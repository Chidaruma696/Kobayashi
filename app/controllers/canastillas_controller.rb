# Canastillas: qué debe cada cliente y qué trae cada chofer, por tipo; devoluciones en oficina y ajustes.
class CanastillasController < ApplicationController
  pestana :rutas

  before_action { autorizar!("canastillas.ver") }

  def index
    @tipos = TipoCanastilla.activos.to_a
    @clientes = Canastillas.saldos_clientes.map { |id, saldos| [ Cliente.find(id), saldos ] }.sort_by { |c, _| c.nombre }
    @choferes = Canastillas.saldos_choferes.map { |id, saldos| [ Usuario.find(id), saldos ] }.sort_by { |u, _| u.nombre }
    @movimientos = MovimientoCanastilla.includes(:cliente, :chofer, :tipo_canastilla, :usuario, :viaje).order(created_at: :desc).limit(50)
    @todos_clientes = Cliente.activos.order(:nombre)
    @todos_choferes = Usuario.activos.order(:nombre).select { |u| u.puede?("rutas.repartir") }
  end

  # El cliente trae canastillas a la bodega (sin chofer de por medio).
  def devolucion
    autorizar!("canastillas.ajustar")
    Canastillas.mover!(tipo: "devolucion", tipo_canastilla: TipoCanastilla.find(params[:tipo_canastilla_id]), cantidad: params[:cantidad],
                       sucursal: sucursal_actual, usuario: usuario_actual, cliente: Cliente.find(params[:cliente_id]), concepto: t("canastillas.devolucion_bodega"))
    redirect_to canastillas_path, notice: t("canastillas.avisos.devolucion")
  rescue ArgumentError, ActiveRecord::RecordInvalid => e
    redirect_to canastillas_path, alert: e.message
  end

  def ajuste
    autorizar!("canastillas.ajustar")
    Canastillas.ajustar!(tipo_canastilla: TipoCanastilla.find(params[:tipo_canastilla_id]), cantidad: params[:cantidad], motivo: params[:motivo].to_s.strip,
                         sucursal: sucursal_actual, usuario: usuario_actual,
                         cliente: Cliente.find_by(id: params[:cliente_id].presence), chofer: Usuario.find_by(id: params[:chofer_id].presence))
    redirect_to canastillas_path, notice: t("canastillas.avisos.ajuste")
  rescue ArgumentError, ActiveRecord::RecordInvalid => e
    redirect_to canastillas_path, alert: e.message
  end
end
