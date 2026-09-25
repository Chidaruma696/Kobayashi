# Supervisión: el supervisor camina la tienda con el teléfono y va comprobando qué hay. Escanea
# etiquetas, o captura pesos y cada pesada se empareja con una etiqueta viva del mismo peso que
# nadie haya visto; si ninguna cuadra, queda como "sin pareja". Se acumula días (una abierta por
# sucursal) y NUNCA ajusta inventario ni mata etiquetas: para eso está el conteo.
class Supervision < ApplicationRecord
  self.table_name = "supervisiones"

  belongs_to :sucursal
  belongs_to :usuario
  has_many :vistas, class_name: "SupervisionEtiqueta", dependent: :destroy, inverse_of: :supervision

  before_validation :asignar_folio, on: :create
  validates :folio, presence: true, uniqueness: { scope: :sucursal_id }
  validates :estado, inclusion: { in: %w[abierta cerrada] }

  scope :abiertas, -> { where(estado: "abierta") }

  def abierta? = estado == "abierta"

  def self.abrir!(sucursal:, usuario:)
    abiertas.find_by(sucursal: sucursal) || create!(sucursal: sucursal, usuario: usuario)
  end

  # Escanear: se marcan como vistas las hojas vivas de lo escaneado (una sola vez cada una).
  def escanear!(etiqueta, usuario:)
    raise ArgumentError, I18n.t("errores.supervision.cerrada") unless abierta?
    raise ArgumentError, I18n.t("errores.caja.etiqueta_no_viva", codigo: etiqueta.codigo, estado: I18n.t("estados.#{etiqueta.estado}")) unless etiqueta.viva?
    raise ArgumentError, I18n.t("errores.caja.etiqueta_otra_sucursal", codigo: etiqueta.codigo) unless etiqueta.sucursal_id == sucursal_id
    nuevas = 0
    transaction do
      etiqueta.hojas_vivas.each do |h|
        next if vistas.exists?(etiqueta: h)
        vistas.create!(etiqueta: h, usuario: usuario, como: "escaneo")
        nuevas += 1
      end
    end
    raise ArgumentError, I18n.t("errores.supervision.ya_vista", codigo: etiqueta.codigo) if nuevas.zero?
    nuevas
  end

  # Pesar: una pesada busca su pareja entre las etiquetas vivas por kilo de la tienda con ese peso
  # exacto (a tres decimales) que nadie haya visto. Devuelve la etiqueta, o nil si no hubo pareja
  # (queda registrada la pesada suelta).
  def pesar!(cantidad, usuario:, producto: nil)
    raise ArgumentError, I18n.t("errores.supervision.cerrada") unless abierta?
    cantidad = BigDecimal(cantidad.to_s).round(3)
    raise ArgumentError, I18n.t("errores.mayor_que_cero") unless cantidad.positive?
    candidatas = Etiqueta.vivas.hojas.where(sucursal: sucursal, cantidad: cantidad).where.not(id: vistas.select(:etiqueta_id)).joins(:producto).where(productos: { unidad: "kg" })
    candidatas = candidatas.where(producto: producto) if producto
    pareja = candidatas.order(:created_at).first
    vistas.create!(etiqueta: pareja, usuario: usuario, como: "pesada", cantidad: cantidad)
    pareja
  end

  def no_vistas
    Etiqueta.vivas.hojas.where(sucursal: sucursal).where.not(id: vistas.where.not(etiqueta_id: nil).select(:etiqueta_id)).includes(:producto)
  end

  def sin_pareja = vistas.where(etiqueta_id: nil).order(created_at: :desc)

  def cerrar!
    raise ArgumentError, I18n.t("errores.supervision.cerrada") unless abierta?
    update!(estado: "cerrada", cerrado_en: Time.current)
  end

  def to_s = folio

  private

  def asignar_folio
    self.folio ||= Folio.siguiente!(sucursal, "supervision") if sucursal
  end
end
