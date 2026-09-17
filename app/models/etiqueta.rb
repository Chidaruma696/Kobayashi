class Etiqueta < ApplicationRecord
  TIPOS = %w[paquete caja tarima].freeze
  ESTADOS = %w[viva vendida baja].freeze
  INTENTOS_CODIGO = 10

  belongs_to :producto, optional: true
  belongs_to :sucursal
  belongs_to :usuario
  belongs_to :padre, class_name: "Etiqueta", optional: true
  has_many :hijas, class_name: "Etiqueta", foreign_key: :padre_id, dependent: :restrict_with_error, inverse_of: :padre
  has_many :movimientos, dependent: :restrict_with_error

  before_validation :asignar_codigo, on: :create

  validates :tipo, inclusion: { in: TIPOS }
  validates :estado, inclusion: { in: ESTADOS }
  validates :codigo, presence: true, uniqueness: true, length: { is: 13 }
  validates :cantidad, numericality: { greater_than_or_equal_to: 0 }
  validate :contenido_coherente

  scope :vivas, -> { where(estado: "viva") }
  scope :sueltas, -> { where(padre_id: nil) }
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
      grupo = create!(tipo: tipo, sucursal_id: sucursales.first, usuario: usuario,
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
