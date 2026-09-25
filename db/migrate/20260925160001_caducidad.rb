# La etiqueta es el lote: si el producto tiene días de vida, el paquete nace con fecha de caducidad.
class Caducidad < ActiveRecord::Migration[8.1]
  def change
    add_column :productos, :dias_vida, :integer
    add_column :etiquetas, :caduca_el, :date
    add_index :etiquetas, [ :sucursal_id, :caduca_el ]
  end
end
