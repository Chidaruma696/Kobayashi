# La pantalla del chofer, pensada para el celular: sus paradas en orden, y en cada una
# entregar escaneando, rechazar lo que no bajó, cobrar de contado y tomar el pedido de la próxima.
class RepartoController < ApplicationController
  pestana :rutas

  before_action { autorizar!("rutas.repartir") }
  before_action :cargar_parada, except: :index

  def index
    viajes = Viaje.where(estado: "en_ruta").includes(:ruta, :chofer)
    viajes = viajes.where(chofer: usuario_actual) unless puede?("rutas.armar")
    @viajes = viajes.order(:fecha).map { |v| [ v, v.paradas ] }
  end

  def parada
    @filas = @salida.salida_etiquetas.includes(etiqueta: :producto, grupo: :producto).order(:grupo_id, :id)
    @bultos = @filas.group_by { |f| f.grupo || f.etiqueta }
    @venta = @salida.venta
    @productos = Producto.activos.order(:nombre)
  end

  def entregar
    n = @salida.entregar!(Etiqueta.buscar(params[:codigo].to_s.strip) || raise(ArgumentError, "no encuentro la etiqueta #{params[:codigo]}"), usuario: usuario_actual)
    volver("#{n} #{n == 1 ? 'bulto entregado' : 'bultos entregados'}")
  rescue ArgumentError => e
    volver(nil, e.message)
  end

  # Entregar sin escanear: se puede, pero queda por revisar a nombre del chofer.
  def entregar_todo
    raise ArgumentError, "escribe por qué no se escaneó" if params[:motivo].blank?
    n = @salida.entregar_todo!
    revisar_si_hace_falta(@salida, nil, motivo: "Entregó #{n} bultos sin escanear: #{params[:motivo]}", valor_centavos: @salida.venta&.saldo_centavos.to_i)
    volver("#{n} bultos dados por entregados; queda por revisar")
  rescue ArgumentError => e
    volver(nil, e.message)
  end

  def cerrar
    pagos = Pago::FORMAS.map { |f| { forma: f, monto_centavos: Dinero.centavos(params[f]) } }
    @salida.cerrar_parada!(usuario: usuario_actual, motivo_rechazo: params[:motivo_rechazo].presence, pagos: pagos)
    redirect_to reparto_path, notice: @salida.entregada? ? "Parada #{@salida.destino} cobrada: #{Dinero.pesos(@salida.venta.saldo_centavos)}" : "Parada #{@salida.destino} rechazada completa"
  rescue ArgumentError, Caja::Error => e
    volver(nil, e.message)
  end

  def no_entregado
    raise ArgumentError, "escribe el motivo" if params[:motivo].blank?
    @salida.cerrar_parada!(usuario: usuario_actual, motivo_rechazo: "no entregado: #{params[:motivo]}")
    redirect_to reparto_path, notice: "Parada #{@salida.destino} no entregada: todo vuelve"
  rescue ArgumentError, Caja::Error => e
    volver(nil, e.message)
  end

  private

  def cargar_parada
    @salida = Salida.where(tipo: "reparto").includes(:cliente, :viaje, :venta).find(params[:id])
    mia = @salida.viaje&.chofer_id == usuario_actual.id || puede?("rutas.armar")
    raise SinPermiso, "rutas.repartir" unless mia && @salida.viaje&.en_ruta?
  end

  def volver(aviso, error = nil)
    redirect_to reparto_parada_path(@salida), notice: aviso, alert: error
  end
end
