# Nota de salida entre sucursales. Se surte escaneando cajas, tarimas o paquetes; otra persona
# verifica la carga; se sella; se envía (el kardex del origen baja y las etiquetas viajan);
# el destino recibe paquete por paquete o tarima entera y reporta lo roto o perdido.
class Salida < ApplicationRecord
  TIPOS = %w[traspaso devolucion].freeze
  ESTADOS = %w[preparando sellada enviada recibida cancelada].freeze

  belongs_to :sucursal_origen, class_name: "Sucursal"
  belongs_to :sucursal_destino, class_name: "Sucursal"
  belongs_to :usuario
  belongs_to :verificado_por, class_name: "Usuario", optional: true
  has_many :salida_etiquetas, dependent: :destroy
  has_many :etiquetas, through: :salida_etiquetas
  has_many :lineas, class_name: "SalidaLinea", dependent: :destroy

  before_validation :asignar_folio, on: :create

  validates :folio, presence: true, uniqueness: true
  validates :tipo, inclusion: { in: TIPOS }
  validates :estado, inclusion: { in: ESTADOS }
  validates :motivo, presence: true, if: :devolucion?
  validate :destino_distinto

  scope :abiertas, -> { where(estado: %w[preparando sellada]) }
  scope :en_transito, -> { where(estado: "enviada") }

  def devolucion? = tipo == "devolucion"
  def preparando? = estado == "preparando"
  def sellada? = estado == "sellada"
  def enviada? = estado == "enviada"
  def abierta? = preparando? || sellada?

  def self.nueva!(origen:, destino:, usuario:, motivo: nil)
    tipo = origen.matriz? ? "traspaso" : "devolucion"
    create!(tipo: tipo, sucursal_origen: origen, sucursal_destino: destino, usuario: usuario, motivo: motivo)
  end

  # --- surtir: escanear una etiqueta viva y suelta del origen; se expande a sus hojas.
  def agregar!(etiqueta)
    raise ArgumentError, "la salida está #{estado}" unless preparando?
    raise ArgumentError, "la etiqueta #{etiqueta.codigo} no está viva" unless etiqueta.viva?
    raise ArgumentError, "la etiqueta #{etiqueta.codigo} no está en #{sucursal_origen.nombre}" unless etiqueta.sucursal_id == sucursal_origen_id
    raise ArgumentError, "la etiqueta #{etiqueta.codigo} va dentro de otra: escanea la caja o la tarima" if etiqueta.padre_id
    hojas = Salida.hojas_de(etiqueta)
    raise ArgumentError, "la etiqueta #{etiqueta.codigo} está vacía" if hojas.empty?
    ocupada = SalidaEtiqueta.joins(:salida).where(etiqueta: hojas, salidas: { estado: %w[preparando sellada enviada] }).first
    raise ArgumentError, "#{ocupada.etiqueta.codigo} ya va en la salida #{ocupada.salida.folio}" if ocupada
    transaction do
      hojas.each { |h| salida_etiquetas.create!(etiqueta: h, grupo: (h == etiqueta ? nil : etiqueta)) }
    end
    hojas.size
  end

  def quitar!(etiqueta)
    raise ArgumentError, "la salida está #{estado}" unless preparando?
    salida_etiquetas.where(etiqueta: Salida.hojas_de(etiqueta)).destroy_all.size
  end

  # Renglón manual (sin etiqueta), solo en devoluciones y con quien lo autoriza.
  def agregar_manual!(producto:, cantidad:, motivo:, autorizado_por:)
    raise ArgumentError, "la salida está #{estado}" unless preparando?
    raise ArgumentError, "sin etiqueta solo se devuelve, y con justificación" unless devolucion? && motivo.present? && autorizado_por
    lineas.create!(producto: producto, cantidad: cantidad, motivo: motivo, autorizado_por: autorizado_por)
  end

  # --- verificar la carga: otra persona escanea lo que sube al camión.
  def verificar!(etiqueta, usuario:)
    raise ArgumentError, "la salida está #{estado}" unless preparando?
    raise ArgumentError, "quien surte no puede verificar su propia carga" if usuario == self.usuario
    filas = salida_etiquetas.where(etiqueta: Salida.hojas_de(etiqueta))
    raise ArgumentError, "#{etiqueta.codigo} no va en esta salida" if filas.empty?
    filas.update_all(verificado_por_id: usuario.id, updated_at: Time.current)
  end

  def sin_verificar
    salida_etiquetas.where(verificado_por_id: nil)
  end

  def sellar!(usuario:)
    raise ArgumentError, "la salida está #{estado}" unless preparando?
    raise ArgumentError, "no hay nada en la salida" if salida_etiquetas.none? && lineas.none?
    raise ArgumentError, "faltan #{sin_verificar.count} etiquetas por verificar" if sin_verificar.exists?
    update!(estado: "sellada", verificado_por: usuario)
  end

  # --- enviar: baja el kardex del origen, las etiquetas viajan y los pedidos completos se cierran.
  def enviar!(usuario:)
    raise ArgumentError, "primero hay que sellar la salida" unless sellada?
    transaction do
      contenido.each do |producto, cant|
        Inventario.mover!(sucursal: sucursal_origen, producto: producto, tipo: "salida", cantidad: cant,
                          usuario: usuario, referencia: self, motivo: "#{folio} → #{sucursal_destino.nombre}")
      end
      ids = salida_etiquetas.pluck(:etiqueta_id)
      Etiqueta.where(id: ids).or(Etiqueta.where(id: salida_etiquetas.pluck(:grupo_id).compact)).update_all(sucursal_id: sucursal_destino_id, updated_at: Time.current)
      update!(estado: "enviada", enviado_en: Time.current)
      cerrar_pedidos_completos!
    end
  end

  # --- recibir en el destino.
  def recibir!(etiqueta, usuario:)
    raise ArgumentError, "la salida no está en tránsito (#{estado})" unless enviada?
    hojas = Salida.hojas_de(etiqueta)
    raise ArgumentError, "una caja se recibe paquete por paquete; la tarima entera sí" if etiqueta.caja? && hojas.size > 1
    filas = salida_etiquetas.where(etiqueta: hojas, estado: "pendiente").includes(etiqueta: :producto)
    raise ArgumentError, "#{etiqueta.codigo} no viene en esta salida o ya se recibió" if filas.empty?
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

  def recibir_lineas!(usuario:)
    raise ArgumentError, "la salida no está en tránsito (#{estado})" unless enviada?
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
    raise ArgumentError, "la salida no está en tránsito (#{estado})" unless enviada?
    raise ArgumentError, "hace falta el motivo" if motivo.blank?
    filas = salida_etiquetas.where(etiqueta: Salida.hojas_de(etiqueta), estado: "pendiente").includes(:etiqueta)
    raise ArgumentError, "#{etiqueta.codigo} no está pendiente en esta salida" if filas.empty?
    transaction do
      filas.each do |f|
        f.update!(estado: "faltante", motivo: motivo)
        f.etiqueta.update!(estado: "baja", motivo: "#{folio}: #{motivo}", padre_id: nil)
      end
      desarmar_grupos_vacios!
    end
    filas.size
  end

  # Cierra la recepción: lo pendiente se reporta como faltante con el motivo dado.
  def cerrar_recepcion!(usuario:, motivo_pendientes: nil)
    raise ArgumentError, "la salida no está en tránsito (#{estado})" unless enviada?
    transaction do
      pendientes = salida_etiquetas.where(estado: "pendiente").includes(:etiqueta)
      if pendientes.exists?
        raise ArgumentError, "quedan #{pendientes.count} paquetes sin recibir: escanéalos o da el motivo del faltante" if motivo_pendientes.blank?
        pendientes.each { |f| reportar!(f.etiqueta, motivo: motivo_pendientes, usuario: usuario) }
      end
      recibir_lineas!(usuario: usuario) if lineas.where(recibida: false).exists?
      update!(estado: "recibida", recibido_en: Time.current)
    end
  end

  def cancelar!
    raise ArgumentError, "solo se cancela antes de enviar" unless abierta?
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
    lineas.includes(:producto).each { |l| acc[l.producto] += l.cantidad }
    acc
  end

  def pedidos
    Pedido.where(id: PedidoLinea.where(id: etiquetas.select(:pedido_linea_id)).select(:pedido_id))
  end

  # Hojas de una etiqueta: ella misma si es paquete o caja de proveedor; si no, todo lo de abajo.
  def self.hojas_de(etiqueta)
    hijas = etiqueta.hijas.vivas.to_a
    return [ etiqueta ] if hijas.empty? && !etiqueta.tarima?
    hijas.flat_map { |h| hojas_de(h) }
  end

  def to_s
    folio
  end

  private

  def asignar_folio
    self.folio ||= Folio.siguiente!(sucursal_origen, devolucion? ? "DV" : "S") if sucursal_origen
  end

  def destino_distinto
    errors.add(:sucursal_destino, "no puede ser el origen") if sucursal_origen_id == sucursal_destino_id
  end

  # Las cajas y tarimas que viajaron y ya no tienen nada dentro se dan de baja: su trabajo terminó.
  def desarmar_grupos_vacios!
    ids = salida_etiquetas.where.not(grupo_id: nil).distinct.pluck(:grupo_id)
    ids += Etiqueta.where(id: ids).where.not(padre_id: nil).pluck(:padre_id)
    Etiqueta.where(id: ids.uniq).vivas.each do |g|
      next if Etiqueta.where(padre_id: g.id).vivas.exists?
      g.update!(estado: "baja", motivo: "#{folio}: desarmada al recibir", padre_id: nil)
    end
  end

  def cerrar_pedidos_completos!
    pedidos.abiertos.includes(:lineas).each do |p|
      p.update!(estado: "cerrado") if p.resuelto?
    end
  end
end
