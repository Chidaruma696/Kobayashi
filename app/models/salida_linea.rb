class SalidaLinea < ApplicationRecord
  belongs_to :salida
  belongs_to :producto
  belongs_to :usuario, optional: true
  belongs_to :autorizado_por, class_name: "Usuario", optional: true

  validates :cantidad, numericality: { greater_than: 0 }
  validates :motivo, presence: true

  scope :vivas, -> { where(rechazada: false) }
end
