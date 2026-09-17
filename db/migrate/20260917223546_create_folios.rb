class CreateFolios < ActiveRecord::Migration[8.1]
  def change
    # Un contador por sucursal y prefijo (B = ticket, S = salida, D = devolución…).
    create_table :folios do |t|
      t.references :sucursal, null: false, foreign_key: true
      t.string :prefijo, null: false
      t.integer :ultimo, null: false, default: 0

      t.timestamps
    end
    add_index :folios, [ :sucursal_id, :prefijo ], unique: true
  end
end
