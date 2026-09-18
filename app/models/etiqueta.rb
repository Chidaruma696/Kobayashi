class Etiqueta < ApplicationRecord
  TIPOS = %w[paquete caja tarima].freeze
  ESTADOS = %w[viva vendida baja].freeze
  INTENTOS_CODIGO = 10

  # Las cajas y tarimas creadas al agrupar heredan el contexto de sus hijas.
  attr_accessor :agrupando

  belongs_to :producto, optional: true
  belongs_to :sucursal
  belongs_to :usuario
  belongs_to :padre, class_name: "Etiqueta", optional: true
  belongs_to :pedido_linea, optional: true
  belongs_to :produccion, optional: true
  belongs_to :autorizado_por, class_name: "Usuario", optional: true
  has_many :hijas, class_name: "Etiqueta", foreign_key: :padre_id, dependent: :restrict_with_error, inverse_of: :padre
  has_many :movimientos, dependent: :restrict_with_error
  has_many :venta_lineas, dependent: :restrict_with_error
  has_many :salida_etiquetas, dependent: :restrict_with_error

  before_validation :asignar_codigo, on: :create

  validates :tipo, inclusion: { in: TIPOS }
  validates :estado, inclusion: { in: ESTADOS }
  validates :codigo, presence: true, uniqueness: true, length: { is: 13 }
  validates :cantidad, numericality: { greater_than_or_equal_to: 0 }
  validate :contenido_coherente
  validate :contexto_obligatorio, on: :create
  validate :cabe_en_la_produccion, on: :create
  after_save :recalcular_renglon

  scope :vivas, -> { where(estado: "viva") }
  scope :sueltas, -> { where(padre_id: nil) }
  # Lo que cuenta como mercancía: paquetes y cajas sin hijas (cajas de proveedor). Nunca tarimas.
  scope :hojas, -> { where(tipo: "paquete").or(where(tipo: "caja").where.not("EXISTS (SELECT 1 FROM etiquetas h WHERE h.padre_id = etiquetas.id)")) }
  scope :recientes, -> { order(created_at: :desc) }

  def paquete? = tipo == "paquete"
  def caja? = tipo == "caja"
  def tarima? = tipo == "tarima"
  def viva? = estado == "viva"

  # La etiqueta que el lector quiso decir. Entre gemelas (código reutilizado tras dar la vuelta
  # a la secuencia) gana la viva.
  def self.buscar(texto)
    candidatas = where(codigo: Barcode.variantes(texto)).to_a
    candidatas.find(&:viva?) || candidatas.first
  end

  # { producto => cantidad } de todo lo que contiene, bajando por cajas y tarimas.
  def contenido
    if hijas.loaded? ? hijas.any? : hijas.exists?
      hijas.each_with_object(Hash.new(BigDecimal("0"))) do |h, acc|
        h.contenido.each { |p, c| acc[p] += c }
      end
    elsif producto
      { producto => cantidad }
    else
      {}
    end
  end

  # Agrupa paquetes vivos y sueltos de la misma sucursal en una caja nueva.
  def self.cerrar_caja!(paquetes, usuario:)
    agrupar!("caja", paquetes, "paquete", usuario)
  end

  # Agrupa cajas vivas y sueltas en una tarima nueva.
  def self.armar_tarima!(cajas, usuario:)
    agrupar!("tarima", cajas, "caja", usuario)
  end

  def dar_de_baja!(motivo:, usuario:)
    raise ArgumentError, "hace falta el motivo" if motivo.blank?
    transaction do
      update!(estado: "baja", motivo: motivo)
      hijas.vivas.each { |h| h.dar_de_baja!(motivo: motivo, usuario: usuario) }
    end
  end

  # Hojas vivas de esta etiqueta: ella misma si es paquete o caja de proveedor; si no, todo lo de abajo.
  def hojas_vivas
    hijas_vivas = hijas.vivas.to_a
    return [ self ] if hijas_vivas.empty? && !tarima?
    hijas_vivas.flat_map(&:hojas_vivas)
  end

  # Va en una salida enviada y todavía no la recibieron: no se vende ni se vuelve a mandar.
  def en_transito?
    SalidaEtiqueta.joins(:salida).where(etiqueta_id: [ id ] + hijas_ids_profundas, estado: "pendiente", salidas: { estado: "enviada" }).exists?
  end

  def hijas_ids_profundas
    ids = hijas.pluck(:id)
    ids + Etiqueta.where(padre_id: ids).pluck(:id)
  end

  def to_s
    "#{tipo} #{codigo}"
  end

  private

  def self.agrupar!(tipo, hijas, tipo_hijas, usuario)
    hijas = Array(hijas)
    raise ArgumentError, "no hay nada que agrupar" if hijas.empty?
    raise ArgumentError, "solo se agrupan #{tipo_hijas}s vivos y sueltos" unless hijas.all? { |h| h.tipo == tipo_hijas && h.viva? && h.padre_id.nil? }
    sucursales = hijas.map(&:sucursal_id).uniq
    raise ArgumentError, "las etiquetas son de sucursales distintas" if sucursales.size > 1
    productos = hijas.map(&:producto_id).uniq
    transaction do
      grupo = create!(tipo: tipo, sucursal_id: sucursales.first, usuario: usuario, agrupando: true,
                      producto_id: (productos.size == 1 ? productos.first : nil),
                      cantidad: hijas.sum(&:cantidad))
      Etiqueta.where(id: hijas.map(&:id)).update_all(padre_id: grupo.id, updated_at: Time.current)
      grupo
    end
  end
  private_class_method :agrupar!

  def asignar_codigo
    return if codigo.present? || !TIPOS.include?(tipo)
    plu = producto&.plu || 0
    clave = "etiqueta:#{Barcode::PREFIJOS[tipo]}:#{plu}"
    INTENTOS_CODIGO.times do
      secuencia = Contador.siguiente_ciclico!(clave, 99_999)
      candidato = Barcode.identidad(tipo, plu, secuencia)
      next if Etiqueta.exists?(codigo: candidato)
      self.codigo = candidato
      return
    end
    errors.add(:codigo, "no quedan códigos libres para este producto")
  end

  # Una etiqueta nace de un renglón de pedido, de una producción, o con autorización registrada.
  # Las cajas y tarimas que solo agrupan no necesitan contexto: lo traen sus hijas.
  def contexto_obligatorio
    return if pedido_linea || produccion || justificacion.present?
    return if agrupando || tarima?
    errors.add(:base, "para etiquetar hace falta un pedido, una producción o un motivo")
  end

  def cabe_en_la_produccion
    return unless produccion
    errors.add(:base, "la producción #{produccion.folio} está cerrada") unless produccion.abierta?
    unless produccion.cabe?(cantidad.to_d)
      errors.add(:cantidad, "no puede salir más de lo que entró: quedan #{produccion.disponible.to_s('F')} de #{produccion.cantidad.to_s('F')}")
    end
  end

  def recalcular_renglon
    return unless pedido_linea && (saved_change_to_estado? || saved_change_to_id?)
    pedido_linea.recalcular!
    pedido_linea.pedido.surtiendo!
  end

  def contenido_coherente
    case tipo
    when "paquete"
      errors.add(:producto, "obligatorio en un paquete") if producto.nil?
      errors.add(:cantidad, "debe ser mayor que cero") unless cantidad.to_d.positive?
    when "tarima"
      errors.add(:producto, "una tarima no lleva producto") if producto.present?
    end
  end
end
