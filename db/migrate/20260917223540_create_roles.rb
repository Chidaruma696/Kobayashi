class CreateRoles < ActiveRecord::Migration[8.1]
  def change
    create_table :roles do |t|
      t.string :nombre, null: false
      t.json :permisos, null: false, default: []

      t.timestamps
    end
    add_index :roles, :nombre, unique: true
  end
end
