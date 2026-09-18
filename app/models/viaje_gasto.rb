class ViajeGasto < ApplicationRecord
  belongs_to :viaje
  belongs_to :usuario

  validates :concepto, presence: true
  validates :monto_centavos, numericality: { only_integer: true, greater_than: 0 }
end
