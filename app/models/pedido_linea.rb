class PedidoLinea < ApplicationRecord
  ESTADOS = %w[pendiente surtido no_surtir].freeze

  belongs_to :pedido, inverse_of: :lineas
  belongs_to :producto
  has_many :etiquetas, dependent: :restrict_with_error

  validates :cantidad, numericality: { greater_than: 0 }
  validates :estado, inclusion: { in: ESTADOS }

  def pendiente? = estado == "pendiente"

  # Lo surtido no se guarda: se suma de las etiquetas hoja vivas ligadas al renglón.
  def cantidad_surtida
    etiquetas.vivas.hojas.sum(:cantidad)
  end

  def faltante
    [ cantidad - cantidad_surtida, 0 ].max
  end

  # Tras ligar o dar de baja una etiqueta: surtido si ya se alcanzó lo pedido, si no pendiente.
  def recalcular!
    return if estado == "no_surtir"
    update!(estado: cantidad_surtida >= cantidad ? "surtido" : "pendiente")
  end

  def marcar_surtido!
    update!(estado: "surtido")
  end

  def no_surtir!(motivo)
    raise ArgumentError, "hace falta el motivo" if motivo.blank?
    update!(estado: "no_surtir", motivo: motivo)
  end

  def reabrir!
    update!(estado: "pendiente", motivo: nil)
    recalcular!
  end
end
