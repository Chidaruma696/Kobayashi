class CargosController < ApplicationController
  pestana :conteos

  before_action { autorizar!("conteos.cargos") }

  def index
    @cargos = Cargo.joins(:conteo).where(conteos: { sucursal_id: sucursal_actual.id }).includes(:usuario, :conteo, :resuelto_por).order(created_at: :desc).limit(100)
  end

  def resolver
    cargo = Cargo.joins(:conteo).where(conteos: { sucursal_id: sucursal_actual.id }).find(params[:id])
    cargo.resolver!(params[:estado].presence_in(%w[cobrado perdonado]) || "cobrado", usuario: usuario_actual)
    redirect_to cargos_path, notice: "Cargo de #{cargo.usuario} marcado como #{cargo.estado}"
  rescue ArgumentError => e
    redirect_to cargos_path, alert: e.message
  end
end
