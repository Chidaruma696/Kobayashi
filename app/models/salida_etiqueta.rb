class SalidaEtiqueta < ApplicationRecord
  belongs_to :salida
  belongs_to :etiqueta
  belongs_to :grupo, class_name: "Etiqueta", optional: true
  belongs_to :verificado_por, class_name: "Usuario", optional: true

  # sobrante: llegó sin venir en la salida; entró a la tienda con motivo y quedó por revisar.
  validates :estado, inclusion: { in: %w[pendiente recibida faltante sobrante] }

  def verificada? = verificado_por_id.present?
end
