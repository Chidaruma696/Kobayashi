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

  # Nota de venta de un reparto: las etiquetas de la salida, al precio de la matriz (con promociones),
  # por cobrar. El inventario sale aquí y las etiquetas quedan vendidas.
  def self.nota_de_reparto!(salida, usuario:)
    sucursal = salida.sucursal_origen
    corte = Corte.abierto_en(sucursal) or raise Error, "no hay caja abierta en #{sucursal.nombre}: ábrela antes de enviar el reparto"
    hojas = salida.salida_etiquetas.includes(etiqueta: :producto).map(&:etiqueta)
    manuales = salida.lineas.includes(:producto).to_a
    raise Error, "la salida está vacía" if hojas.empty? && manuales.empty?
    cajas = salida.cajas_por_hoja
    Venta.transaction do
      preparadas = hojas.map { |e| preparar_linea(sucursal, { etiqueta_id: e.id }, nil).merge(cajas: cajas[e.id]) } +
                   manuales.map { |l| preparar_linea(sucursal, { producto_id: l.producto_id, cantidad: l.cantidad }, nil) }
      preparadas = salida.cliente.convenio.aplicar(preparadas, Date.current) if salida.cliente.convenio
      preparadas.each { |l| l.delete(:cajas) }
      total = preparadas.sum { |l| l[:importe_centavos] }
      venta = Venta.create!(sucursal: sucursal, corte: corte, usuario: usuario, cliente: salida.cliente, clave: "reparto:#{salida.id}",
                            folio: Folio.siguiente!(sucursal, "B"), codigo: codigo_ticket(sucursal), estado: "por_cobrar",
                            total_centavos: total, cambio_centavos: 0, fecha_negocio: Date.current)
      preparadas.each do |l|
        linea = venta.lineas.create!(l)
        Inventario.mover!(sucursal: sucursal, producto: linea.producto, tipo: "venta", cantidad: linea.cantidad,
                          usuario: usuario, etiqueta: linea.etiqueta, referencia: venta, motivo: "#{venta.folio} reparto #{salida.folio}")
        linea.etiqueta&.update!(estado: "vendida")
      end
      venta
    end
  end

  # Cobra una nota por cobrar (reparto) en la caja abierta de ahora.
  def self.cobrar_pendiente!(venta:, pagos:, usuario:)
    raise Error, "la nota #{venta.folio} no está por cobrar (#{venta.estado})" unless venta.por_cobrar?
    corte = Corte.abierto_en(venta.sucursal) or raise Error, "no hay caja abierta en #{venta.sucursal.nombre}"
    pagos_ok = preparar_pagos(pagos, venta.saldo_centavos)
    Venta.transaction do
      pagos_ok.each { |p| venta.pagos.create!(p) }
      venta.update!(estado: "cobrada", corte: corte, usuario: usuario, cambio_centavos: pagos_ok.sum { |p| p[:monto_centavos] } - venta.saldo_centavos)
    end
    venta
  end

  # El chofer cobra en la parada. Lo que paga queda en la nota; lo que no paga se va a la cuenta
  # del cliente si su crédito lo permite. El dinero entra a la caja hasta liquidar el viaje
  # (marca en_ruta: el corte no la cuenta todavía).
  def self.cobrar_en_ruta!(venta:, pagos:, usuario:, a_credito: false)
    raise Error, "la nota #{venta.folio} no está por cobrar (#{venta.estado})" unless venta.por_cobrar?
    saldo = venta.saldo_centavos
    limpios = Array(pagos).map { |p| { forma: p[:forma].to_s, monto_centavos: p[:monto_centavos].to_i } }.reject { |p| p[:monto_centavos] <= 0 }
    suma = limpios.sum { |p| p[:monto_centavos] }
    Venta.transaction do
      if suma >= saldo
        pagos_ok = preparar_pagos(limpios, saldo)
        pagos_ok.each { |p| venta.pagos.create!(p) }
        venta.update!(estado: "cobrada", en_ruta: true, cambio_centavos: suma - saldo)
      else
        raise Error, "falta dinero: la nota es #{Dinero.pesos(saldo)} y se pagan #{Dinero.pesos(suma)}; marca el resto a crédito si el cliente lo tiene" unless a_credito
        cliente = venta.cliente or raise Error, "la nota no tiene cliente"
        estado = Credito.evaluar(cliente)
        raise Error, "#{cliente.nombre} no tiene crédito (#{estado.regla.downcase})" if cliente.credito == "contado"
        raise Error, "#{cliente.nombre} está bloqueado: #{estado.motivo}" if estado.bloqueado
        limpios.each { |p| raise Error, "forma de pago desconocida: #{p[:forma]}" unless Pago::FORMAS.include?(p[:forma]) }
        limpios.each { |p| venta.pagos.create!(p) }
        venta.update!(estado: "a_credito", en_ruta: true, cambio_centavos: 0)
        cliente.movimientos_credito.create!(tipo: "cargo", monto_centavos: saldo - suma, fecha: Date.current, referencia: venta,
                                            usuario: usuario, motivo: "Nota #{venta.folio} a crédito")
      end
    end
    venta
  end

  # El cliente no quiso estos bultos: vuelven al inventario de la matriz y la nota baja.
  # No hay dinero de por medio, así que la devolución no toca ningún corte.
  def self.rechazar_en_ruta!(venta:, etiquetas:, motivo:, usuario:, lineas_manuales: [])
    raise Error, "hace falta el motivo del rechazo" if motivo.blank?
    raise Error, "la nota #{venta.folio} ya está #{venta.estado}" unless venta.por_cobrar?
    Venta.transaction do
      devolucion = Devolucion.new(venta: venta, sucursal: venta.sucursal, usuario: usuario, motivo: motivo, total_centavos: 0)
      total = 0
      renglones = etiquetas.map { |e| [ venta.lineas.find_by!(etiqueta: e), e ] }
      renglones += lineas_manuales.map { |l| [ venta.lineas.where(etiqueta: nil, producto_id: l.producto_id).find { |vl| vl.cantidad == l.cantidad && vl.cantidad_pendiente.positive? } || raise(Error, "no encuentro en la nota el renglón de #{l.producto.nombre}"), nil ] }
      renglones.each do |vl, e|
        importe = Dinero.importe(vl.cantidad_pendiente, vl.precio_centavos)
        total += importe
        devolucion.lineas.build(venta_linea: vl, cantidad: vl.cantidad_pendiente, importe_centavos: importe)
        Inventario.mover!(sucursal: venta.sucursal, producto: vl.producto, tipo: "devolucion_cliente", cantidad: vl.cantidad_pendiente,
                          usuario: usuario, etiqueta: e, referencia: devolucion, motivo: "#{venta.folio} rechazo en ruta: #{motivo}")
        e&.update!(estado: "viva", padre_id: nil)
      end
      devolucion.total_centavos = total
      devolucion.save!
      venta.update!(estado: "devuelta") if venta.saldo_centavos.zero?
      devolucion
    end
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
      raise Error, "la etiqueta #{etiqueta.codigo} está en tránsito: recibe la salida antes de vender" if etiqueta.en_transito?
      raise Error, "la etiqueta #{etiqueta.codigo} es una #{etiqueta.tipo}: escanea los paquetes" unless etiqueta.paquete? || (etiqueta.caja? && etiqueta.producto)
      producto = etiqueta.producto
      cantidad = etiqueta.cantidad
    else
      producto = Producto.activos.find(l[:producto_id])
      cantidad = BigDecimal(l[:cantidad].to_s).round(3)
      raise Error, "#{producto.nombre}: cantidad inválida" unless cantidad.positive?
      raise Error, "#{producto.nombre} va por piezas enteras" if !producto.kg? && cantidad != cantidad.floor
    end
    catalogo = producto.precio_centavos_en(sucursal)
    promo_precio, promocion = Promocion.mejor(producto, sucursal, cantidad, catalogo)
    legitimo = promo_precio || catalogo
    precio = l[:precio_centavos].present? ? l[:precio_centavos].to_i : legitimo
    autoriza = nil
    if precio < legitimo
      raise Error, "#{producto.nombre}: el precio no puede bajar de la mitad del catálogo (#{Dinero.pesos((catalogo * PISO_PRECIO).ceil)})" if precio < catalogo * PISO_PRECIO
      raise Error, "#{producto.nombre}: bajar el precio necesita el PIN de quien pueda autorizarlo" unless autorizador&.puede?("caja.bajar_precio")
      autoriza = autorizador
    end
    { producto: producto, etiqueta: etiqueta, cantidad: cantidad, precio_centavos: precio, catalogo_centavos: catalogo,
      importe_centavos: Dinero.importe(cantidad, precio), autorizado_por: autoriza, promocion: (precio == promo_precio ? promocion : nil) }
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
