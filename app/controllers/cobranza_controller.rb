# Cobranza de ruta: saldos, antigüedad, estado de crédito de cada cliente, abonos en oficina
# y el bloqueo manual que manda sobre la regla.
class CobranzaController < ApplicationController
  pestana :rutas
  modulo :rutas

  before_action { autorizar!("cobranza.ver") }
  before_action :cargar_cliente, except: :index

  def index
    @clientes = Cliente.activos.includes(:ruta).order(:nombre).map { |c| [ c, c.estado_credito, Credito.aging(c) ] }
    @clientes.select! { |_, e, _| e.tipo != "contado" || e.saldo_centavos != 0 }
    @total = @clientes.sum { |_, e, _| e.saldo_centavos }
  end

  def cliente
    @estado = @cliente.estado_credito
    @aging = Credito.aging(@cliente)
    @movimientos = @cliente.movimientos_credito.includes(:usuario).order(fecha: :desc, id: :desc).limit(200)
  end

  def abonar
    autorizar!("cobranza.abonar")
    abono = Abono.registrar!(cliente: @cliente, sucursal: sucursal_actual, monto_centavos: Dinero.centavos(params[:monto]),
                             forma: params[:forma].to_s, usuario: usuario_actual, notas: params[:notas].presence)
    redirect_to cobranza_cliente_path(@cliente), notice: "Abono #{abono.folio} de #{Dinero.pesos(abono.monto_centavos)} registrado; saldo #{Dinero.pesos(@cliente.saldo_centavos)}"
  rescue ArgumentError, ActiveRecord::RecordInvalid => e
    redirect_to cobranza_cliente_path(@cliente), alert: e.message
  end

  def bloquear
    autorizar!("cobranza.bloquear")
    case params[:accion]
    when "bloquear" then @cliente.bloquear!(motivo: params[:motivo].to_s.strip, usuario: usuario_actual)
    when "desbloquear" then @cliente.desbloquear!(motivo: params[:motivo].to_s.strip, usuario: usuario_actual)
    else @cliente.quitar_bloqueo_manual!
    end
    redirect_to cobranza_cliente_path(@cliente), notice: t("cobranza.avisos.credito_de", cliente: @cliente, estado: @cliente.estado_credito.bloqueado ? t("estados.bloqueado") : t("cobranza.abierto"))
  rescue ArgumentError => e
    redirect_to cobranza_cliente_path(@cliente), alert: e.message
  end

  private

  def cargar_cliente
    @cliente = Cliente.find(params[:id])
  end
end
