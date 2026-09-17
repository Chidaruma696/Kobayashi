class EtiquetasController < ApplicationController
  pestana :etiquetas

  before_action { autorizar!("etiquetas.crear") }

  def index
    vivas = Etiqueta.vivas.sueltas.where(sucursal: sucursal_actual).includes(:producto).recientes
    @paquetes = vivas.where(tipo: "paquete")
    @cajas = vivas.where(tipo: "caja")
    @tarimas = vivas.where(tipo: "tarima")
  end

  def new
    cargar_contexto
    @productos = Producto.activos.order(:nombre)
    @producto = @linea&.producto || @productos.find_by(id: params[:producto_id]) || @productos.first
    @recientes = Etiqueta.where(sucursal: sucursal_actual, usuario: usuario_actual).includes(:producto).recientes.limit(15)
  end

  def create
    cargar_contexto
    producto = Producto.activos.find(params[:producto_id])
    tipo = params[:tipo] == "caja" ? "caja" : "paquete"
    linea = @linea || @produccion&.pedido&.linea_de(producto)
    autoriza = nil
    if linea.nil? && @produccion.nil?
      autoriza = autorizador("etiquetas.libre", params[:pin])
      raise ArgumentError, "para etiquetar hace falta un pedido, una producción o una autorización con motivo" if autoriza.nil? || params[:justificacion].blank?
    end
    @etiqueta = Etiqueta.create!(tipo: tipo, producto: producto, cantidad: params[:cantidad], sucursal: sucursal_actual,
                                 usuario: usuario_actual, pedido_linea: linea, produccion: @produccion,
                                 autorizado_por: autoriza, justificacion: params[:justificacion].presence)
    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to new_etiqueta_path(contexto_params.merge(producto_id: producto.id)), notice: "Etiqueta #{@etiqueta.codigo} creada" }
    end
  rescue ActiveRecord::RecordInvalid, ArgumentError => e
    mensaje = e.respond_to?(:record) ? e.record.errors.full_messages.join(", ") : e.message
    respond_to do |format|
      format.turbo_stream { render turbo_stream: turbo_stream.update("aviso", partial: "aviso", locals: { texto: mensaje }), status: :unprocessable_entity }
      format.html { redirect_to new_etiqueta_path(contexto_params.merge(producto_id: params[:producto_id])), alert: mensaje }
    end
  end

  # Para el lector: qué etiqueta de esta sucursal es este código (JSON).
  def buscar
    etiqueta = Etiqueta.buscar(params[:codigo])
    if etiqueta && etiqueta.sucursal_id == sucursal_actual.id
      render json: { id: etiqueta.id, codigo: etiqueta.codigo, tipo: etiqueta.tipo, estado: etiqueta.estado,
                     producto: etiqueta.producto&.nombre, cantidad: etiqueta.cantidad }
    else
      head :not_found
    end
  end

  def show
    @etiqueta = Etiqueta.find(params[:id])
    render layout: "etiqueta"
  end

  def cerrar_caja
    agrupar { |hijas| Etiqueta.cerrar_caja!(hijas, usuario: usuario_actual) }
  end

  def armar_tarima
    agrupar { |hijas| Etiqueta.armar_tarima!(hijas, usuario: usuario_actual) }
  end

  def baja
    etiqueta = Etiqueta.where(sucursal: sucursal_actual).find(params[:id])
    etiqueta.dar_de_baja!(motivo: params[:motivo].to_s.strip, usuario: usuario_actual)
    redirect_to etiquetas_path, notice: "#{etiqueta} dada de baja"
  rescue ArgumentError => e
    redirect_to etiquetas_path, alert: e.message
  end

  private

  # Renglón de pedido o producción abierta de esta sucursal desde los que se etiqueta.
  def cargar_contexto
    @linea = PedidoLinea.joins(:pedido).where(pedidos: { sucursal_origen_id: sucursal_actual.id, estado: %w[solicitado surtiendo] })
                        .includes(:producto, :pedido).find_by(id: params[:pedido_linea_id])
    @produccion = Produccion.abiertas.where(sucursal: sucursal_actual).includes(:producto, :pedido).find_by(id: params[:produccion_id])
  end

  def contexto_params
    { pedido_linea_id: @linea&.id, produccion_id: @produccion&.id }.compact
  end

  def agrupar
    hijas = Etiqueta.where(sucursal: sucursal_actual, id: Array(params[:ids])).to_a
    grupo = yield(hijas)
    redirect_to etiqueta_path(grupo), notice: "#{grupo.tipo.capitalize} #{grupo.codigo} creada con #{hijas.size} etiquetas"
  rescue ArgumentError => e
    redirect_to etiquetas_path, alert: e.message
  end
end
