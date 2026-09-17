class PedidoLineasController < ApplicationController
  pestana :pedidos

  before_action { autorizar!("pedidos.surtir") }
  before_action :cargar_linea

  def surtido
    @linea.marcar_surtido!
    volver("Renglón marcado como surtido")
  end

  def no_surtir
    @linea.no_surtir!(params[:motivo].to_s.strip)
    volver("Renglón apartado: no se va a surtir")
  rescue ArgumentError => e
    volver(nil, e.message)
  end

  def reabrir
    @linea.reabrir!
    volver("Renglón reabierto")
  end

  private

  def cargar_linea
    @linea = PedidoLinea.joins(:pedido).where(pedidos: { sucursal_origen_id: sucursal_actual.id }).find(params[:id])
  end

  def volver(aviso, error = nil)
    redirect_to pedido_path(@linea.pedido), notice: aviso, alert: error
  end
end
