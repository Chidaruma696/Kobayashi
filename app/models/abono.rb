# Dinero que el cliente paga a cuenta. En oficina entra a la caja abierta al momento; en ruta
# lo trae el chofer y entra a la caja cuando se liquida el viaje.
class Abono < ApplicationRecord
  belongs_to :cliente
  belongs_to :sucursal
  belongs_to :usuario
  belongs_to :viaje, optional: true
  belongs_to :corte, optional: true

  before_validation :asignar_folio, on: :create

  validates :folio, presence: true, uniqueness: true
  validates :monto_centavos, numericality: { only_integer: true, greater_than: 0 }
  validates :forma, inclusion: { in: Pago::FORMAS }

  def self.registrar!(cliente:, sucursal:, monto_centavos:, forma:, usuario:, viaje: nil, notas: nil)
    raise ArgumentError, "el abono debe ser mayor que cero" unless monto_centavos.to_i.positive?
    corte = nil
    unless viaje
      corte = Corte.abierto_en(sucursal) or raise ArgumentError, "no hay caja abierta en #{sucursal.nombre} para recibir el abono"
    end
    transaction do
      abono = create!(cliente: cliente, sucursal: sucursal, monto_centavos: monto_centavos.to_i, forma: forma, usuario: usuario,
                      viaje: viaje, corte: corte, en_ruta: viaje.present?, notas: notas)
      cliente.movimientos_credito.create!(tipo: "abono", monto_centavos: -abono.monto_centavos, fecha: Date.current, referencia: abono,
                                          usuario: usuario, motivo: "Abono #{abono.folio}#{" en ruta #{viaje.folio}" if viaje}")
      abono
    end
  end

  def to_s
    folio
  end

  private

  def asignar_folio
    self.folio ||= Folio.siguiente!(sucursal, "A") if sucursal
  end
end
