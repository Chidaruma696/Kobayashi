# Un movimiento de canastillas. Dos saldos en paralelo, cada uno con su signo:
#   cantidad_cliente  lo que el cliente debe (+ se lleva, − devuelve)
#   cantidad_chofer   lo que trae el camión (+ carga o recibe, − entrega o descarga)
#   carga      bodega → camión                        chofer +
#   entrega    camión → cliente en la parada          cliente +, chofer −
#   devolucion cliente → camión (o bodega, sin chofer) cliente −, chofer +
#   descarga   camión → bodega al liquidar            chofer −
#   ajuste     lo que diga cobranza, con motivo
class MovimientoCanastilla < ApplicationRecord
  self.table_name = "movimientos_canastillas"
  TIPOS = %w[carga entrega devolucion descarga ajuste].freeze

  belongs_to :cliente, optional: true
  belongs_to :chofer, class_name: "Usuario", optional: true
  belongs_to :viaje, optional: true
  belongs_to :sucursal
  belongs_to :tipo_canastilla
  belongs_to :usuario

  validates :tipo, inclusion: { in: TIPOS }
  validates :fecha, presence: true
  validate { errors.add(:base, I18n.t("errores.canastillas.mueve_algo")) if cantidad_cliente.zero? && cantidad_chofer.zero? }

  before_update { raise ActiveRecord::ReadOnlyRecord, "las canastillas no se editan, se ajustan" }
  before_destroy { raise ActiveRecord::ReadOnlyRecord, "las canastillas no se borran, se ajustan" }
end
