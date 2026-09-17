class SalidaEtiqueta < ApplicationRecord
  belongs_to :salida
  belongs_to :etiqueta
  belongs_to :grupo, class_name: "Etiqueta", optional: true
  belongs_to :verificado_por, class_name: "Usuario", optional: true

  validates :estado, inclusion: { in: %w[pendiente recibida faltante] }

  def verificada? = verificado_por_id.present?
end
