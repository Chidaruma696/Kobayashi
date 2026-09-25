# Una comprobación de la supervisión: una etiqueta vista (por escaneo o por pesada emparejada) o
# una pesada que no encontró pareja (etiqueta en nil).
class SupervisionEtiqueta < ApplicationRecord
  belongs_to :supervision, inverse_of: :vistas
  belongs_to :etiqueta, optional: true
  belongs_to :usuario

  validates :como, inclusion: { in: %w[escaneo pesada] }
  validates :etiqueta, presence: true, if: -> { como == "escaneo" }

  scope :con_pareja, -> { where.not(etiqueta_id: nil) }
end
