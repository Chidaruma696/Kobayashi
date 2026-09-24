class FoliosPorSucursal < ActiveRecord::Migration[8.1]
  # Los folios se numeran por sucursal (cada tienda tiene su B-00001), pero el índice los exigía
  # únicos en todo el sistema: la segunda tienda no podía ni abrir caja. Únicos por sucursal.
  TABLAS = {
    abonos: :sucursal_id, conteos: :sucursal_id, cortes: :sucursal_id, devoluciones: :sucursal_id,
    pedidos: :sucursal_origen_id, producciones: :sucursal_id, salidas: :sucursal_origen_id, ventas: :sucursal_id, viajes: :sucursal_id
  }.freeze

  def up
    TABLAS.each do |tabla, sucursal|
      remove_index tabla, name: "index_#{tabla}_on_folio"
      add_index tabla, [ sucursal, :folio ], unique: true, name: "index_#{tabla}_on_sucursal_y_folio"
    end
  end

  def down
    TABLAS.each do |tabla, sucursal|
      remove_index tabla, name: "index_#{tabla}_on_sucursal_y_folio"
      add_index tabla, :folio, unique: true
    end
  end
end
