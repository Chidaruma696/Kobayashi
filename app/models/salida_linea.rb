class SalidaLinea < ApplicationRecord
  belongs_to :salida
  belongs_to :producto
  belongs_to :autorizado_por, class_name: "Usuario"

  validates :cantidad, numericality: { greater_than: 0 }
  validates :motivo, presence: true
end
