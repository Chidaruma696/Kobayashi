# Facturas del proveedor: crean la deuda. Con renglones (el precio vive solo aquí) o solo monto.
class FacturasProveedorController < ApplicationController
  pestana :compras
  modulo :compras

  before_action { autorizar!("compras.ver") }

  def index
    @facturas = FacturaProveedor.includes(:proveedor, :usuario, :pagos).order(fecha: :desc, id: :desc).limit(200)
    @facturas = @facturas.where(proveedor_id: params[:proveedor_id]) if params[:proveedor_id].present?
    @proveedores = Proveedor.order(:nombre)
  end

  def new
    autorizar!("compras.facturar")
    @factura = FacturaProveedor.new(fecha: Date.current, proveedor_id: params[:proveedor_id])
    @factura.lineas.build
    @proveedores = Proveedor.activos.order(:nombre)
    @productos = Producto.activos.order(:nombre)
  end

  def create
    autorizar!("compras.facturar")
    d = params.require(:factura)
    proveedor = Proveedor.activos.find(d[:proveedor_id])
    factura = Compras.facturar!(proveedor: proveedor, sucursal: sucursal_actual, usuario: usuario_actual, folio: d[:folio].to_s, fecha: Date.parse(d[:fecha].presence || Date.current.to_s),
                                vence: (Date.parse(d[:vence]) if d[:vence].present?), concepto: d[:concepto], monto_centavos: Dinero.centavos(d[:monto]),
                                lineas: (d[:lineas_attributes]&.to_unsafe_h || {}).values)
    Recepcion.where(id: Array(d[:recepcion_ids]), proveedor: proveedor, factura_proveedor_id: nil, estado: "registrada").find_each { |r| Compras.ligar!(r, factura) }
    redirect_to factura_path(factura), notice: t("compras.avisos.facturada", folio: factura.folio, monto: Dinero.pesos(factura.monto_centavos))
  rescue ArgumentError, ActiveRecord::RecordInvalid, ActiveRecord::RecordNotFound => e
    redirect_to new_factura_path(proveedor_id: d && d[:proveedor_id]), alert: e.message
  end

  def show
    @factura = FacturaProveedor.includes(:proveedor, :usuario, lineas: :producto, recepciones: %i[usuario sucursal], pagos: %i[usuario retiro]).find(params[:id])
    @comparativo = Compras.comparativo(@factura)
    @sueltas = @factura.proveedor.recepciones.registradas.where(factura_proveedor_id: nil).order(fecha: :desc).limit(30)
  end

  def cancelar
    autorizar!("compras.facturar")
    factura = FacturaProveedor.find(params[:id])
    Compras.cancelar_factura!(factura, motivo: params[:motivo].to_s.strip, usuario: usuario_actual)
    redirect_to factura_path(factura), notice: t("compras.avisos.factura_cancelada", folio: factura.folio)
  rescue ArgumentError, ActiveRecord::RecordInvalid => e
    redirect_to factura_path(factura), alert: e.message
  end
end
