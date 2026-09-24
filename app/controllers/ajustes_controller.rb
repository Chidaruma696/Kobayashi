# Ajustes: lo de cada quien (idioma, tema, densidad, letra) y lo del sistema (negocio, etiqueta,
# caja), esto último solo para quien administra usuarios.
class AjustesController < ApplicationController
  pestana :ajustes

  def index
    @ajustes = Ajuste.todos
  end

  def preferencias
    usuario_actual.update!(params.require(:usuario).permit(:idioma, :tema, :densidad, :letra))
    redirect_to ajustes_path, notice: I18n.t("ajustes.guardado", locale: usuario_actual.idioma)
  rescue ActiveRecord::RecordInvalid => e
    redirect_to ajustes_path, alert: e.record.errors.full_messages.join(", ")
  end

  # Diseño del ticket: los datos del negocio a la izquierda y cómo queda a la derecha.
  def ticket
    autorizar!("admin.usuarios")
    @ajustes = Ajuste.todos
    @venta = venta_de_muestra
    @previa = true
  end

  def guardar_ticket
    autorizar!("admin.usuarios")
    Ajuste.guardar!(params.fetch(:ajuste, {}).to_unsafe_h)
    redirect_to ajustes_ticket_path, notice: t("ajustes.guardado")
  rescue ArgumentError, ActiveRecord::RecordInvalid => e
    redirect_to ajustes_ticket_path, alert: e.message
  end

  def sistema
    autorizar!("admin.usuarios")
    Ajuste.guardar!(params.fetch(:ajuste, {}).to_unsafe_h)
    Modulo.guardar!(params[:modulos]) if params.key?(:modulos)
    redirect_to ajustes_path, notice: t("ajustes.guardado")
  rescue ArgumentError, ActiveRecord::RecordInvalid => e
    redirect_to ajustes_path, alert: e.message
  end

  private

  # Una venta inventada, en memoria, para la vista previa del ticket.
  def venta_de_muestra
    v = Venta.new(sucursal: sucursal_actual, usuario: usuario_actual, folio: "B-00042", codigo: Barcode.ean13("090000000042"),
                  created_at: Time.current, total_centavos: 21_450, cambio_centavos: 3_550, estado: "cobrada")
    [ [ t("ajustes.ticket.muestra.producto_kg"), "kg", "1.250", 12_900 ], [ t("ajustes.ticket.muestra.producto_pieza"), "pieza", "2", 2_650 ] ].each do |nombre, unidad, cant, precio|
      cantidad = BigDecimal(cant)
      v.lineas.build(producto: Producto.new(nombre: nombre, unidad: unidad), cantidad: cantidad, precio_centavos: precio,
                     catalogo_centavos: precio, importe_centavos: (cantidad * precio).round.to_i)
    end
    v.pagos.build(forma: "efectivo", monto_centavos: 25_000)
    v
  end
end
