class InventarioController < ApplicationController
  pestana :inventario

  before_action { autorizar!("inventario.ver") }
  before_action :cargar_sucursal

  def index
    @existencias = Existencia.where(sucursal: @sucursal).includes(:producto)
                             .joins(:producto).order("productos.nombre")
  end

  def kardex
    @producto = Producto.find_by(id: params[:producto_id])
    @movimientos = Movimiento.where(sucursal: @sucursal).includes(:producto, :usuario, :etiqueta)
                             .order(created_at: :desc).limit(200)
    @movimientos = @movimientos.where(producto: @producto) if @producto
  end

  def nuevo_movimiento
    @movimiento = Movimiento.new(tipo: "entrada")
  end

  def crear_movimiento
    return volver_con_error("Escribe el motivo") if params[:motivo].blank?
    autoriza = autorizador_o_revision("inventario.ajustar")
    producto = Producto.activos.find(params[:producto_id])
    tipo = params[:tipo].presence_in(%w[entrada ajuste_entrada ajuste_salida merma]) || "entrada"
    movimiento = Inventario.mover!(sucursal: @sucursal, producto: producto, tipo: tipo, cantidad: params[:cantidad], usuario: usuario_actual,
                                   motivo: "#{params[:motivo]} (#{autoriza ? "autorizó #{autoriza.nombre}" : 'por revisar'})")
    revisar_si_hace_falta(movimiento, autoriza, motivo: params[:motivo], sucursal: @sucursal,
                          valor_centavos: Revision.valor(movimiento.cantidad, producto, @sucursal))
    redirect_to kardex_inventario_path(producto_id: producto.id, sucursal_id: @sucursal.id),
                notice: "#{Movimiento::NOMBRES[tipo]} de #{producto.nombre} registrada#{'; queda por revisar' unless autoriza}"
  rescue Inventario::SinExistencia, ArgumentError => e
    volver_con_error(e.message)
  end

  private

  # La matriz puede mirar cualquier sucursal; una tienda solo la suya.
  def cargar_sucursal
    @sucursal = sucursal_actual
    if params[:sucursal_id].present? && (sucursal_actual.matriz? || puede?("admin.usuarios"))
      @sucursal = Sucursal.find(params[:sucursal_id])
    end
  end

  def volver_con_error(mensaje)
    @movimiento = Movimiento.new(tipo: params[:tipo], producto_id: params[:producto_id], cantidad: params[:cantidad], motivo: params[:motivo])
    flash.now[:alert] = mensaje
    render :nuevo_movimiento, status: :unprocessable_entity
  end
end
