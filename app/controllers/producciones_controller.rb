class ProduccionesController < ApplicationController
  pestana :etiquetas

  before_action { autorizar!("produccion.abrir") }

  def index
    @abiertas = Produccion.where(sucursal: sucursal_actual).abiertas.includes(:producto, :pedido, :usuario).order(:created_at)
    @cerradas = Produccion.where(sucursal: sucursal_actual).where(estado: "cerrada").includes(:producto).order(created_at: :desc).limit(20)
  end

  def new
    @pedido = Pedido.abiertos.find_by(id: params[:pedido_id], sucursal_origen: sucursal_actual)
    @pedidos = Pedido.abiertos.where(sucursal_origen: sucursal_actual).includes(:sucursal_destino, :cliente).order(:created_at)
    @productos = Producto.activos.order(:nombre)
  end

  def create
    pedido = Pedido.abiertos.find_by(id: params[:pedido_id], sucursal_origen: sucursal_actual)
    return redirect_to new_produccion_path, alert: "Sin pedido escribe el motivo" if pedido.nil? && params[:justificacion].blank?
    autoriza = pedido ? nil : autorizador_o_revision("etiquetas.libre", params[:pin])
    producto = Producto.activos.find(params[:producto_id])
    produccion = Produccion.abrir!(sucursal: sucursal_actual, producto: producto,
                                   cantidad: params[:cantidad], usuario: usuario_actual, pedido: pedido,
                                   autorizado_por: autoriza, justificacion: params[:justificacion].presence)
    revisar_si_hace_falta(produccion, autoriza, motivo: params[:justificacion], valor_centavos: Revision.valor(produccion.cantidad, producto, sucursal_actual)) if pedido.nil?
    redirect_to new_etiqueta_path(produccion_id: produccion.id), notice: "Producción #{produccion.folio} abierta: entraron #{produccion.cantidad.to_s('F')} de #{produccion.producto.nombre}"
  rescue Inventario::SinExistencia, ActiveRecord::RecordInvalid, ArgumentError => e
    redirect_to new_produccion_path(pedido_id: params[:pedido_id]), alert: e.message
  end

  def show
    @produccion = Produccion.where(sucursal: sucursal_actual).includes(:producto, :pedido).find(params[:id])
    @salidas = @produccion.salidas
  end

  def cerrar
    produccion = Produccion.where(sucursal: sucursal_actual).find(params[:id])
    produccion.cerrar!(usuario: usuario_actual)
    redirect_to produccion_path(produccion), notice: "Producción cerrada: merma #{produccion.merma.to_s('F')} #{produccion.producto.unidad}"
  rescue ArgumentError => e
    redirect_to produccion_path(params[:id]), alert: e.message
  end
end
