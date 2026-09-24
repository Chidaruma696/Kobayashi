class Cliente < ApplicationRecord
  belongs_to :ruta, optional: true
  belongs_to :zona, optional: true
  has_one :convenio, -> { where(activo: true) }, dependent: :restrict_with_error
  has_many :movimientos_canastillas, class_name: "MovimientoCanastilla", dependent: :restrict_with_error
  has_many :pedidos, dependent: :restrict_with_error
  has_many :salidas, dependent: :restrict_with_error
  has_many :ventas, dependent: :restrict_with_error
  has_many :movimientos_credito, class_name: "MovimientoCredito", dependent: :restrict_with_error
  has_many :abonos, dependent: :restrict_with_error
  belongs_to :bloqueo_por, class_name: "Usuario", optional: true

  validates :nombre, presence: true
  validates :credito, inclusion: { in: Credito::TIPOS.keys }
  validates :limite_credito_centavos, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :dia_corte, inclusion: { in: 0..6 }, allow_nil: true
  validate { errors.add(:zona, "no es de la ruta #{ruta}") if zona && zona.ruta_id != ruta_id }

  # [orden de la zona, orden del cliente]: el orden de reparto.
  def orden_reparto
    [ zona&.orden || 0, orden, id.to_i ]
  end

  def saldo_canastillas
    Canastillas.saldo_cliente(self)
  end

  def saldo_centavos
    movimientos_credito.sum(:monto_centavos)
  end

  def estado_credito
    Credito.evaluar(self)
  end

  def bloquear!(motivo:, usuario:)
    raise ArgumentError, I18n.t("errores.escribe_motivo") if motivo.blank?
    update!(bloqueo_manual: "bloqueado", bloqueo_motivo: motivo, bloqueo_por: usuario)
  end

  def desbloquear!(motivo:, usuario:)
    raise ArgumentError, I18n.t("errores.escribe_motivo") if motivo.blank?
    update!(bloqueo_manual: "desbloqueado", bloqueo_motivo: motivo, bloqueo_por: usuario)
  end

  def quitar_bloqueo_manual!
    update!(bloqueo_manual: nil, bloqueo_motivo: nil, bloqueo_por: nil)
  end

  def limite_credito
    limite_credito_centavos / 100.0
  end

  def limite_credito=(pesos)
    self.limite_credito_centavos = Dinero.centavos(pesos)
  end

  scope :activos, -> { where(activo: true) }

  def to_s
    nombre
  end
end
