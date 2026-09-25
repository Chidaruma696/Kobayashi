# Entra un producto en una cantidad y salen las etiquetas que se crean bajo la producción.
# Nunca sale más de lo que entró; la diferencia al cerrar es la merma. Eso es todo: no va contra
# un pedido ni pide motivo.
class Produccion < ApplicationRecord
  self.table_name = "producciones"

  belongs_to :sucursal
  belongs_to :producto
  belongs_to :usuario
  has_many :etiquetas, dependent: :restrict_with_error

  before_validation :asignar_folio, on: :create

  validates :folio, presence: true, uniqueness: { scope: :sucursal_id }
  validates :cantidad, numericality: { greater_than: 0 }
  validates :estado, inclusion: { in: %w[abierta cerrada] }

  scope :abiertas, -> { where(estado: "abierta") }

  def abierta? = estado == "abierta"

  # Abre la producción consumiendo la entrada de la existencia de la sucursal.
  def self.abrir!(sucursal:, producto:, cantidad:, usuario:)
    transaction do
      costo = producto.ultimo_costo_centavos
      p = create!(sucursal: sucursal, producto: producto, cantidad: cantidad, usuario: usuario,
                  costo_centavos: costo && Dinero.importe(cantidad, costo))
      Inventario.mover!(sucursal: sucursal, producto: producto, tipo: "consumo", cantidad: cantidad,
                        usuario: usuario, referencia: p, motivo: "Producción #{p.folio}")
      p
    end
  end

  # { producto => cantidad } de lo etiquetado hasta ahora.
  def salidas
    etiquetas.vivas.hojas.includes(:producto).group_by(&:producto).transform_values { |es| es.sum(&:cantidad) }
  end

  def total_salidas
    etiquetas.vivas.hojas.sum(:cantidad)
  end

  def disponible
    cantidad - total_salidas
  end

  # ¿Cabe una salida más de `extra`? Nunca sale más de lo que entró.
  def cabe?(extra)
    abierta? && total_salidas + extra <= cantidad
  end

  # Cierra: las salidas entran a la existencia y la merma queda registrada en la producción.
  def cerrar!(usuario:)
    raise ArgumentError, I18n.t("errores.produccion.ya_cerrada") unless abierta?
    transaction do
      salidas.each do |producto, cant|
        Inventario.mover!(sucursal: sucursal, producto: producto, tipo: "produccion", cantidad: cant,
                          usuario: usuario, referencia: self, motivo: "Producción #{folio}")
      end
      update!(estado: "cerrada", merma: disponible)
    end
  end

  # Merma en % de lo que entró (la de ahora si sigue abierta).
  def merma_pct
    return 0 if cantidad.zero?
    ((abierta? ? disponible : merma.to_d) / cantidad * 100).round(1)
  end

  # ¿La merma se pasó de lo que el producto dice esperar?
  def merma_excedida?
    producto.merma_esperada.present? && merma_pct > producto.merma_esperada
  end

  # Lo que se mermó de más, en unidades del producto de entrada.
  def exceso_merma
    [ (abierta? ? disponible : merma.to_d) - cantidad * producto.merma_esperada.to_d / 100, 0 ].max
  end

  # El costo de lo que entró repartido entre las salidas según lo que valen a precio de venta (como
  # el cost_share de una lista de materiales): la merma no se lleva nada, la absorben las salidas.
  # [{ producto:, cantidad:, venta_centavos:, costo_centavos:, costo_unitario: }] o [] sin costo.
  def reparto
    return [] unless costo_centavos
    filas = salidas.map { |producto, cant| { producto: producto, cantidad: cant, venta_centavos: Dinero.importe(cant, producto.precio_centavos_en(sucursal)) } }
    total_venta = filas.sum { |f| f[:venta_centavos] }
    filas.each do |f|
      f[:costo_centavos] = total_venta.zero? ? 0 : (costo_centavos.to_d * f[:venta_centavos] / total_venta).round.to_i
      f[:costo_unitario] = f[:cantidad].zero? ? 0 : (f[:costo_centavos] / f[:cantidad]).round.to_i
    end
  end

  # Lo que valen las salidas a precio de venta de la sucursal.
  def valor_salidas_centavos
    salidas.sum { |producto, cant| Dinero.importe(cant, producto.precio_centavos_en(sucursal)) }
  end

  # Margen de toda la producción: lo que valen las salidas contra lo que costó lo que entró.
  def margen_pct
    valor = valor_salidas_centavos
    return nil if costo_centavos.nil? || valor.zero?
    ((valor - costo_centavos).to_d / valor * 100).round(1)
  end

  def to_s
    folio
  end

  private

  def asignar_folio
    self.folio ||= Folio.siguiente!(sucursal, "produccion") if sucursal
  end
end
