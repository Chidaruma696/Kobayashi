# Viajes de reparto: la oficina arma la ruta del día, la despacha y la liquida cuando el chofer vuelve.
class ViajesController < ApplicationController
  pestana :rutas

  before_action :cargar_viaje, except: %i[index new create subir]

  def index
    autorizar_alguno!("rutas.armar", "rutas.liquidar")
    @abiertos = ambito.abiertos.includes(:ruta, :chofer, salidas: :cliente).order(:fecha, :created_at)
    @liquidados = ambito.where(estado: %w[liquidado cancelado]).includes(:ruta, :chofer, :liquidado_por).order(liquidado_en: :desc).limit(20)
  end

  def new
    autorizar!("rutas.armar")
    @rutas = Ruta.activas.includes(:chofer).order(:nombre)
    @choferes = Usuario.activos.joins(:rol).order(:nombre).select { |u| u.puede?("rutas.repartir") }
  end

  def create
    autorizar!("rutas.armar")
    ruta = Ruta.activas.find(params[:ruta_id])
    chofer = Usuario.activos.find(params[:chofer_id].presence || ruta.chofer_id)
    viaje = Viaje.create!(sucursal: sucursal_actual, ruta: ruta, chofer: chofer, usuario: usuario_actual,
                          fecha: (Date.parse(params[:fecha]) rescue Date.current), notas: params[:notas].presence)
    # Los repartos sellados de la ruta que aún no van en ningún viaje suben solos.
    Salida.where(sucursal_origen: sucursal_actual, tipo: "reparto", ruta: ruta, viaje_id: nil, estado: "sellada").find_each { |s| viaje.agregar!(s) }
    redirect_to viaje_path(viaje), notice: "Viaje #{viaje.folio} armado con #{viaje.salidas.count} repartos"
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotFound => e
    redirect_to new_viaje_path, alert: e.message
  end

  def show
    autorizar_alguno!("rutas.armar", "rutas.liquidar", "rutas.repartir")
    @paradas = @viaje.paradas
    @candidatas = Salida.where(sucursal_origen: @viaje.sucursal, tipo: "reparto", viaje_id: nil).abiertas.includes(:cliente, :ruta).order(:created_at) if @viaje.armando?
  end

  # Hoja de ruta para el chofer, en papel de 80 mm.
  def hoja
    autorizar_alguno!("rutas.armar", "rutas.liquidar", "rutas.repartir")
    @paradas = @viaje.paradas
    @titulo = "Hoja de ruta #{@viaje.folio}"
    render layout: "ticket"
  end

  # Desde la ficha de una salida: subirla al viaje elegido.
  def subir
    autorizar!("rutas.armar")
    salida = Salida.where(sucursal_origen: sucursal_actual).find(params[:salida_id])
    ambito.find(params[:viaje_id]).agregar!(salida)
    redirect_to salida_path(salida), notice: "#{salida.folio} va en el viaje #{salida.reload.viaje.folio}"
  rescue ArgumentError, ActiveRecord::RecordNotFound => e
    redirect_to salida_path(params[:salida_id]), alert: e.message
  end

  def agregar
    autorizar!("rutas.armar")
    @viaje.agregar!(Salida.where(sucursal_origen: @viaje.sucursal).find(params[:salida_id]))
    volver("Reparto agregado")
  rescue ArgumentError => e
    volver(nil, e.message)
  end

  def quitar
    autorizar!("rutas.armar")
    @viaje.quitar!(Salida.find(params[:salida_id]))
    volver("Reparto quitado del viaje")
  rescue ArgumentError => e
    volver(nil, e.message)
  end

  def salir
    autorizar!("rutas.armar")
    @viaje.salir!(usuario: usuario_actual)
    volver("Viaje #{@viaje.folio} en ruta: #{@viaje.salidas.count} notas por cobrar")
  rescue ArgumentError, Caja::Error => e
    volver(nil, e.message)
  end

  def gasto
    autorizar_alguno!("rutas.liquidar", "rutas.repartir")
    @viaje.agregar_gasto!(concepto: params[:concepto].to_s.strip, monto_centavos: Dinero.centavos(params[:monto]), usuario: usuario_actual)
    volver("Gasto registrado")
  rescue ArgumentError, ActiveRecord::RecordInvalid => e
    volver(nil, e.message)
  end

  def liquidar
    autorizar!("rutas.liquidar")
    @viaje.liquidar!(efectivo_entregado_centavos: Dinero.centavos(params[:entregado]), usuario: usuario_actual)
    aviso = "Viaje liquidado: esperaba #{Dinero.pesos(@viaje.efectivo_esperado_centavos)}, entregó #{Dinero.pesos(@viaje.efectivo_entregado_centavos)}"
    aviso += "; cargo de #{Dinero.pesos(-@viaje.diferencia_centavos)} a #{@viaje.chofer}" if @viaje.diferencia_centavos.negative?
    volver(aviso)
  rescue ArgumentError, Caja::Error, ActiveRecord::RecordInvalid => e
    volver(nil, e.message)
  end

  def cancelar
    autorizar!("rutas.armar")
    @viaje.cancelar!
    volver("Viaje cancelado")
  rescue ArgumentError => e
    volver(nil, e.message)
  end

  private

  def ambito
    sucursal_actual.matriz? ? Viaje.all : Viaje.where(sucursal: sucursal_actual)
  end

  def cargar_viaje
    @viaje = ambito.includes(:ruta, :chofer, :gastos).find(params[:id])
  end

  def autorizar_alguno!(*claves)
    raise SinPermiso, claves.first unless claves.any? { |c| puede?(c) }
  end

  def volver(aviso, error = nil)
    redirect_to viaje_path(@viaje), notice: aviso, alert: error
  end
end
