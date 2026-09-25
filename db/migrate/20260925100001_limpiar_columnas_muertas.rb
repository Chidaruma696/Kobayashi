# Columnas que quedaron sin uso: el PIN se descartó y la producción ya no se liga a pedidos ni pide
# autorización (issue #16).
class LimpiarColumnasMuertas < ActiveRecord::Migration[8.1]
  def change
    remove_column :usuarios, :pin_digest, :string
    remove_reference :producciones, :pedido, foreign_key: true, index: true
    remove_reference :producciones, :autorizado_por, foreign_key: { to_table: :usuarios }, index: true
    remove_column :producciones, :justificacion, :string
  end
end
