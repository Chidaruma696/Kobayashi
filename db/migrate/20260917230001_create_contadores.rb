class CreateContadores < ActiveRecord::Migration[8.1]
  def change
    # Secuencias genéricas (etiquetas por prefijo y PLU, etc.). El incremento lo hace la base.
    create_table :contadores do |t|
      t.string :clave, null: false
      t.integer :ultimo, null: false, default: 0

      t.timestamps
    end
    add_index :contadores, :clave, unique: true
  end
end
