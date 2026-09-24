class SobranteEnRecepcion < ActiveRecord::Migration[8.1]
  # Un paquete que llega sin venir en la salida se recibe como sobrante, con motivo y por revisar.
  def change
    remove_check_constraint :salida_etiquetas, name: "salida_etiquetas_estado"
    add_check_constraint :salida_etiquetas, "estado IN ('pendiente', 'recibida', 'faltante', 'sobrante')", name: "salida_etiquetas_estado"
  end
end
