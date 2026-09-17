# La única puerta para cobrar y para devolver. Todo en una transacción: venta, líneas, pagos,
# kardex y etiquetas; si algo falla, no queda nada a medias.
module Caja
  class Error < StandardError; end

  PISO_PRECIO = 0.5 # nunca por debajo de la mitad del catálogo, ni con autorización

  # lineas: [{ etiqueta_id: | producto_id:, cantidad:, precio_centavos: }]
  # pagos:  [{ forma:, monto_centavos: }]
  # clave:  identificador único del ticket generado por la caja; repetir la misma clave devuelve la misma venta.
  def self.cobrar!(sucursal:, usuario:, lineas:, pagos:, clave:, autorizador: nil)
    raise Error, "hace falta la clave del ticket" if clave.blank?
    if (previa = Venta.find_by(clave: clave))
      return previa
    end
    corte = Corte.abierto_en(sucursal) or raise Error, "no hay caja abierta en #{sucursal.nombre}: ábrela con su fondo"
    raise Error, "hay más de #{Dinero.pesos(sucursal.limite_efectivo_centavos)} en la gaveta: haz un retiro a la caja fuerte antes de seguir" if corte.excede_limite?
    raise Error, "el ticket está vacío" if lineas.blank?

    Venta.transaction do
      preparadas = lineas.map { |l| preparar_linea(sucursal, l, autorizador) }
      total = preparadas.sum { |l| l[:importe_centavos] }
      pagos_ok = preparar_pagos(pagos, total)
      cambio = pagos_ok.sum { |p| p[:monto_centavos] } - total

      venta = Venta.create!(sucursal: sucursal, corte: corte, usuario: usuario, clave: clave,
                            folio: Folio.siguiente!(sucursal, "B"), codigo: codigo_ticket(sucursal),
                            total_centavos: total, cambio_centavos: cambio, fecha_negocio: Date.current)
      preparadas.each do |l|
        linea = venta.lineas.create!(l)
        Inventario.mover!(sucursal: sucursal, producto: linea.producto, tipo: "venta", cantidad: linea.cantidad,
                          usuario: usuario, etiqueta: linea.etiqueta, referencia: venta, motivo: venta.folio)
        linea.etiqueta&.update!(estado: "vendida")
      end
      pagos_ok.each { |p| venta.pagos.create!(p) }
      venta
    end
  rescue Inventario::SinExistencia => e
    raise Error, "#{e.message}. No se vende lo que no hay: recibe el traspaso antes."
  end

  # lineas: [{ venta_linea_id:, cantidad: }]. El dinero sale de la gaveta del corte abierto.
  def self.devolver!(venta:, lineas:, motivo:, usuario:)
    raise Error, "hace falta el motivo" if motivo.blank?
    raise Error, "la venta ya está devuelta completa" unless venta.cobrada?
    corte = Corte.abierto_en(venta.sucursal) or raise Error, "no hay caja abierta para devolver el dinero"
    raise Error, "no se devolvió nada" if lineas.blank?

    Venta.transaction do
      devolucion = Devolucion.new(venta: venta, corte: corte, usuario: usuario, motivo: motivo, total_centavos: 0)
      total = 0
      lineas.each do |l|
        vl = venta.lineas.find(l[:venta_linea_id])
        cantidad = BigDecimal(l[:cantidad].to_s).round(3)
        raise Error, "#{vl.producto.nombre}: se pueden devolver como mucho #{vl.cantidad_pendiente.to_s('F')}" if cantidad <= 0 || cantidad > vl.cantidad_pendiente
        importe = Dinero.importe(cantidad, vl.precio_centavos)
        total += importe
        devolucion.lineas.build(venta_linea: vl, cantidad: cantidad, importe_centavos: importe)
        Inventario.mover!(sucursal: venta.sucursal, producto: vl.producto, tipo: "devolucion_cliente", cantidad: cantidad,
                          usuario: usuario, etiqueta: vl.etiqueta, referencia: devolucion, motivo: "#{venta.folio}: #{motivo}")
        vl.etiqueta&.update!(estado: "viva") if vl.etiqueta && cantidad == vl.cantidad
      end
      devolucion.total_centavos = total
      devolucion.save!
      venta.update!(estado: "devuelta") if venta.lineas.all? { |vl| vl.reload.cantidad_pendiente.zero? }
      devolucion
    end
  end

  def self.preparar_linea(sucursal, l, autorizador)
    etiqueta = l[:etiqueta_id].present? ? Etiqueta.find(l[:etiqueta_id]) : nil
    if etiqueta
      raise Error, "la etiqueta #{etiqueta.codigo} no está viva (#{etiqueta.estado})" unless etiqueta.viva?
      raise Error, "la etiqueta #{etiqueta.codigo} no es de esta sucursal" unless etiqueta.sucursal_id == sucursal.id
      raise Error, "la etiqueta #{etiqueta.codigo} es una #{etiqueta.tipo}: escanea los paquetes" unless etiqueta.paquete? || (etiqueta.caja? && etiqueta.producto)
      producto = etiqueta.producto
      cantidad = etiqueta.cantidad
    else
      producto = Producto.activos.find(l[:producto_id])
      cantidad = BigDecimal(l[:cantidad].to_s).round(3)
      raise Error, "#{producto.nombre}: cantidad inválida" unless cantidad.positive?
      raise Error, "#{producto.nombre} va por piezas enteras" if !producto.kg? && cantidad != cantidad.floor
    end
    catalogo = producto.precio_centavos
    precio = l[:precio_centavos].present? ? l[:precio_centavos].to_i : catalogo
    autoriza = nil
    if precio < catalogo
      raise Error, "#{producto.nombre}: el precio no puede bajar de la mitad del catálogo (#{Dinero.pesos((catalogo * PISO_PRECIO).ceil)})" if precio < catalogo * PISO_PRECIO
      raise Error, "#{producto.nombre}: bajar el precio necesita el PIN de quien pueda autorizarlo" unless autorizador&.puede?("caja.bajar_precio")
      autoriza = autorizador
    end
    { producto: producto, etiqueta: etiqueta, cantidad: cantidad, precio_centavos: precio, catalogo_centavos: catalogo,
      importe_centavos: Dinero.importe(cantidad, precio), autorizado_por: autoriza }
  end
  private_class_method :preparar_linea

  def self.preparar_pagos(pagos, total)
    limpios = Array(pagos).map { |p| { forma: p[:forma].to_s, monto_centavos: p[:monto_centavos].to_i } }.reject { |p| p[:monto_centavos] <= 0 }
    limpios.each { |p| raise Error, "forma de pago desconocida: #{p[:forma]}" unless Pago::FORMAS.include?(p[:forma]) }
    suma = limpios.sum { |p| p[:monto_centavos] }
    raise Error, "falta dinero: el ticket es #{Dinero.pesos(total)} y se pagan #{Dinero.pesos(suma)}" if suma < total
    no_efectivo = limpios.reject { |p| p[:forma] == "efectivo" }.sum { |p| p[:monto_centavos] }
    raise Error, "una transferencia o depósito no puede pasarse del total" if no_efectivo > total
    limpios
  end
  private_class_method :preparar_pagos

  def self.codigo_ticket(sucursal)
    secuencia = Contador.siguiente!("ticket:#{sucursal.id}")
    Barcode.ean13(format("09%02d%08d", sucursal.id % 100, secuencia % 100_000_000))
  end
  private_class_method :codigo_ticket
end
