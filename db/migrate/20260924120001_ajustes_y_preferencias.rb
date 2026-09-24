class AjustesYPreferencias < ActiveRecord::Migration[8.1]
  # Preferencias por usuario (idioma, tema, densidad, letra) y ajustes del sistema (clave/valor).
  def change
    add_column :usuarios, :idioma, :string, null: false, default: "es"
    add_column :usuarios, :tema, :string, null: false, default: "sistema"
    add_column :usuarios, :densidad, :string, null: false, default: "normal"
    add_column :usuarios, :letra, :string, null: false, default: "normal"

    create_table :ajustes do |t|
      t.string :clave, null: false
      t.text :valor
      t.timestamps
    end
    add_index :ajustes, :clave, unique: true
  end
end
