# Nota de salida entre sucursales. Se surte escaneando cajas, tarimas o paquetes; otra persona
# verifica la carga; se sella; se envía (el kardex del origen baja y las etiquetas viajan);
# el destino recibe paquete por paquete o tarima entera y reporta lo roto o perdido.
class Salida < ApplicationRecord
  TIPOS = %w[traspaso devolucion reparto].freeze
  ESTADOS = %w[preparando sellada enviada recibida entregada rechazada cancelada].freeze

  belongs_to :sucursal_origen, class_name: "Sucursal"
  belongs_to :sucursal_destino, class_name: "Sucursal", optional: true
  belongs_to :cliente, optional: true
  belongs_to :ruta, optional: true
  belongs_to :venta, optional: true
  belongs_to :viaje, optional: true
  belongs_to :usuario
  belongs_to :verificado_por, class_name: "Usuario", optional: true
  has_many :salida_etiquetas, dependent: :destroy
  has_many :etiquetas, through: :salida_etiquetas
  has_many :lineas, class_name: "SalidaLinea", dependent: :destroy
  has_many :canastillas, class_name: "SalidaCanastilla", dependent: :destroy

  before_validation :asignar_folio, on: :create

  validates :folio, presence: true, uniqueness: { scope: :sucursal_origen_id }
  validates :tipo, inclusion: { in: TIPOS }
  validates :estado, inclusion: { in: ESTADOS }
  validates :motivo, presence: true, if: :devolucion?
  validate :destino_coherente

  scope :abiertas, -> { where(estado: %w[preparando sellada]) }
  scope :en_transito, -> { where(estado: "enviada") }

  def devolucion? = tipo == "devolucion"
  def reparto? = tipo == "reparto"
  def entregada? = estado == "entregada"
  def rechazada? = estado == "rechazada"

  def destino
    cliente || sucursal_destino
  end
  def preparando? = estado == "preparando"
  def sellada? = estado == "sellada"
  def enviada? = estado == "enviada"
  def abierta? = preparando? || sellada?

  # `destino` es una Sucursal (traspaso o devolución) o un Cliente (reparto de contado).
  def self.nueva!(origen:, destino:, usuario:, motivo: nil)
    if destino.is_a?(Cliente)
      create!(tipo: "reparto", sucursal_origen: origen, cliente: destino, ruta: destino.ruta, usuario: usuario, motivo: motivo)
    else
      tipo = origen.matriz? ? "traspaso" : "devolucion"
      create!(tipo: tipo, sucursal_origen: origen, sucursal_destino: destino, usuario: usuario, motivo: motivo)
    end
  end

  # La salida que se está armando para el destino de un pedido; si no hay, la abre. Así la caja
  # que nace de un renglón entra sola a la salida, sin volver a escanearla.
  def self.para_pedido!(pedido, usuario:)
    armandose_para(pedido) || nueva!(origen: pedido.sucursal_origen, destino: pedido.destino, usuario: usuario)
  end

  def self.armandose_para(pedido)
    where(sucursal_origen: pedido.sucursal_origen, sucursal_destino_id: pedido.sucursal_destino_id, cliente_id: pedido.cliente_id, estado: "preparando").order(:created_at).first
  end

  # Mete una etiqueta recién registrada sin escanearla. Tolera lo que ya estaba: las pesadas que
  # entraron al vuelo como sueltas y ahora se cerraron en caja se reagrupan bajo la caja.
  # Devuelve cuántas hojas entraron nuevas.
  def acomodar!(etiqueta)
    raise ArgumentError, I18n.t("errores.salida.esta", estado: I18n.t("estados.#{estado}")) unless preparando?
    hojas = Salida.hojas_de(etiqueta)
    ajena = SalidaEtiqueta.joins(:salida).where(etiqueta: hojas, salidas: { estado: %w[preparando sellada enviada] }).where.not(salida_id: id).first
    raise ArgumentError, I18n.t("errores.salida.ya_va_en", codigo: ajena.etiqueta.codigo, folio: ajena.salida.folio) if ajena
    transaction do
      puestas = salida_etiquetas.where(etiqueta: hojas).to_a
      puestas.each { |f| f.update!(grupo: (f.etiqueta_id == etiqueta.id ? nil : etiqueta)) }
      (hojas - puestas.map(&:etiqueta)).each { |h| salida_etiquetas.create!(etiqueta: h, grupo: (h == etiqueta ? nil : etiqueta)) }
      hojas.size - puestas.size
    end
  end

  # --- surtir: escanear una etiqueta viva y suelta del origen; se expande a sus hojas.
  def agregar!(etiqueta)
    raise ArgumentError, I18n.t("errores.salida.esta", estado: I18n.t("estados.#{estado}")) unless preparando?
    raise ArgumentError, I18n.t("errores.salida.no_viva", codigo: etiqueta.codigo) unless etiqueta.viva?
    raise ArgumentError, I18n.t("errores.salida.no_esta_en", codigo: etiqueta.codigo, sucursal: sucursal_origen.nombre) unless etiqueta.sucursal_id == sucursal_origen_id
    raise ArgumentError, I18n.t("errores.salida.va_dentro", codigo: etiqueta.codigo) if etiqueta.padre_id
    hojas = Salida.hojas_de(etiqueta)
    raise ArgumentError, I18n.t("errores.salida.etiqueta_vacia", codigo: etiqueta.codigo) if hojas.empty?
    ocupada = SalidaEtiqueta.joins(:salida).where(etiqueta: hojas, salidas: { estado: %w[preparando sellada enviada] }).first
    raise ArgumentError, I18n.t("errores.salida.ya_va_en", codigo: ocupada.etiqueta.codigo, folio: ocupada.salida.folio) if ocupada
    transaction do
      hojas.each { |h| salida_etiquetas.create!(etiqueta: h, grupo: (h == etiqueta ? nil : etiqueta)) }
    end
    hojas.size
  end

  def quitar!(etiqueta)
    raise ArgumentError, I18n.t("errores.salida.esta", estado: I18n.t("estados.#{estado}")) unless preparando?
    salida_etiquetas.where(etiqueta: Salida.hojas_de(etiqueta)).destroy_all.size
  end

  # Renglón manual (sin etiqueta) con motivo: mandar sin escanear se puede, pero queda a nombre de
  # alguien. Sin autorizado_por la línea queda por revisar (ver Revision); el controlador la abre.
  def agregar_manual!(producto:, cantidad:, motivo:, autorizado_por: nil, usuario: nil)
    raise ArgumentError, I18n.t("errores.salida.esta", estado: I18n.t("estados.#{estado}")) unless preparando?
    raise ArgumentError, I18n.t("errores.salida.manual_motivo") if motivo.blank?
    lineas.create!(producto: producto, cantidad: cantidad, motivo: motivo, autorizado_por: autorizado_por, usuario: usuario || self.usuario)
  end

  # --- verificar la carga: otra persona escanea lo que sube al camión.
  def verificar!(etiqueta, usuario:)
    raise ArgumentError, I18n.t("errores.salida.esta", estado: I18n.t("estados.#{estado}")) unless preparando?
    raise ArgumentError, I18n.t("errores.salida.verificar_propia") if usuario == self.usuario
    filas = salida_etiquetas.where(etiqueta: Salida.hojas_de(etiqueta))
    raise ArgumentError, I18n.t("errores.salida.no_va", codigo: etiqueta.codigo) if filas.empty?
    filas.update_all(verificado_por_id: usuario.id, updated_at: Time.current)
  end

  def sin_verificar
    salida_etiquetas.where(verificado_por_id: nil)
  end

  # Sellar exige que otra persona haya escaneado todo. Con `sin_verificar_motivo` se sella igual
  # (mandar sin escanear se puede) y devuelve cuántos bultos quedaron sin verificar, para que el
  # controlador lo deje por revisar.
  def sellar!(usuario:, sin_verificar_motivo: nil)
    raise ArgumentError, I18n.t("errores.salida.esta", estado: I18n.t("estados.#{estado}")) unless preparando?
    raise ArgumentError, I18n.t("errores.salida.nada") if salida_etiquetas.none? && lineas.none?
    pendientes = sin_verificar.count
    raise ArgumentError, I18n.t("errores.salida.faltan_verificar", n: pendientes) if pendientes.positive? && sin_verificar_motivo.blank?
    update!(estado: "sellada", verificado_por: usuario)
    pendientes
  end

  # --- enviar: baja el kardex del origen, las etiquetas viajan y los pedidos completos se cierran.
  def enviar!(usuario:)
    raise ArgumentError, I18n.t("errores.salida.primero_sellar") unless sellada?
    transaction do
      if reparto?
        # La nota de venta se cierra aquí; se cobra de contado cuando el chofer vuelve.
        nota = Caja.nota_de_reparto!(self, usuario: usuario)
        update!(estado: "enviada", enviado_en: Time.current, venta: nota)
      else
        contenido.each do |producto, cant|
          Inventario.mover!(sucursal: sucursal_origen, producto: producto, tipo: "salida", cantidad: cant,
                            usuario: usuario, referencia: self, motivo: "#{folio} → #{destino}")
        end
        ids = salida_etiquetas.pluck(:etiqueta_id)
        Etiqueta.where(id: ids).or(Etiqueta.where(id: salida_etiquetas.pluck(:grupo_id).compact)).update_all(sucursal_id: sucursal_destino_id, updated_at: Time.current)
        update!(estado: "enviada", enviado_en: Time.current)
      end
      cerrar_pedidos_completos!
    end
  end

  # --- la parada del chofer: entrega escaneando, rechaza lo que no bajó y cobra de contado.
  def entregar!(etiqueta, usuario:)
    raise ArgumentError, I18n.t("errores.salida.solo_entrega_reparto", estado: I18n.t("estados.#{estado}")) unless reparto? && enviada?
    filas = salida_etiquetas.where(etiqueta: Salida.hojas_de_reparto(etiqueta), estado: "pendiente")
    raise ArgumentError, I18n.t("errores.salida.no_va_parada", codigo: etiqueta.codigo) if filas.empty?
    filas.update_all(estado: "recibida", recibido_en: Time.current, updated_at: Time.current)
  end

  # Todo lo pendiente se da por entregado sin escanear (queda por revisar; el controlador abre la revisión).
  def entregar_todo!
    raise ArgumentError, I18n.t("errores.salida.solo_entrega_reparto", estado: I18n.t("estados.#{estado}")) unless reparto? && enviada?
    salida_etiquetas.where(estado: "pendiente").update_all(estado: "recibida", recibido_en: Time.current, updated_at: Time.current)
  end

  def pendientes_de_entrega
    salida_etiquetas.where(estado: "pendiente")
  end

  # Canastillas que van en la salida (solo mientras se prepara). Cantidad 0 la quita.
  def fijar_canastillas!(tipo_canastilla, cantidad)
    raise ArgumentError, I18n.t("errores.salida.esta", estado: I18n.t("estados.#{estado}")) unless preparando?
    fila = canastillas.find_or_initialize_by(tipo_canastilla: tipo_canastilla)
    cantidad.to_i.positive? ? fila.update!(cantidad: cantidad.to_i) : fila.destroy
  end

  # Cuántas cajas (canastillas) de cada hoja: una caja de proveedor es 1; un paquete dentro de
  # una caja es su parte proporcional; un paquete suelto no cuenta como caja.
  def cajas_por_hoja
    filas = salida_etiquetas.includes(:etiqueta).to_a
    por_padre = filas.group_by { |f| f.etiqueta.padre_id }
    filas.each_with_object({}) do |f, h|
      e = f.etiqueta
      h[e.id] = if e.caja? then BigDecimal("1")
      elsif e.padre_id && (padre = e.padre) && padre.caja? then (BigDecimal("1") / por_padre[e.padre_id].size).round(3)
      else BigDecimal("0")
      end
    end
  end

  # Cierra la parada: lo no escaneado se rechaza (vuelve al inventario, la nota baja), y si queda
  # algo que cobrar se cobra de contado ahí mismo. Sin nada entregado la parada queda rechazada.
  def cerrar_parada!(usuario:, motivo_rechazo: nil, pagos: [], a_credito: false, rechazar_lineas: [])
    raise ArgumentError, I18n.t("errores.salida.solo_cierra_reparto", estado: I18n.t("estados.#{estado}")) unless reparto? && enviada?
    transaction do
      pendientes = pendientes_de_entrega.includes(:etiqueta).to_a
      manuales = lineas.where(id: rechazar_lineas, rechazada: false).includes(:producto).to_a
      if pendientes.any? || manuales.any?
        raise ArgumentError, I18n.t("errores.salida.sin_entregar", n: pendientes.size + manuales.size) if motivo_rechazo.blank?
        Caja.rechazar_en_ruta!(venta: venta, etiquetas: pendientes.map(&:etiqueta), lineas_manuales: manuales, motivo: motivo_rechazo, usuario: usuario)
        salida_etiquetas.where(id: pendientes.map(&:id)).update_all(estado: "faltante", motivo: motivo_rechazo, updated_at: Time.current)
        lineas.where(id: manuales.map(&:id)).update_all(rechazada: true, updated_at: Time.current)
      end
      lineas.where(rechazada: false).update_all(recibida: true, updated_at: Time.current)
      if venta.saldo_centavos.positive?
        Caja.cobrar_en_ruta!(venta: venta, pagos: pagos, usuario: usuario, a_credito: a_credito)
        update!(estado: "entregada", recibido_en: Time.current)
        # Lo rechazado se regresa con todo y canastilla: al cliente se le cargan solo las que se
        # quedó, en proporción a las cajas que aceptó (issue #10).
        proporcion = proporcion_entregada
        canastillas.includes(:tipo_canastilla).each do |c|
          entregadas = (c.cantidad * proporcion).round
          next unless entregadas.positive?
          Canastillas.mover!(tipo: "entrega", tipo_canastilla: c.tipo_canastilla, cantidad: entregadas, sucursal: sucursal_origen, usuario: usuario,
                             cliente: cliente, chofer: viaje&.chofer, viaje: viaje,
                             concepto: entregadas == c.cantidad ? I18n.t("salidas.entrega_concepto", folio: folio) : I18n.t("salidas.entrega_parcial_concepto", folio: folio, de: c.cantidad))
        end
      else
        update!(estado: "rechazada", recibido_en: Time.current)
      end
    end
    self
  end

  # Qué parte de las cajas de la salida se quedó el cliente (1 = todo). Sirve para las canastillas.
  def proporcion_entregada
    cajas = cajas_por_hoja
    total = cajas.values.sum
    return BigDecimal("1") if total.zero?
    entregadas = salida_etiquetas.where(estado: "recibida").sum { |f| cajas[f.etiqueta_id] || 0 }
    entregadas / total
  end

  # Cobro en oficina de una nota por cobrar (reparto suelto, sin viaje): el dinero entra a la caja abierta.
  def cobrar_entrega!(pagos:, usuario:)
    raise ArgumentError, I18n.t("errores.salida.solo_cobra_reparto") unless reparto? && enviada?
    raise ArgumentError, I18n.t("errores.salida.va_en_viaje", folio: viaje.folio) if viaje
    transaction do
      Caja.cobrar_pendiente!(venta: venta, pagos: pagos, usuario: usuario)
      update!(estado: "entregada", recibido_en: Time.current)
    end
  end

  # --- recibir en el destino.
  def recibir!(etiqueta, usuario:)
    raise ArgumentError, I18n.t("errores.salida.reparto_no_se_recibe") if reparto?
    raise ArgumentError, I18n.t("errores.salida.no_en_transito", estado: I18n.t("estados.#{estado}")) unless enviada?
    hojas = Salida.hojas_de(etiqueta)
    raise ArgumentError, I18n.t("errores.salida.caja_por_paquete") if etiqueta.caja? && hojas.size > 1
    filas = salida_etiquetas.where(etiqueta: hojas, estado: "pendiente").includes(etiqueta: :producto)
    raise ArgumentError, I18n.t("errores.salida.no_viene", codigo: etiqueta.codigo) if filas.empty?
    transaction do
      filas.each do |f|
        Inventario.mover!(sucursal: sucursal_destino, producto: f.etiqueta.producto, tipo: "recepcion", cantidad: f.etiqueta.cantidad,
                          usuario: usuario, etiqueta: f.etiqueta, referencia: self, motivo: "#{folio} desde #{sucursal_origen.nombre}")
        f.update!(estado: "recibida", recibido_en: Time.current)
        # En la tienda el paquete queda suelto: la caja de la matriz ya cumplió.
        f.etiqueta.update!(padre_id: nil) if f.etiqueta.padre_id
      end
      desarmar_grupos_vacios!
    end
    filas.size
  end

  # Llegó un paquete que no venía en la salida (se etiquetó por fuera y nunca entró a ella). No se
  # pierde ni se queda en el limbo: sale del origen, entra a la tienda como sobrante con motivo, y
  # queda por revisar (la revisión la abre el controlador).
  def recibir_sobrante!(etiqueta, motivo:, usuario:)
    raise ArgumentError, I18n.t("errores.salida.reparto_no_se_recibe") if reparto?
    raise ArgumentError, I18n.t("errores.salida.no_en_transito", estado: I18n.t("estados.#{estado}")) unless enviada?
    raise ArgumentError, I18n.t("errores.hace_falta_motivo") if motivo.blank?
    raise ArgumentError, I18n.t("errores.salida.etiqueta_esta", codigo: etiqueta.codigo, estado: I18n.t("estados.#{etiqueta.estado}")) unless etiqueta.viva?
    raise ArgumentError, I18n.t("errores.salida.es_grupo", codigo: etiqueta.codigo, tipo: I18n.t("etiquetas.tipos.#{etiqueta.tipo}")) unless etiqueta.paquete? || (etiqueta.caja? && etiqueta.hijas.none?)
    raise ArgumentError, I18n.t("errores.salida.si_viene", codigo: etiqueta.codigo) if salida_etiquetas.exists?(etiqueta: etiqueta)
    raise ArgumentError, I18n.t("errores.salida.de_otra_sucursal", codigo: etiqueta.codigo, de: etiqueta.sucursal.nombre, origen: sucursal_origen.nombre) unless etiqueta.sucursal_id == sucursal_origen_id
    if (otra = SalidaEtiqueta.joins(:salida).where(etiqueta: etiqueta, salidas: { estado: %w[preparando sellada enviada] }).includes(:salida).first)
      raise ArgumentError, I18n.t("errores.salida.recibela_alla", codigo: etiqueta.codigo, folio: otra.salida.folio)
    end
    transaction do
      # El origen no lo descontó al enviar esta salida: se descuenta ahora, con el mismo rastro.
      Inventario.mover!(sucursal: sucursal_origen, producto: etiqueta.producto, tipo: "salida", cantidad: etiqueta.cantidad,
                        usuario: usuario, etiqueta: etiqueta, referencia: self, motivo: "#{folio} sobrante: #{motivo}")
      Inventario.mover!(sucursal: sucursal_destino, producto: etiqueta.producto, tipo: "recepcion", cantidad: etiqueta.cantidad,
                        usuario: usuario, etiqueta: etiqueta, referencia: self, motivo: "#{folio} sobrante: #{motivo}")
      padre = etiqueta.padre
      etiqueta.update!(sucursal_id: sucursal_destino_id, padre_id: nil)
      padre&.recalcular_contenido!
      salida_etiquetas.create!(etiqueta: etiqueta, estado: "sobrante", motivo: motivo, recibido_en: Time.current)
    end
  end

  def recibir_lineas!(usuario:)
    raise ArgumentError, I18n.t("errores.salida.no_en_transito", estado: I18n.t("estados.#{estado}")) unless enviada?
    transaction do
      lineas.where(recibida: false).includes(:producto).each do |l|
        Inventario.mover!(sucursal: sucursal_destino, producto: l.producto, tipo: "recepcion", cantidad: l.cantidad,
                          usuario: usuario, referencia: self, motivo: "#{folio} manual: #{l.motivo}")
        l.update!(recibida: true)
      end
    end
  end

  # Lo que no llegó o llegó sin etiqueta: no suma al stock, queda el barcode exacto y la etiqueta muere.
  def reportar!(etiqueta, motivo:, usuario:)
    raise ArgumentError, I18n.t("errores.salida.no_en_transito", estado: I18n.t("estados.#{estado}")) unless enviada?
    raise ArgumentError, I18n.t("errores.hace_falta_motivo") if motivo.blank?
    filas = salida_etiquetas.where(etiqueta: Salida.hojas_de(etiqueta), estado: "pendiente").includes(:etiqueta)
    raise ArgumentError, I18n.t("errores.salida.no_pendiente", codigo: etiqueta.codigo) if filas.empty?
    transaction do
      filas.each do |f|
        f.update!(estado: "faltante", motivo: motivo)
        f.etiqueta.update!(estado: "baja", motivo: "#{folio}: #{motivo}", padre_id: nil)
      end
      desarmar_grupos_vacios!
    end
    filas.size
  end

  # Qué dice cada caja (o tarima, o paquete suelto) contra lo que de verdad llegó: cantidad y
  # paquetes esperados, recibidos, y los códigos de lo que falta. Sirve en vivo mientras se recibe
  # y es lo que se canta al cerrar.
  Canto = Struct.new(:grupo, :producto, :esperado, :recibido, :paquetes, :recibidos, :faltan, keyword_init: true) do
    def diferencia = esperado - recibido
    def completo? = faltan.empty?
  end

  def resumen_por_caja
    salida_etiquetas.includes(etiqueta: :producto, grupo: :producto).group_by(&:grupo).map do |grupo, filas|
      vivas = filas.reject { |f| f.estado == "sobrante" }
      llegaron = vivas.select { |f| f.estado == "recibida" }
      Canto.new(grupo: grupo, producto: (grupo&.producto || vivas.first&.etiqueta&.producto),
                esperado: vivas.sum { |f| f.etiqueta.cantidad }, recibido: llegaron.sum { |f| f.etiqueta.cantidad },
                paquetes: vivas.size, recibidos: llegaron.size, faltan: (vivas - llegaron).map { |f| f.etiqueta.codigo })
    end
  end

  # El canto en texto, una línea por caja con diferencia, para la salida y para la bandeja de revisión.
  def canto_de_recepcion
    resumen_por_caja.reject(&:completo?).map do |c|
      nombre = c.grupo ? "#{I18n.t("etiquetas.tipos.#{c.grupo.tipo}")} #{c.grupo.codigo}" : I18n.t("salidas.suelto")
      dec = c.producto&.decimales || 3
      cifra = ->(n) { ActiveSupport::NumberHelper.number_to_rounded(n, precision: dec) }
      I18n.t("salidas.canto", caja: nombre, producto: c.producto&.nombre, esperado: cifra.(c.esperado), paquetes: c.paquetes,
             recibido: cifra.(c.recibido), recibidos: c.recibidos, faltan: cifra.(c.diferencia), unidad: c.producto&.unidad_corta, codigos: c.faltan.join(", "))
    end.join("\n")
  end

  # Cierra la recepción: lo pendiente se reporta como faltante con el motivo dado, se canta la
  # diferencia por caja y, si faltó algo, queda por revisar con su valor a precio de la tienda.
  def cerrar_recepcion!(usuario:, motivo_pendientes: nil)
    raise ArgumentError, I18n.t("errores.salida.no_en_transito", estado: I18n.t("estados.#{estado}")) unless enviada?
    transaction do
      pendientes = salida_etiquetas.where(estado: "pendiente").includes(:etiqueta)
      if pendientes.exists?
        raise ArgumentError, I18n.t("errores.salida.sin_recibir", n: pendientes.count) if motivo_pendientes.blank?
        pendientes.each { |f| reportar!(f.etiqueta, motivo: motivo_pendientes, usuario: usuario) }
      end
      recibir_lineas!(usuario: usuario) if lineas.where(recibida: false).exists?
      canto = canto_de_recepcion
      update!(estado: "recibida", recibido_en: Time.current, diferencias: canto.presence)
      if canto.present?
        valor = salida_etiquetas.where(estado: "faltante").includes(etiqueta: :producto).sum { |f| Revision.valor(f.etiqueta.cantidad, f.etiqueta.producto, sucursal_destino) }
        Revision.abrir!(self, usuario: usuario, sucursal: sucursal_destino, motivo: I18n.t("salidas.avisos.faltantes_al_recibir", folio: folio, canto: canto), valor_centavos: valor)
      end
    end
  end

  def cancelar!
    raise ArgumentError, I18n.t("errores.salida.solo_cancela_antes") unless abierta?
    transaction do
      salida_etiquetas.destroy_all
      lineas.destroy_all
      update!(estado: "cancelada")
    end
  end

  # { producto => cantidad } de etiquetas y renglones manuales.
  def contenido
    acc = Hash.new(BigDecimal("0"))
    salida_etiquetas.includes(etiqueta: :producto).each { |f| acc[f.etiqueta.producto] += f.etiqueta.cantidad }
    lineas.vivas.includes(:producto).each { |l| acc[l.producto] += l.cantidad }
    acc
  end

  def pedidos
    Pedido.where(id: PedidoLinea.where(id: etiquetas.select(:pedido_linea_id)).select(:pedido_id))
  end

  def self.hojas_de(etiqueta)
    etiqueta.hojas_vivas
  end

  # En un reparto las hojas ya están "vendidas" (la nota se cerró al salir): se buscan por estado vendida.
  def self.hojas_de_reparto(etiqueta)
    return [ etiqueta ] if etiqueta.hijas.none?
    Etiqueta.where(padre_id: etiqueta.id, estado: "vendida").flat_map { |h| hojas_de_reparto(h) }
  end

  def to_s
    folio
  end

  private

  def asignar_folio
    self.folio ||= Folio.siguiente!(sucursal_origen, { "devolucion" => "DV", "reparto" => "R" }.fetch(tipo, "S")) if sucursal_origen
  end

  def destino_coherente
    if reparto?
      errors.add(:cliente, I18n.t("errores.salida.cliente_obligatorio")) if cliente.nil?
    else
      errors.add(:sucursal_destino, I18n.t("errores.salida.destino_obligatorio")) if sucursal_destino.nil?
      errors.add(:sucursal_destino, I18n.t("errores.salida.destino_no_origen")) if sucursal_origen_id == sucursal_destino_id
    end
  end

  # Las cajas y tarimas que viajaron y ya no tienen nada dentro se dan de baja: su trabajo terminó.
  def desarmar_grupos_vacios!
    ids = salida_etiquetas.where.not(grupo_id: nil).distinct.pluck(:grupo_id)
    ids += Etiqueta.where(id: ids).where.not(padre_id: nil).pluck(:padre_id)
    Etiqueta.where(id: ids.uniq).vivas.each do |g|
      next if Etiqueta.where(padre_id: g.id).vivas.exists?
      g.update!(estado: "baja", motivo: I18n.t("salidas.avisos.desarmada", folio: folio), padre_id: nil)
    end
  end

  def cerrar_pedidos_completos!
    pedidos.abiertos.includes(:lineas).each do |p|
      p.update!(estado: "cerrado") if p.resuelto?
    end
  end
end
