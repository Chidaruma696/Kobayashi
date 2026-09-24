# Un renglón de la cuenta del cliente. Solo se inserta: el saldo es la suma de los montos con signo.
class MovimientoCredito < ApplicationRecord
  self.table_name = "movimientos_credito"
  TIPOS = %w[cargo abono devolucion ajuste].freeze

  belongs_to :cliente
  belongs_to :usuario
  belongs_to :referencia, polymorphic: true, optional: true

  validates :tipo, inclusion: { in: TIPOS }
  validates :monto_centavos, numericality: { only_integer: true }
  validates :fecha, presence: true
  validate { errors.add(:monto_centavos, I18n.t("errores.credito.cargo_suma")) if tipo == "cargo" && monto_centavos.to_i <= 0 }
  validate { errors.add(:monto_centavos, I18n.t("errores.credito.abono_resta")) if %w[abono devolucion].include?(tipo) && monto_centavos.to_i >= 0 }

  before_update { raise ActiveRecord::ReadOnlyRecord, "la cuenta del cliente no se edita" }
  before_destroy { raise ActiveRecord::ReadOnlyRecord, "la cuenta del cliente no se borra" }

  scope :en_orden, -> { order(:fecha, :id) }
end
