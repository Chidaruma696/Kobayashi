class CreateUsuarios < ActiveRecord::Migration[8.1]
  def change
    create_table :usuarios do |t|
      t.string :nombre, null: false
      t.string :usuario, null: false
      t.string :password_digest, null: false
      t.string :pin_digest
      t.references :rol, null: false, foreign_key: true
      t.references :sucursal, null: false, foreign_key: true
      t.boolean :activo, null: false, default: true

      t.timestamps
    end
    add_index :usuarios, :usuario, unique: true
  end
end
