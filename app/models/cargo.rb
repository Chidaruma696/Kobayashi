class Cargo < ApplicationRecord
  belongs_to :usuario
  belongs_to :conteo
  belongs_to :resuelto_por, class_name: "Usuario", optional: true

  validates :monto_centavos, numericality: { only_integer: true, greater_than: 0 }
  validates :estado, inclusion: { in: %w[pendiente cobrado perdonado] }

  scope :pendientes, -> { where(estado: "pendiente") }

  def resolver!(estado, usuario:)
    raise ArgumentError, "el cargo ya está #{self.estado}" unless self.estado == "pendiente"
    update!(estado: estado, resuelto_por: usuario, resuelto_en: Time.current)
  end
end
