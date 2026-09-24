# Autorización diferida. Cuando una operación necesita a alguien con permiso y no hay nadie
# (etiquetar sin pedido, producir sin pedido, un renglón sin etiqueta, un ajuste, un retiro),
# el operador la hace de todos modos con su motivo y queda aquí a su nombre. El supervisor
# la revisa después, al final del día: la aprueba o la observa, y si la observa puede
# cargársela al responsable. El flujo nunca se frena; lo irregular nunca se pierde.
class Revision < ApplicationRecord
  self.table_name = "revisiones"
  ESTADOS = %w[pendiente aprobada observada].freeze

  belongs_to :sucursal
  belongs_to :usuario
  belongs_to :revisable, polymorphic: true
  belongs_to :revisado_por, class_name: "Usuario", optional: true
  has_one :cargo, dependent: :nullify

  validates :motivo, presence: true
  validates :estado, inclusion: { in: ESTADOS }
  validates :valor_centavos, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  scope :pendientes, -> { where(estado: "pendiente") }
  scope :resueltas, -> { where.not(estado: "pendiente") }

  def self.abrir!(registro, usuario:, sucursal:, motivo:, valor_centavos: 0)
    create!(revisable: registro, usuario: usuario, sucursal: sucursal, motivo: motivo, valor_centavos: valor_centavos.to_i)
  end

  # Lo que vale la mercancía de la operación, a precio de catálogo de la sucursal.
  def self.valor(cantidad, producto, sucursal)
    (BigDecimal(cantidad.to_s) * producto.precio_centavos_en(sucursal)).round.to_i
  end

  def pendiente? = estado == "pendiente"

  def aprobar!(usuario:, nota: nil)
    resolver!("aprobada", usuario: usuario, nota: nota)
  end

  # Observada: queda como irregular y, si se indica monto, se le carga al responsable.
  def observar!(usuario:, nota: nil, cargo_centavos: 0)
    transaction do
      resolver!("observada", usuario: usuario, nota: nota)
      if cargo_centavos.to_i.positive?
        create_cargo!(usuario: self.usuario, sucursal: sucursal, monto_centavos: cargo_centavos.to_i,
                      detalle: [ descripcion, motivo, nota ].compact_blank.join("\n"))
      end
    end
    self
  end

  # Qué fue lo que se hizo, en una línea.
  def descripcion
    case revisable
    when Etiqueta then "Etiqueta #{revisable.codigo}: #{cantidad_de(revisable)}"
    when Produccion then "Producción #{revisable.folio}: entraron #{cantidad_de(revisable)}"
    when SalidaLinea then "Renglón sin etiqueta en #{revisable.salida.folio}: #{cantidad_de(revisable)}"
    when Movimiento then "#{revisable.nombre_tipo} de #{cantidad_de(revisable)}"
    when Retiro then "Retiro de #{Dinero.pesos(revisable.monto_centavos)} del corte #{revisable.corte.folio}"
    when VentaLinea then "Precio bajado en #{revisable.venta.folio}: #{revisable.producto.nombre} a #{Dinero.pesos(revisable.precio_centavos)} (catálogo #{Dinero.pesos(revisable.catalogo_centavos)})"
    else "#{revisable_type} #{revisable_id}"
    end
  end

  private

  def resolver!(nuevo_estado, usuario:, nota:)
    raise ArgumentError, "la revisión ya está #{estado}" unless pendiente?
    update!(estado: nuevo_estado, revisado_por: usuario, revisado_en: Time.current, nota: nota)
  end

  def cantidad_de(registro)
    producto = registro.producto
    "#{ActiveSupport::NumberHelper.number_to_rounded(registro.cantidad, precision: producto.decimales)} #{producto.unidad} #{producto.nombre}"
  end
end
