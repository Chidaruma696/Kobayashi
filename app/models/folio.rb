class Folio < ApplicationRecord
  belongs_to :sucursal

  validates :prefijo, presence: true, format: { with: /\A[A-Z]{1,3}\z/ }
  validates :ultimo, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  # Siguiente folio de la sucursal, atómico: el incremento lo hace la base, no Ruby.
  def self.siguiente!(sucursal, prefijo)
    transaction do
      folio = find_or_create_by!(sucursal: sucursal, prefijo: prefijo)
      where(id: folio.id).update_all("ultimo = ultimo + 1")
      formatear(prefijo, folio.reload.ultimo)
    end
  end

  def self.formatear(prefijo, numero)
    "#{prefijo}-#{numero.to_s.rjust(5, '0')}"
  end
end
