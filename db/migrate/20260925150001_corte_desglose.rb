# El corte guarda cómo se contó la gaveta (cuántos de cada billete y moneda), no solo el total.
class CorteDesglose < ActiveRecord::Migration[8.1]
  def change
    add_column :cortes, :desglose, :text
  end
end
