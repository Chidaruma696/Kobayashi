class SalidasController < ApplicationController
  pestana :salidas
  modulo :salidas

  before_action :cargar_salida, except: %i[index new create por_recibir]

  def index
    autorizar!("salidas.surtir")
    @salidas = Salida.where(sucursal_origen: sucursal_actual).where.not(estado: %w[recibida entregada cancelada]).includes(:sucursal_destino, :cliente, :usuario).order(:created_at)
    @historial = Salida.where(sucursal_origen: sucursal_actual).where(estado: %w[recibida entregada cancelada]).includes(:sucursal_destino, :cliente).order(created_at: :desc).limit(15)
  end

  def por_recibir
    autorizar!("salidas.recibir")
    @salidas = Salida.where(sucursal_destino: sucursal_actual).en_transito.includes(:sucursal_origen, :usuario).order(:enviado_en)
    @recibidas = Salida.where(sucursal_destino: sucursal_actual).where(estado: "recibida").includes(:sucursal_origen).order(recibido_en: :desc).limit(15)
  end

  # Si la salida nace de un pedido, va a quien pidió: no se escoge destino.
  def new
    autorizar!("salidas.surtir")
    @pedido = pedido_abierto
    return if @pedido

    @destinos = Sucursal.activas.where.not(id: sucursal_actual.id).order(:nombre)
    @clientes = sucursal_actual.matriz? && Modulo.activo?("rutas") ? Cliente.activos.includes(:ruta).order(:nombre) : []
  end

  def create
    autorizar!("salidas.surtir")
    destino = pedido_abierto&.destino || destino_elegido
    salida = Salida.nueva!(origen: sucursal_actual, destino: destino, usuario: usuario_actual, motivo: params[:motivo].presence)
    redirect_to salida_path(salida), notice: t("salidas.avisos.abierta", folio: salida.folio)
  rescue ActiveRecord::RecordInvalid => e
    redirect_to new_salida_path(pedido_id: params[:pedido_id]), alert: e.record.errors.full_messages.join(", ")
  end

  def show
    @filas = @salida.salida_etiquetas.includes(:verificado_por, etiqueta: :producto, grupo: :producto).order(:grupo_id, :id)
    @grupos = @filas.group_by(&:grupo)
    if @salida.preparando? && !@salida.devolucion?
      @pedidos = Pedido.abiertos.where(sucursal_origen: @salida.sucursal_origen, sucursal_destino_id: @salida.sucursal_destino_id, cliente_id: @salida.cliente_id).includes(lineas: :producto)
    end
    @recibiendo = @salida.enviada? && @salida.sucursal_destino_id == sucursal_actual.id
  end

  # --- surtir
  def agregar
    autorizar!("salidas.surtir")
    con_etiqueta { |e| n = @salida.agregar!(e); t("salidas.avisos.agregada", tipo: t("etiquetas.tipos.#{e.tipo}"), codigo: e.codigo, n: n) }
  end

  def quitar
    autorizar!("salidas.surtir")
    con_etiqueta { |e| n = @salida.quitar!(e); t("salidas.avisos.quitados", n: n) }
  end

  def manual
    autorizar!("salidas.surtir")
    autoriza = autorizador_o_revision("etiquetas.libre")
    linea = @salida.agregar_manual!(producto: Producto.activos.find(params[:producto_id]), cantidad: params[:cantidad],
                                    motivo: params[:motivo].to_s.strip, autorizado_por: autoriza, usuario: usuario_actual)
    revisar_si_hace_falta(linea, autoriza, motivo: linea.motivo, valor_centavos: Revision.valor(linea.cantidad, linea.producto, sucursal_actual))
    redirect_to salida_path(@salida), notice: autoriza ? t("salidas.avisos.manual") : t("salidas.avisos.manual_revision")
  rescue ArgumentError, ActiveRecord::RecordInvalid => e
    redirect_to salida_path(@salida), alert: e.message
  end

  # --- verificar y sellar
  def verificar
    autorizar!("salidas.verificar")
    con_etiqueta { |e| @salida.verificar!(e, usuario: usuario_actual); t("salidas.avisos.verificada", codigo: e.codigo) }
  end

  def sellar
    autorizar!(params[:motivo_sin_verificar].present? ? "salidas.surtir" : "salidas.verificar")
    pendientes = @salida.sellar!(usuario: usuario_actual, sin_verificar_motivo: params[:motivo_sin_verificar].presence)
    if pendientes.positive?
      revisar_si_hace_falta(@salida, nil, motivo: t("salidas.avisos.sello_sin_verificar", folio: @salida.folio, n: pendientes, motivo: params[:motivo_sin_verificar]),
                            valor_centavos: @salida.contenido.sum { |producto, cant| Revision.valor(cant, producto, sucursal_actual) })
    end
    redirect_to salida_path(@salida), notice: t("salidas.avisos.sellada", folio: @salida.folio, quien: usuario_actual)
  rescue ArgumentError => e
    redirect_to salida_path(@salida), alert: e.message
  end

  def enviar
    autorizar!("salidas.surtir")
    @salida.enviar!(usuario: usuario_actual)
    redirect_to salidas_path, notice: t("salidas.avisos.enviada", folio: @salida.folio, destino: @salida.destino)
  rescue ArgumentError, Inventario::SinExistencia, Caja::Error => e
    redirect_to salida_path(@salida), alert: e.message
  end

  # El chofer vuelve con el dinero del reparto.
  def canastillas
    autorizar!("salidas.surtir")
    @salida.fijar_canastillas!(TipoCanastilla.find(params[:tipo_canastilla_id]), params[:cantidad])
    redirect_to salida_path(@salida), notice: t("salidas.avisos.canastillas")
  rescue ArgumentError, ActiveRecord::RecordInvalid => e
    redirect_to salida_path(@salida), alert: e.message
  end

  def cobrar_entrega
    autorizar!("caja.vender")
    pagos = %w[efectivo transferencia deposito].map { |f| { forma: f, monto_centavos: Dinero.centavos(params[f]) } }
    @salida.cobrar_entrega!(pagos: pagos, usuario: usuario_actual)
    redirect_to salida_path(@salida), notice: t("salidas.avisos.cobrada", folio: @salida.folio, nota: @salida.venta.folio)
  rescue ArgumentError, Caja::Error => e
    redirect_to salida_path(@salida), alert: e.message
  end

  def cancelar
    autorizar!("salidas.surtir")
    @salida.cancelar!
    redirect_to salidas_path, notice: t("salidas.avisos.cancelada", folio: @salida.folio)
  rescue ArgumentError => e
    redirect_to salida_path(@salida), alert: e.message
  end

  # --- recibir
  def recibir_etiqueta
    autorizar!("salidas.recibir")
    con_etiqueta { |e| n = @salida.recibir!(e, usuario: usuario_actual); t("salidas.avisos.recibidos", n: n) }
  end

  # Un paquete que llegó sin venir en la salida: entra como sobrante con motivo y queda por revisar.
  def sobrante
    autorizar!("salidas.recibir")
    etiqueta = Etiqueta.buscar(params[:codigo]) or raise ArgumentError, t("errores.etiqueta.no_encontrada", codigo: params[:codigo])
    motivo = params[:motivo].to_s.strip
    @salida.recibir_sobrante!(etiqueta, motivo: motivo, usuario: usuario_actual)
    revisar_si_hace_falta(etiqueta, nil, motivo: t("salidas.avisos.sobrante_motivo", folio: @salida.folio, motivo: motivo),
                          valor_centavos: Revision.valor(etiqueta.cantidad, etiqueta.producto, sucursal_actual))
    redirect_to salida_path(@salida), notice: t("salidas.avisos.sobrante", codigo: etiqueta.codigo)
  rescue ArgumentError, Inventario::SinExistencia => e
    redirect_to salida_path(@salida), alert: e.message
  end

  def reportar
    autorizar!("salidas.recibir")
    con_etiqueta { |e| n = @salida.reportar!(e, motivo: params[:motivo].to_s.strip, usuario: usuario_actual); t("salidas.avisos.reportados", n: n) }
  end

  def cerrar_recepcion
    autorizar!("salidas.recibir")
    @salida.cerrar_recepcion!(usuario: usuario_actual, motivo_pendientes: params[:motivo].presence)
    redirect_to recibir_salidas_path, notice: t("salidas.avisos.recibida", folio: @salida.folio)
  rescue ArgumentError => e
    redirect_to salida_path(@salida), alert: e.message
  end

  private

  def pedido_abierto
    Pedido.abiertos.find_by(id: params[:pedido_id], sucursal_origen: sucursal_actual) if params[:pedido_id].present?
  end

  def destino_elegido
    tipo, id = params[:destino].to_s.split(":")
    tipo == "cliente" && sucursal_actual.matriz? ? Cliente.activos.find(id) : Sucursal.find(id)
  end

  def cargar_salida
    @salida = Salida.where(sucursal_origen: sucursal_actual).or(Salida.where(sucursal_destino: sucursal_actual)).includes(:sucursal_origen, :sucursal_destino, :usuario).find(params[:id])
  end

  def con_etiqueta
    etiqueta = Etiqueta.buscar(params[:codigo]) or raise ArgumentError, t("errores.etiqueta.no_encontrada", codigo: params[:codigo])
    redirect_to salida_path(@salida), notice: yield(etiqueta)
  rescue ArgumentError, Inventario::SinExistencia => e
    redirect_to salida_path(@salida), alert: e.message
  end
end
