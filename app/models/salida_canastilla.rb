class SalidaCanastilla < ApplicationRecord
  belongs_to :salida
  belongs_to :tipo_canastilla

  validates :cantidad, numericality: { only_integer: true, greater_than: 0 }
end
