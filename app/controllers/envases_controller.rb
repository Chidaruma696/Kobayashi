# Envases del proveedor (canastilla, tarima, tote): qué le debemos a cada uno, devoluciones y ajustes.
# Es otro libro que el de canastillas de clientes y choferes.
class EnvasesController < ApplicationController
  pestana :retornables
  modulo :retornables, :compras

  before_action { autorizar!("retornables.ver") }

  def index
    @saldos = Proveedor.order(:nombre).map { |p| [ p, p.saldo_envases ] }.reject { |_, s| s.empty? }
    @movimientos = EnvaseProveedor.includes(:proveedor, :usuario, :recepcion).order(id: :desc).limit(50)
    @proveedores = Proveedor.activos.order(:nombre)
  end

  def mover
    autorizar!("retornables.mover")
    proveedor = Proveedor.find(params[:proveedor_id])
    tipo = params[:tipo].to_s
    signo = tipo == "ajuste" ? (params[:cantidad].to_i.negative? ? -1 : 1) : nil
    raise ArgumentError, t("errores.hace_falta_motivo") if tipo == "ajuste" && params[:motivo].blank?
    Compras.mover_envases!(proveedor: proveedor, sucursal: sucursal_actual, usuario: usuario_actual, envase: params[:envase].to_s, tipo: tipo,
                           cantidad: params[:cantidad].to_i.abs, signo: signo, concepto: params[:motivo].presence || t("compras.envases.tipos.#{tipo}"))
    redirect_to envases_path, notice: t("compras.avisos.envases_movidos")
  rescue ArgumentError, ActiveRecord::RecordInvalid => e
    redirect_to envases_path, alert: e.message
  end
end
