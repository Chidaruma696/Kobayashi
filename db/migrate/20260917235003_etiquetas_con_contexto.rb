class EtiquetasConContexto < ActiveRecord::Migration[8.1]
  def change
    # Toda etiqueta nace de un renglón de pedido, de una producción, o con autorización registrada.
    add_reference :etiquetas, :pedido_linea, foreign_key: true
    add_reference :etiquetas, :produccion, foreign_key: { to_table: :producciones }
    add_reference :etiquetas, :autorizado_por, foreign_key: { to_table: :usuarios }
    add_column :etiquetas, :justificacion, :string

    # El consumo de una producción es una salida más del kardex.
    remove_check_constraint :movimientos, name: "movimientos_tipo"
    add_check_constraint :movimientos,
      "tipo IN ('entrada', 'produccion', 'recepcion', 'devolucion_cliente', 'ajuste_entrada', 'venta', 'salida', 'consumo', 'merma', 'ajuste_salida')",
      name: "movimientos_tipo"
  end
end
