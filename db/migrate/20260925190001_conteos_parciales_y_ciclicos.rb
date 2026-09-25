# Un conteo puede ser de todo o de solo algunos productos (alcance), y cada sucursal puede decir
# cada cuántos días toca contar, para que el tablero avise.
class ConteosParcialesYCiclicos < ActiveRecord::Migration[8.1]
  def change
    add_column :conteos, :alcance, :string, null: false, default: "total"
    add_column :sucursales, :dias_conteo, :integer
  end
end
