# El contador de folios pasa de ir por letra ("B") a ir por documento ("venta"): así el negocio puede
# cambiar la letra en Ajustes sin reiniciar la numeración.
class FoliosPorDocumento < ActiveRecord::Migration[8.1]
  MAPA = { "B" => "venta", "C" => "corte", "D" => "devolucion", "A" => "abono", "P" => "pedido", "S" => "salida", "DV" => "salida_devolucion",
           "R" => "reparto", "V" => "viaje", "PR" => "produccion", "K" => "conteo", "SV" => "supervision", "RC" => "recepcion", "TG" => "traspaso" }.freeze

  def up
    MAPA.each { |letra, documento| execute "UPDATE folios SET prefijo = '#{documento}' WHERE prefijo = '#{letra}'" }
  end

  def down
    MAPA.each { |letra, documento| execute "UPDATE folios SET prefijo = '#{letra}' WHERE prefijo = '#{documento}'" }
  end
end
