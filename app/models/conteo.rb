# Conteo físico: el supervisor escanea todo lo que hay (o teclea lo que no lleva etiqueta), el
# sistema compara contra la existencia y, al cerrar, el conteo manda: se ajusta el inventario,
# las etiquetas que no aparecieron mueren y el faltante se le carga al responsable.
class Conteo < ApplicationRecord
  belongs_to :sucursal
  belongs_to :usuario
  belongs_to :responsable, class_name: "Usuario"
  has_many :lineas, class_name: "ConteoLinea", dependent: :destroy, inverse_of: :conteo
  has_many :conteo_etiquetas, dependent: :destroy
  has_many :cargos, dependent: :restrict_with_error

  before_validation :asignar_folio, on: :create

  validates :folio, presence: true, uniqueness: true
  validates :estado, inclusion: { in: %w[abierto cerrado] }

  scope :abiertos, -> { where(estado: "abierto") }

  def abierto? = estado == "abierto"

  def self.abrir!(sucursal:, usuario:, responsable:)
    raise ArgumentError, "ya hay un conteo abierto en #{sucursal.nombre}" if abiertos.exists?(sucursal: sucursal)
    transaction do
      c = create!(sucursal: sucursal, usuario: usuario, responsable: responsable)
      Existencia.where(sucursal: sucursal).where("cantidad > 0").includes(:producto).each do |e|
        c.lineas.create!(producto: e.producto, sistema: e.cantidad)
      end
      c
    end
  end

  def linea_de(producto)
    lineas.find_or_create_by!(producto: producto) { |l| l.sistema = Existencia.de(sucursal, producto) }
  end

  # Escanear una etiqueta: se cuentan sus hojas vivas, cada una una sola vez.
  def escanear!(etiqueta)
    raise ArgumentError, "el conteo está cerrado" unless abierto?
    raise ArgumentError, "la etiqueta #{etiqueta.codigo} no está viva (#{etiqueta.estado})" unless etiqueta.viva?
    raise ArgumentError, "la etiqueta #{etiqueta.codigo} es de otra sucursal" unless etiqueta.sucursal_id == sucursal_id
    raise ArgumentError, "la etiqueta #{etiqueta.codigo} está en tránsito" if etiqueta.en_transito?
    nuevas = 0
    transaction do
      etiqueta.hojas_vivas.each do |h|
        next if conteo_etiquetas.exists?(etiqueta: h)
        conteo_etiquetas.create!(etiqueta: h)
        linea_de(h.producto).increment!(:escaneado, h.cantidad)
        nuevas += 1
      end
    end
    raise ArgumentError, "#{etiqueta.codigo} ya estaba contada" if nuevas.zero?
    nuevas
  end

  # Lo que no lleva etiqueta se teclea; sustituye el valor anterior, no lo suma.
  def contar_manual!(producto, cantidad)
    raise ArgumentError, "el conteo está cerrado" unless abierto?
    cantidad = BigDecimal(cantidad.to_s).round(3)
    raise ArgumentError, "cantidad inválida" if cantidad.negative?
    linea_de(producto).update!(manual: cantidad)
  end

  # Etiquetas vivas de la sucursal que nadie escaneó: son las que faltan, con su barcode exacto.
  def etiquetas_no_vistas
    Etiqueta.vivas.hojas.where(sucursal: sucursal).where.not(id: conteo_etiquetas.select(:etiqueta_id)).includes(:producto)
  end

  def cerrar!(usuario:)
    raise ArgumentError, "el conteo ya está cerrado" unless abierto?
    faltante = 0
    sobrante = 0
    detalle = []
    transaction do
      # Lo que tenía etiqueta y no apareció, muere aquí (y su producto queda fuera del sistema).
      etiquetas_no_vistas.each do |e|
        e.update!(estado: "baja", motivo: "no apareció en el conteo #{folio}", padre_id: nil)
      end
      lineas.includes(:producto).each do |l|
        sistema = Existencia.de(sucursal, l.producto)
        contado = l.escaneado + l.manual
        diferencia = contado - sistema
        centavos = Dinero.importe(diferencia.abs, l.producto.precio_centavos)
        l.update!(sistema: sistema, diferencia: diferencia, diferencia_centavos: diferencia.negative? ? -centavos : centavos)
        next if diferencia.zero?
        Inventario.mover!(sucursal: sucursal, producto: l.producto, tipo: diferencia.negative? ? "ajuste_salida" : "ajuste_entrada",
                          cantidad: diferencia.abs, usuario: usuario, referencia: self, motivo: "Conteo #{folio}")
        if diferencia.negative?
          faltante += centavos
          detalle << "#{l.producto.nombre}: faltan #{diferencia.abs.to_s('F')} #{l.producto.unidad} (#{Dinero.pesos(centavos)})"
        else
          sobrante += centavos
        end
      end
      update!(estado: "cerrado", cerrado_en: Time.current, faltante_centavos: faltante, sobrante_centavos: sobrante)
      cargos.create!(usuario: responsable, monto_centavos: faltante, detalle: detalle.join("\n")) if faltante.positive?
    end
    self
  end

  def to_s
    folio
  end

  private

  def asignar_folio
    self.folio ||= Folio.siguiente!(sucursal, "K") if sucursal
  end
end
