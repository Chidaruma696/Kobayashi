class PedidoLineasController < ApplicationController
  pestana :pedidos

  before_action { autorizar!("pedidos.surtir") }
  before_action :cargar_linea

  def surtido
    @linea.marcar_surtido!
    volver(t("pedidos.renglon_surtido"))
  end

  def no_surtir
    @linea.no_surtir!(params[:motivo].to_s.strip)
    volver(t("pedidos.renglon_apartado"))
  rescue ArgumentError => e
    volver(nil, e.message)
  end

  def reabrir
    @linea.reabrir!
    volver(t("pedidos.renglon_reabierto"))
  end

  private

  def cargar_linea
    @linea = PedidoLinea.joins(:pedido).where(pedidos: { sucursal_origen_id: sucursal_actual.id }).find(params[:id])
  end

  # Desde la ficha del pedido (HTML) o desde el checklist de la etiquetadora (JSON).
  def volver(aviso, error = nil)
    respond_to do |format|
      format.html { redirect_to pedido_path(@linea.pedido), notice: aviso, alert: error }
      format.json { error ? render(json: { error: error }, status: :unprocessable_entity) : render(json: { id: @linea.id, estado: @linea.estado, motivo: @linea.motivo }) }
    end
  end
end
