# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_09_25_100001) do
  create_table "abonos", force: :cascade do |t|
    t.integer "cliente_id", null: false
    t.integer "corte_id"
    t.datetime "created_at", null: false
    t.boolean "en_ruta", default: false, null: false
    t.string "folio", null: false
    t.string "forma", null: false
    t.integer "monto_centavos", null: false
    t.string "notas"
    t.integer "sucursal_id", null: false
    t.datetime "updated_at", null: false
    t.integer "usuario_id", null: false
    t.integer "viaje_id"
    t.index ["cliente_id"], name: "index_abonos_on_cliente_id"
    t.index ["corte_id"], name: "index_abonos_on_corte_id"
    t.index ["sucursal_id", "folio"], name: "index_abonos_on_sucursal_y_folio", unique: true
    t.index ["sucursal_id"], name: "index_abonos_on_sucursal_id"
    t.index ["usuario_id"], name: "index_abonos_on_usuario_id"
    t.index ["viaje_id"], name: "index_abonos_on_viaje_id"
    t.check_constraint "monto_centavos > 0", name: "abonos_monto"
  end

  create_table "ajustes", force: :cascade do |t|
    t.string "clave", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "valor"
    t.index ["clave"], name: "index_ajustes_on_clave", unique: true
  end

  create_table "cargos", force: :cascade do |t|
    t.integer "conteo_id"
    t.datetime "created_at", null: false
    t.text "detalle"
    t.string "estado", default: "pendiente", null: false
    t.integer "monto_centavos", null: false
    t.datetime "resuelto_en"
    t.integer "resuelto_por_id"
    t.integer "revision_id"
    t.integer "sucursal_id", null: false
    t.datetime "updated_at", null: false
    t.integer "usuario_id", null: false
    t.integer "viaje_id"
    t.index ["conteo_id"], name: "index_cargos_on_conteo_id"
    t.index ["resuelto_por_id"], name: "index_cargos_on_resuelto_por_id"
    t.index ["revision_id"], name: "index_cargos_on_revision_id"
    t.index ["sucursal_id"], name: "index_cargos_on_sucursal_id"
    t.index ["usuario_id"], name: "index_cargos_on_usuario_id"
    t.index ["viaje_id"], name: "index_cargos_on_viaje_id"
    t.check_constraint "estado IN ('pendiente', 'cobrado', 'perdonado')", name: "cargos_estado"
    t.check_constraint "monto_centavos > 0", name: "cargos_monto"
  end

  create_table "clientes", force: :cascade do |t|
    t.boolean "activo", default: true, null: false
    t.string "bloqueo_manual"
    t.string "bloqueo_motivo"
    t.integer "bloqueo_por_id"
    t.datetime "created_at", null: false
    t.string "credito", default: "contado", null: false
    t.integer "dia_corte"
    t.string "direccion"
    t.integer "limite_credito_centavos", default: 0, null: false
    t.string "nombre", null: false
    t.text "notas"
    t.integer "orden", default: 0, null: false
    t.integer "ruta_id"
    t.string "telefono"
    t.datetime "updated_at", null: false
    t.integer "zona_id"
    t.index ["bloqueo_por_id"], name: "index_clientes_on_bloqueo_por_id"
    t.index ["nombre"], name: "index_clientes_on_nombre"
    t.index ["ruta_id"], name: "index_clientes_on_ruta_id"
    t.index ["zona_id"], name: "index_clientes_on_zona_id"
    t.check_constraint "credito IN ('contado', 'nota_x_nota', 'limite', 'semanal', 'contado_abonando', 'especial')", name: "clientes_credito"
  end

  create_table "codigos_barras", force: :cascade do |t|
    t.string "codigo", null: false
    t.datetime "created_at", null: false
    t.integer "producto_id", null: false
    t.datetime "updated_at", null: false
    t.index ["codigo"], name: "index_codigos_barras_on_codigo", unique: true
    t.index ["producto_id"], name: "index_codigos_barras_on_producto_id"
  end

  create_table "contadores", force: :cascade do |t|
    t.string "clave", null: false
    t.datetime "created_at", null: false
    t.integer "ultimo", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["clave"], name: "index_contadores_on_clave", unique: true
  end

  create_table "conteo_etiquetas", force: :cascade do |t|
    t.integer "conteo_id", null: false
    t.datetime "created_at", null: false
    t.integer "etiqueta_id", null: false
    t.datetime "updated_at", null: false
    t.index ["conteo_id", "etiqueta_id"], name: "index_conteo_etiquetas_on_conteo_id_and_etiqueta_id", unique: true
    t.index ["conteo_id"], name: "index_conteo_etiquetas_on_conteo_id"
    t.index ["etiqueta_id"], name: "index_conteo_etiquetas_on_etiqueta_id"
  end

  create_table "conteo_lineas", force: :cascade do |t|
    t.integer "conteo_id", null: false
    t.datetime "created_at", null: false
    t.decimal "diferencia", precision: 12, scale: 3
    t.integer "diferencia_centavos"
    t.decimal "escaneado", precision: 12, scale: 3, default: "0.0", null: false
    t.decimal "manual", precision: 12, scale: 3, default: "0.0", null: false
    t.integer "producto_id", null: false
    t.decimal "sistema", precision: 12, scale: 3, default: "0.0", null: false
    t.datetime "updated_at", null: false
    t.index ["conteo_id", "producto_id"], name: "index_conteo_lineas_on_conteo_id_and_producto_id", unique: true
    t.index ["conteo_id"], name: "index_conteo_lineas_on_conteo_id"
    t.index ["producto_id"], name: "index_conteo_lineas_on_producto_id"
  end

  create_table "conteos", force: :cascade do |t|
    t.datetime "cerrado_en"
    t.datetime "created_at", null: false
    t.string "estado", default: "abierto", null: false
    t.integer "faltante_centavos"
    t.string "folio", null: false
    t.text "notas"
    t.integer "responsable_id", null: false
    t.integer "sobrante_centavos"
    t.integer "sucursal_id", null: false
    t.datetime "updated_at", null: false
    t.integer "usuario_id", null: false
    t.index ["responsable_id"], name: "index_conteos_on_responsable_id"
    t.index ["sucursal_id", "estado"], name: "index_conteos_on_sucursal_id_and_estado"
    t.index ["sucursal_id", "folio"], name: "index_conteos_on_sucursal_y_folio", unique: true
    t.index ["sucursal_id"], name: "index_conteos_on_sucursal_id"
    t.index ["usuario_id"], name: "index_conteos_on_usuario_id"
    t.check_constraint "estado IN ('abierto', 'cerrado')", name: "conteos_estado"
  end

  create_table "convenios", force: :cascade do |t|
    t.boolean "activo", default: true, null: false
    t.integer "cliente_id", null: false
    t.datetime "created_at", null: false
    t.string "excluir"
    t.string "lineas", null: false
    t.string "notas"
    t.integer "precio_centavos", null: false
    t.decimal "tope_cajas", precision: 8, scale: 2, default: "0.0", null: false
    t.datetime "updated_at", null: false
    t.index ["cliente_id"], name: "index_convenios_activo_por_cliente", unique: true, where: "activo"
    t.index ["cliente_id"], name: "index_convenios_on_cliente_id"
  end

  create_table "cortes", force: :cascade do |t|
    t.datetime "abierto_en", null: false
    t.datetime "cerrado_en"
    t.integer "cerrado_por_id"
    t.integer "contado_centavos"
    t.datetime "created_at", null: false
    t.integer "diferencia_centavos"
    t.integer "esperado_centavos"
    t.string "estado", default: "abierto", null: false
    t.string "folio", null: false
    t.integer "fondo_centavos", default: 0, null: false
    t.integer "sucursal_id", null: false
    t.datetime "updated_at", null: false
    t.integer "usuario_id", null: false
    t.index ["cerrado_por_id"], name: "index_cortes_on_cerrado_por_id"
    t.index ["sucursal_id", "estado"], name: "index_cortes_on_sucursal_id_and_estado"
    t.index ["sucursal_id", "folio"], name: "index_cortes_on_sucursal_y_folio", unique: true
    t.index ["sucursal_id"], name: "index_cortes_on_sucursal_id"
    t.index ["usuario_id"], name: "index_cortes_on_usuario_id"
    t.check_constraint "estado IN ('abierto', 'cerrado')", name: "cortes_estado"
    t.check_constraint "fondo_centavos >= 0", name: "cortes_fondo"
  end

  create_table "devolucion_lineas", force: :cascade do |t|
    t.decimal "cantidad", precision: 12, scale: 3, null: false
    t.datetime "created_at", null: false
    t.integer "devolucion_id", null: false
    t.integer "importe_centavos", null: false
    t.datetime "updated_at", null: false
    t.integer "venta_linea_id", null: false
    t.index ["devolucion_id"], name: "index_devolucion_lineas_on_devolucion_id"
    t.index ["venta_linea_id"], name: "index_devolucion_lineas_on_venta_linea_id"
    t.check_constraint "cantidad > 0", name: "devolucion_lineas_cantidad"
  end

  create_table "devoluciones", force: :cascade do |t|
    t.integer "corte_id"
    t.datetime "created_at", null: false
    t.string "folio", null: false
    t.string "motivo", null: false
    t.integer "sucursal_id", null: false
    t.integer "total_centavos", null: false
    t.datetime "updated_at", null: false
    t.integer "usuario_id", null: false
    t.integer "venta_id", null: false
    t.index ["corte_id"], name: "index_devoluciones_on_corte_id"
    t.index ["sucursal_id", "folio"], name: "index_devoluciones_on_sucursal_y_folio", unique: true
    t.index ["sucursal_id"], name: "index_devoluciones_on_sucursal_id"
    t.index ["usuario_id"], name: "index_devoluciones_on_usuario_id"
    t.index ["venta_id"], name: "index_devoluciones_on_venta_id"
  end

  create_table "etiquetas", force: :cascade do |t|
    t.integer "autorizado_por_id"
    t.decimal "cantidad", precision: 12, scale: 3, default: "0.0", null: false
    t.string "codigo", limit: 13, null: false
    t.datetime "created_at", null: false
    t.string "estado", default: "viva", null: false
    t.string "justificacion"
    t.string "motivo"
    t.integer "padre_id"
    t.integer "pedido_linea_id"
    t.integer "produccion_id"
    t.integer "producto_id"
    t.integer "sucursal_id", null: false
    t.string "tipo", null: false
    t.datetime "updated_at", null: false
    t.integer "usuario_id", null: false
    t.index ["autorizado_por_id"], name: "index_etiquetas_on_autorizado_por_id"
    t.index ["codigo"], name: "index_etiquetas_on_codigo", unique: true
    t.index ["padre_id"], name: "index_etiquetas_on_padre_id"
    t.index ["pedido_linea_id"], name: "index_etiquetas_on_pedido_linea_id"
    t.index ["produccion_id"], name: "index_etiquetas_on_produccion_id"
    t.index ["producto_id"], name: "index_etiquetas_on_producto_id"
    t.index ["sucursal_id", "estado", "tipo"], name: "index_etiquetas_on_sucursal_id_and_estado_and_tipo"
    t.index ["sucursal_id"], name: "index_etiquetas_on_sucursal_id"
    t.index ["usuario_id"], name: "index_etiquetas_on_usuario_id"
    t.check_constraint "cantidad >= 0", name: "etiquetas_cantidad"
    t.check_constraint "estado IN ('viva', 'vendida', 'baja')", name: "etiquetas_estado"
    t.check_constraint "tipo IN ('paquete', 'caja', 'tarima')", name: "etiquetas_tipo"
  end

  create_table "existencias", force: :cascade do |t|
    t.decimal "cantidad", precision: 12, scale: 3, default: "0.0", null: false
    t.datetime "created_at", null: false
    t.integer "producto_id", null: false
    t.integer "sucursal_id", null: false
    t.datetime "updated_at", null: false
    t.index ["producto_id"], name: "index_existencias_on_producto_id"
    t.index ["sucursal_id", "producto_id"], name: "index_existencias_on_sucursal_id_and_producto_id", unique: true
    t.index ["sucursal_id"], name: "index_existencias_on_sucursal_id"
    t.check_constraint "cantidad >= 0", name: "existencias_no_negativas"
  end

  create_table "folios", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "prefijo", null: false
    t.integer "sucursal_id", null: false
    t.integer "ultimo", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["sucursal_id", "prefijo"], name: "index_folios_on_sucursal_id_and_prefijo", unique: true
    t.index ["sucursal_id"], name: "index_folios_on_sucursal_id"
  end

  create_table "movimientos", force: :cascade do |t|
    t.decimal "cantidad", precision: 12, scale: 3, null: false
    t.datetime "created_at", null: false
    t.integer "etiqueta_id"
    t.date "fecha_negocio", null: false
    t.string "motivo"
    t.integer "producto_id", null: false
    t.integer "referencia_id"
    t.string "referencia_type"
    t.decimal "saldo", precision: 12, scale: 3, null: false
    t.integer "sucursal_id", null: false
    t.string "tipo", null: false
    t.datetime "updated_at", null: false
    t.integer "usuario_id", null: false
    t.index ["etiqueta_id"], name: "index_movimientos_on_etiqueta_id"
    t.index ["producto_id"], name: "index_movimientos_on_producto_id"
    t.index ["referencia_type", "referencia_id"], name: "index_movimientos_on_referencia"
    t.index ["sucursal_id", "fecha_negocio"], name: "index_movimientos_on_sucursal_id_and_fecha_negocio"
    t.index ["sucursal_id", "producto_id", "created_at"], name: "idx_on_sucursal_id_producto_id_created_at_be784bb004"
    t.index ["sucursal_id"], name: "index_movimientos_on_sucursal_id"
    t.index ["usuario_id"], name: "index_movimientos_on_usuario_id"
    t.check_constraint "cantidad > 0", name: "movimientos_cantidad_positiva"
    t.check_constraint "tipo IN ('entrada', 'produccion', 'recepcion', 'devolucion_cliente', 'ajuste_entrada', 'venta', 'salida', 'consumo', 'merma', 'ajuste_salida')", name: "movimientos_tipo"
  end

  create_table "movimientos_canastillas", force: :cascade do |t|
    t.integer "cantidad_chofer", default: 0, null: false
    t.integer "cantidad_cliente", default: 0, null: false
    t.integer "chofer_id"
    t.integer "cliente_id"
    t.string "concepto"
    t.datetime "created_at", null: false
    t.date "fecha", null: false
    t.integer "sucursal_id", null: false
    t.string "tipo", null: false
    t.integer "tipo_canastilla_id", null: false
    t.datetime "updated_at", null: false
    t.integer "usuario_id", null: false
    t.integer "viaje_id"
    t.index ["chofer_id"], name: "index_movimientos_canastillas_on_chofer_id"
    t.index ["cliente_id"], name: "index_movimientos_canastillas_on_cliente_id"
    t.index ["sucursal_id"], name: "index_movimientos_canastillas_on_sucursal_id"
    t.index ["tipo_canastilla_id"], name: "index_movimientos_canastillas_on_tipo_canastilla_id"
    t.index ["usuario_id"], name: "index_movimientos_canastillas_on_usuario_id"
    t.index ["viaje_id"], name: "index_movimientos_canastillas_on_viaje_id"
    t.check_constraint "tipo IN ('carga', 'entrega', 'devolucion', 'descarga', 'ajuste')", name: "movimientos_canastillas_tipo"
  end

  create_table "movimientos_credito", force: :cascade do |t|
    t.integer "cliente_id", null: false
    t.datetime "created_at", null: false
    t.date "fecha", null: false
    t.integer "monto_centavos", null: false
    t.string "motivo"
    t.integer "referencia_id"
    t.string "referencia_type"
    t.string "tipo", null: false
    t.datetime "updated_at", null: false
    t.integer "usuario_id", null: false
    t.index ["cliente_id", "fecha"], name: "index_movimientos_credito_on_cliente_id_and_fecha"
    t.index ["cliente_id"], name: "index_movimientos_credito_on_cliente_id"
    t.index ["referencia_type", "referencia_id"], name: "index_movimientos_credito_on_referencia"
    t.index ["usuario_id"], name: "index_movimientos_credito_on_usuario_id"
    t.check_constraint "tipo IN ('cargo', 'abono', 'devolucion', 'ajuste')", name: "movimientos_credito_tipo"
  end

  create_table "pagos", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "forma", null: false
    t.integer "monto_centavos", null: false
    t.datetime "updated_at", null: false
    t.integer "venta_id", null: false
    t.index ["venta_id"], name: "index_pagos_on_venta_id"
    t.check_constraint "forma IN ('efectivo', 'transferencia', 'deposito')", name: "pagos_forma"
    t.check_constraint "monto_centavos > 0", name: "pagos_monto"
  end

  create_table "pedido_lineas", force: :cascade do |t|
    t.decimal "cantidad", precision: 12, scale: 3, null: false
    t.datetime "created_at", null: false
    t.string "estado", default: "pendiente", null: false
    t.string "motivo"
    t.integer "pedido_id", null: false
    t.integer "producto_id", null: false
    t.datetime "updated_at", null: false
    t.index ["pedido_id"], name: "index_pedido_lineas_on_pedido_id"
    t.index ["producto_id"], name: "index_pedido_lineas_on_producto_id"
    t.check_constraint "cantidad > 0", name: "pedido_lineas_cantidad"
    t.check_constraint "estado IN ('pendiente', 'surtido', 'no_surtir')", name: "pedido_lineas_estado"
  end

  create_table "pedidos", force: :cascade do |t|
    t.integer "cliente_id"
    t.datetime "created_at", null: false
    t.string "estado", default: "solicitado", null: false
    t.string "folio", null: false
    t.text "notas"
    t.integer "sucursal_destino_id"
    t.integer "sucursal_origen_id", null: false
    t.datetime "updated_at", null: false
    t.integer "usuario_id", null: false
    t.index ["cliente_id"], name: "index_pedidos_on_cliente_id"
    t.index ["sucursal_destino_id"], name: "index_pedidos_on_sucursal_destino_id"
    t.index ["sucursal_origen_id", "estado"], name: "index_pedidos_on_sucursal_origen_id_and_estado"
    t.index ["sucursal_origen_id", "folio"], name: "index_pedidos_on_sucursal_y_folio", unique: true
    t.index ["sucursal_origen_id"], name: "index_pedidos_on_sucursal_origen_id"
    t.index ["usuario_id"], name: "index_pedidos_on_usuario_id"
    t.check_constraint "estado IN ('solicitado', 'surtiendo', 'cerrado', 'cancelado')", name: "pedidos_estado"
  end

  create_table "precios_sucursal", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "precio_centavos", null: false
    t.integer "producto_id", null: false
    t.integer "sucursal_id", null: false
    t.datetime "updated_at", null: false
    t.index ["producto_id", "sucursal_id"], name: "index_precios_sucursal_on_producto_id_and_sucursal_id", unique: true
    t.index ["producto_id"], name: "index_precios_sucursal_on_producto_id"
    t.index ["sucursal_id"], name: "index_precios_sucursal_on_sucursal_id"
    t.check_constraint "precio_centavos >= 0", name: "precios_sucursal_no_negativo"
  end

  create_table "producciones", force: :cascade do |t|
    t.decimal "cantidad", precision: 12, scale: 3, null: false
    t.datetime "created_at", null: false
    t.string "estado", default: "abierta", null: false
    t.string "folio", null: false
    t.decimal "merma", precision: 12, scale: 3
    t.integer "producto_id", null: false
    t.integer "sucursal_id", null: false
    t.datetime "updated_at", null: false
    t.integer "usuario_id", null: false
    t.index ["producto_id"], name: "index_producciones_on_producto_id"
    t.index ["sucursal_id", "folio"], name: "index_producciones_on_sucursal_y_folio", unique: true
    t.index ["sucursal_id"], name: "index_producciones_on_sucursal_id"
    t.index ["usuario_id"], name: "index_producciones_on_usuario_id"
    t.check_constraint "cantidad > 0", name: "producciones_cantidad"
    t.check_constraint "estado IN ('abierta', 'cerrada')", name: "producciones_estado"
  end

  create_table "productos", force: :cascade do |t|
    t.boolean "activo", default: true, null: false
    t.string "clave", null: false
    t.datetime "created_at", null: false
    t.string "linea"
    t.string "nombre", null: false
    t.decimal "peso_fijo", precision: 10, scale: 3
    t.integer "plu", null: false
    t.integer "precio_centavos", default: 0, null: false
    t.string "unidad", default: "kg", null: false
    t.datetime "updated_at", null: false
    t.index ["clave"], name: "index_productos_on_clave", unique: true
    t.index ["plu"], name: "index_productos_on_plu", unique: true
    t.check_constraint "plu BETWEEN 1 AND 99999", name: "productos_plu_rango"
    t.check_constraint "precio_centavos >= 0", name: "productos_precio_no_negativo"
    t.check_constraint "unidad IN ('kg', 'pieza', 'litro', 'metro')", name: "productos_unidad"
  end

  create_table "promociones", force: :cascade do |t|
    t.boolean "activa", default: true, null: false
    t.decimal "cantidad_minima", precision: 12, scale: 3, default: "0.0", null: false
    t.datetime "created_at", null: false
    t.date "desde"
    t.date "hasta"
    t.string "nombre", null: false
    t.decimal "porcentaje", precision: 5, scale: 2
    t.integer "precio_centavos"
    t.integer "producto_id", null: false
    t.integer "sucursal_id"
    t.string "tipo", null: false
    t.datetime "updated_at", null: false
    t.index ["producto_id", "activa"], name: "index_promociones_on_producto_id_and_activa"
    t.index ["producto_id"], name: "index_promociones_on_producto_id"
    t.index ["sucursal_id"], name: "index_promociones_on_sucursal_id"
    t.check_constraint "tipo IN ('precio', 'porcentaje', 'por_cantidad')", name: "promociones_tipo"
  end

  create_table "retiros", force: :cascade do |t|
    t.integer "autorizado_por_id"
    t.integer "corte_id", null: false
    t.datetime "created_at", null: false
    t.integer "monto_centavos", null: false
    t.string "motivo", null: false
    t.datetime "updated_at", null: false
    t.integer "usuario_id", null: false
    t.index ["autorizado_por_id"], name: "index_retiros_on_autorizado_por_id"
    t.index ["corte_id"], name: "index_retiros_on_corte_id"
    t.index ["usuario_id"], name: "index_retiros_on_usuario_id"
    t.check_constraint "monto_centavos > 0", name: "retiros_monto"
  end

  create_table "revisiones", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "estado", default: "pendiente", null: false
    t.string "motivo", null: false
    t.string "nota"
    t.integer "revisable_id", null: false
    t.string "revisable_type", null: false
    t.datetime "revisado_en"
    t.integer "revisado_por_id"
    t.integer "sucursal_id", null: false
    t.datetime "updated_at", null: false
    t.integer "usuario_id", null: false
    t.integer "valor_centavos", default: 0, null: false
    t.index ["revisable_type", "revisable_id"], name: "index_revisiones_on_revisable"
    t.index ["revisado_por_id"], name: "index_revisiones_on_revisado_por_id"
    t.index ["sucursal_id", "estado"], name: "index_revisiones_on_sucursal_id_and_estado"
    t.index ["sucursal_id"], name: "index_revisiones_on_sucursal_id"
    t.index ["usuario_id"], name: "index_revisiones_on_usuario_id"
    t.check_constraint "estado IN ('pendiente', 'aprobada', 'observada')", name: "revisiones_estado"
  end

  create_table "roles", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "nombre", null: false
    t.json "permisos", default: [], null: false
    t.datetime "updated_at", null: false
    t.index ["nombre"], name: "index_roles_on_nombre", unique: true
  end

  create_table "rutas", force: :cascade do |t|
    t.boolean "activa", default: true, null: false
    t.integer "chofer_id"
    t.datetime "created_at", null: false
    t.string "nombre", null: false
    t.datetime "updated_at", null: false
    t.index ["chofer_id"], name: "index_rutas_on_chofer_id"
    t.index ["nombre"], name: "index_rutas_on_nombre", unique: true
  end

  create_table "salida_canastillas", force: :cascade do |t|
    t.integer "cantidad", null: false
    t.datetime "created_at", null: false
    t.integer "salida_id", null: false
    t.integer "tipo_canastilla_id", null: false
    t.datetime "updated_at", null: false
    t.index ["salida_id", "tipo_canastilla_id"], name: "index_salida_canastillas_on_salida_id_and_tipo_canastilla_id", unique: true
    t.index ["salida_id"], name: "index_salida_canastillas_on_salida_id"
    t.index ["tipo_canastilla_id"], name: "index_salida_canastillas_on_tipo_canastilla_id"
  end

  create_table "salida_etiquetas", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "estado", default: "pendiente", null: false
    t.integer "etiqueta_id", null: false
    t.integer "grupo_id"
    t.string "motivo"
    t.datetime "recibido_en"
    t.integer "salida_id", null: false
    t.datetime "updated_at", null: false
    t.integer "verificado_por_id"
    t.index ["etiqueta_id"], name: "index_salida_etiquetas_on_etiqueta_id"
    t.index ["grupo_id"], name: "index_salida_etiquetas_on_grupo_id"
    t.index ["salida_id", "estado"], name: "index_salida_etiquetas_on_salida_id_and_estado"
    t.index ["salida_id"], name: "index_salida_etiquetas_on_salida_id"
    t.index ["verificado_por_id"], name: "index_salida_etiquetas_on_verificado_por_id"
    t.check_constraint "estado IN ('pendiente', 'recibida', 'faltante', 'sobrante')", name: "salida_etiquetas_estado"
  end

  create_table "salida_lineas", force: :cascade do |t|
    t.integer "autorizado_por_id"
    t.decimal "cantidad", precision: 12, scale: 3, null: false
    t.datetime "created_at", null: false
    t.string "motivo", null: false
    t.integer "producto_id", null: false
    t.boolean "rechazada", default: false, null: false
    t.boolean "recibida", default: false, null: false
    t.integer "salida_id", null: false
    t.datetime "updated_at", null: false
    t.integer "usuario_id"
    t.index ["autorizado_por_id"], name: "index_salida_lineas_on_autorizado_por_id"
    t.index ["producto_id"], name: "index_salida_lineas_on_producto_id"
    t.index ["salida_id"], name: "index_salida_lineas_on_salida_id"
    t.index ["usuario_id"], name: "index_salida_lineas_on_usuario_id"
    t.check_constraint "cantidad > 0", name: "salida_lineas_cantidad"
  end

  create_table "salidas", force: :cascade do |t|
    t.integer "cliente_id"
    t.datetime "created_at", null: false
    t.datetime "enviado_en"
    t.string "estado", default: "preparando", null: false
    t.string "folio", null: false
    t.string "motivo"
    t.integer "parada"
    t.datetime "recibido_en"
    t.integer "ruta_id"
    t.integer "sucursal_destino_id"
    t.integer "sucursal_origen_id", null: false
    t.string "tipo", default: "traspaso", null: false
    t.datetime "updated_at", null: false
    t.integer "usuario_id", null: false
    t.integer "venta_id"
    t.integer "verificado_por_id"
    t.integer "viaje_id"
    t.index ["cliente_id"], name: "index_salidas_on_cliente_id"
    t.index ["ruta_id"], name: "index_salidas_on_ruta_id"
    t.index ["sucursal_destino_id", "estado"], name: "index_salidas_on_sucursal_destino_id_and_estado"
    t.index ["sucursal_destino_id"], name: "index_salidas_on_sucursal_destino_id"
    t.index ["sucursal_origen_id", "estado"], name: "index_salidas_on_sucursal_origen_id_and_estado"
    t.index ["sucursal_origen_id", "folio"], name: "index_salidas_on_sucursal_y_folio", unique: true
    t.index ["sucursal_origen_id"], name: "index_salidas_on_sucursal_origen_id"
    t.index ["usuario_id"], name: "index_salidas_on_usuario_id"
    t.index ["venta_id"], name: "index_salidas_on_venta_id"
    t.index ["verificado_por_id"], name: "index_salidas_on_verificado_por_id"
    t.index ["viaje_id"], name: "index_salidas_on_viaje_id"
    t.check_constraint "estado IN ('preparando', 'sellada', 'enviada', 'recibida', 'entregada', 'rechazada', 'cancelada')", name: "salidas_estado"
    t.check_constraint "tipo IN ('traspaso', 'devolucion', 'reparto')", name: "salidas_tipo"
  end

  create_table "sucursales", force: :cascade do |t|
    t.boolean "activa", default: true, null: false
    t.string "codigo", null: false
    t.datetime "created_at", null: false
    t.integer "limite_efectivo_centavos", default: 300000, null: false
    t.string "nombre", null: false
    t.string "tipo", default: "tienda", null: false
    t.datetime "updated_at", null: false
    t.index ["codigo"], name: "index_sucursales_on_codigo", unique: true
    t.check_constraint "tipo IN ('matriz', 'tienda')", name: "sucursales_tipo"
  end

  create_table "tipos_canastilla", force: :cascade do |t|
    t.boolean "activo", default: true, null: false
    t.string "color"
    t.datetime "created_at", null: false
    t.string "nombre", null: false
    t.datetime "updated_at", null: false
    t.index ["nombre"], name: "index_tipos_canastilla_on_nombre", unique: true
  end

  create_table "usuarios", force: :cascade do |t|
    t.boolean "activo", default: true, null: false
    t.datetime "created_at", null: false
    t.string "densidad", default: "normal", null: false
    t.string "idioma", default: "en", null: false
    t.string "letra", default: "normal", null: false
    t.string "nombre", null: false
    t.string "password_digest", null: false
    t.integer "rol_id", null: false
    t.integer "sucursal_id", null: false
    t.string "tema", default: "claro", null: false
    t.datetime "updated_at", null: false
    t.string "usuario", null: false
    t.index ["rol_id"], name: "index_usuarios_on_rol_id"
    t.index ["sucursal_id"], name: "index_usuarios_on_sucursal_id"
    t.index ["usuario"], name: "index_usuarios_on_usuario", unique: true
  end

  create_table "venta_lineas", force: :cascade do |t|
    t.integer "autorizado_por_id"
    t.decimal "cantidad", precision: 12, scale: 3, null: false
    t.integer "catalogo_centavos", null: false
    t.decimal "convenio_cajas", precision: 8, scale: 3, default: "0.0", null: false
    t.integer "convenio_id"
    t.datetime "created_at", null: false
    t.integer "etiqueta_id"
    t.integer "importe_centavos", null: false
    t.integer "precio_centavos", null: false
    t.integer "producto_id", null: false
    t.integer "promocion_id"
    t.datetime "updated_at", null: false
    t.integer "venta_id", null: false
    t.index ["autorizado_por_id"], name: "index_venta_lineas_on_autorizado_por_id"
    t.index ["convenio_id"], name: "index_venta_lineas_on_convenio_id"
    t.index ["etiqueta_id"], name: "index_venta_lineas_on_etiqueta_id"
    t.index ["producto_id"], name: "index_venta_lineas_on_producto_id"
    t.index ["promocion_id"], name: "index_venta_lineas_on_promocion_id"
    t.index ["venta_id"], name: "index_venta_lineas_on_venta_id"
    t.check_constraint "cantidad > 0", name: "venta_lineas_cantidad"
    t.check_constraint "precio_centavos >= 0 AND importe_centavos >= 0", name: "venta_lineas_dinero"
  end

  create_table "ventas", force: :cascade do |t|
    t.integer "cambio_centavos", default: 0, null: false
    t.string "clave", null: false
    t.integer "cliente_id"
    t.string "codigo", limit: 13, null: false
    t.integer "corte_id", null: false
    t.datetime "created_at", null: false
    t.boolean "en_ruta", default: false, null: false
    t.string "estado", default: "cobrada", null: false
    t.date "fecha_negocio", null: false
    t.string "folio", null: false
    t.integer "sucursal_id", null: false
    t.integer "total_centavos", null: false
    t.datetime "updated_at", null: false
    t.integer "usuario_id", null: false
    t.index ["clave"], name: "index_ventas_on_clave", unique: true
    t.index ["cliente_id"], name: "index_ventas_on_cliente_id"
    t.index ["codigo"], name: "index_ventas_on_codigo", unique: true
    t.index ["corte_id", "estado"], name: "index_ventas_on_corte_id_and_estado"
    t.index ["corte_id"], name: "index_ventas_on_corte_id"
    t.index ["sucursal_id", "folio"], name: "index_ventas_on_sucursal_y_folio", unique: true
    t.index ["sucursal_id"], name: "index_ventas_on_sucursal_id"
    t.index ["usuario_id"], name: "index_ventas_on_usuario_id"
    t.check_constraint "estado IN ('por_cobrar', 'cobrada', 'a_credito', 'devuelta')", name: "ventas_estado"
    t.check_constraint "total_centavos >= 0", name: "ventas_total"
  end

  create_table "viaje_gastos", force: :cascade do |t|
    t.string "concepto", null: false
    t.datetime "created_at", null: false
    t.integer "monto_centavos", null: false
    t.datetime "updated_at", null: false
    t.integer "usuario_id", null: false
    t.integer "viaje_id", null: false
    t.index ["usuario_id"], name: "index_viaje_gastos_on_usuario_id"
    t.index ["viaje_id"], name: "index_viaje_gastos_on_viaje_id"
    t.check_constraint "monto_centavos > 0", name: "viaje_gastos_monto"
  end

  create_table "viajes", force: :cascade do |t|
    t.integer "chofer_id", null: false
    t.datetime "created_at", null: false
    t.integer "diferencia_centavos"
    t.integer "efectivo_entregado_centavos"
    t.integer "efectivo_esperado_centavos"
    t.string "estado", default: "armando", null: false
    t.date "fecha", null: false
    t.string "folio", null: false
    t.datetime "liquidado_en"
    t.integer "liquidado_por_id"
    t.text "notas"
    t.integer "ruta_id", null: false
    t.datetime "salido_en"
    t.integer "sucursal_id", null: false
    t.datetime "updated_at", null: false
    t.integer "usuario_id", null: false
    t.index ["chofer_id"], name: "index_viajes_on_chofer_id"
    t.index ["liquidado_por_id"], name: "index_viajes_on_liquidado_por_id"
    t.index ["ruta_id"], name: "index_viajes_on_ruta_id"
    t.index ["sucursal_id", "folio"], name: "index_viajes_on_sucursal_y_folio", unique: true
    t.index ["sucursal_id"], name: "index_viajes_on_sucursal_id"
    t.index ["usuario_id"], name: "index_viajes_on_usuario_id"
    t.check_constraint "estado IN ('armando', 'en_ruta', 'liquidado', 'cancelado')", name: "viajes_estado"
  end

  create_table "zonas", force: :cascade do |t|
    t.boolean "activa", default: true, null: false
    t.datetime "created_at", null: false
    t.string "nombre", null: false
    t.integer "orden", default: 0, null: false
    t.integer "ruta_id", null: false
    t.datetime "updated_at", null: false
    t.index ["ruta_id"], name: "index_zonas_on_ruta_id"
  end

  add_foreign_key "abonos", "clientes"
  add_foreign_key "abonos", "cortes"
  add_foreign_key "abonos", "sucursales"
  add_foreign_key "abonos", "usuarios"
  add_foreign_key "abonos", "viajes"
  add_foreign_key "cargos", "conteos"
  add_foreign_key "cargos", "revisiones"
  add_foreign_key "cargos", "sucursales"
  add_foreign_key "cargos", "usuarios"
  add_foreign_key "cargos", "usuarios", column: "resuelto_por_id"
  add_foreign_key "cargos", "viajes"
  add_foreign_key "clientes", "rutas"
  add_foreign_key "clientes", "usuarios", column: "bloqueo_por_id"
  add_foreign_key "clientes", "zonas"
  add_foreign_key "codigos_barras", "productos"
  add_foreign_key "conteo_etiquetas", "conteos"
  add_foreign_key "conteo_etiquetas", "etiquetas"
  add_foreign_key "conteo_lineas", "conteos"
  add_foreign_key "conteo_lineas", "productos"
  add_foreign_key "conteos", "sucursales"
  add_foreign_key "conteos", "usuarios"
  add_foreign_key "conteos", "usuarios", column: "responsable_id"
  add_foreign_key "convenios", "clientes"
  add_foreign_key "cortes", "sucursales"
  add_foreign_key "cortes", "usuarios"
  add_foreign_key "cortes", "usuarios", column: "cerrado_por_id"
  add_foreign_key "devolucion_lineas", "devoluciones"
  add_foreign_key "devolucion_lineas", "venta_lineas"
  add_foreign_key "devoluciones", "cortes"
  add_foreign_key "devoluciones", "sucursales"
  add_foreign_key "devoluciones", "usuarios"
  add_foreign_key "devoluciones", "ventas"
  add_foreign_key "etiquetas", "etiquetas", column: "padre_id"
  add_foreign_key "etiquetas", "pedido_lineas"
  add_foreign_key "etiquetas", "producciones"
  add_foreign_key "etiquetas", "productos"
  add_foreign_key "etiquetas", "sucursales"
  add_foreign_key "etiquetas", "usuarios"
  add_foreign_key "etiquetas", "usuarios", column: "autorizado_por_id"
  add_foreign_key "existencias", "productos"
  add_foreign_key "existencias", "sucursales"
  add_foreign_key "folios", "sucursales"
  add_foreign_key "movimientos", "etiquetas"
  add_foreign_key "movimientos", "productos"
  add_foreign_key "movimientos", "sucursales"
  add_foreign_key "movimientos", "usuarios"
  add_foreign_key "movimientos_canastillas", "clientes"
  add_foreign_key "movimientos_canastillas", "sucursales"
  add_foreign_key "movimientos_canastillas", "tipos_canastilla"
  add_foreign_key "movimientos_canastillas", "usuarios"
  add_foreign_key "movimientos_canastillas", "usuarios", column: "chofer_id"
  add_foreign_key "movimientos_canastillas", "viajes"
  add_foreign_key "movimientos_credito", "clientes"
  add_foreign_key "movimientos_credito", "usuarios"
  add_foreign_key "pagos", "ventas"
  add_foreign_key "pedido_lineas", "pedidos"
  add_foreign_key "pedido_lineas", "productos"
  add_foreign_key "pedidos", "clientes"
  add_foreign_key "pedidos", "sucursales", column: "sucursal_destino_id"
  add_foreign_key "pedidos", "sucursales", column: "sucursal_origen_id"
  add_foreign_key "pedidos", "usuarios"
  add_foreign_key "precios_sucursal", "productos"
  add_foreign_key "precios_sucursal", "sucursales"
  add_foreign_key "producciones", "productos"
  add_foreign_key "producciones", "sucursales"
  add_foreign_key "producciones", "usuarios"
  add_foreign_key "promociones", "productos"
  add_foreign_key "promociones", "sucursales"
  add_foreign_key "retiros", "cortes"
  add_foreign_key "retiros", "usuarios"
  add_foreign_key "retiros", "usuarios", column: "autorizado_por_id"
  add_foreign_key "revisiones", "sucursales"
  add_foreign_key "revisiones", "usuarios"
  add_foreign_key "revisiones", "usuarios", column: "revisado_por_id"
  add_foreign_key "rutas", "usuarios", column: "chofer_id"
  add_foreign_key "salida_canastillas", "salidas"
  add_foreign_key "salida_canastillas", "tipos_canastilla"
  add_foreign_key "salida_etiquetas", "etiquetas"
  add_foreign_key "salida_etiquetas", "etiquetas", column: "grupo_id"
  add_foreign_key "salida_etiquetas", "salidas"
  add_foreign_key "salida_etiquetas", "usuarios", column: "verificado_por_id"
  add_foreign_key "salida_lineas", "productos"
  add_foreign_key "salida_lineas", "salidas"
  add_foreign_key "salida_lineas", "usuarios"
  add_foreign_key "salida_lineas", "usuarios", column: "autorizado_por_id"
  add_foreign_key "salidas", "clientes"
  add_foreign_key "salidas", "rutas"
  add_foreign_key "salidas", "sucursales", column: "sucursal_destino_id"
  add_foreign_key "salidas", "sucursales", column: "sucursal_origen_id"
  add_foreign_key "salidas", "usuarios"
  add_foreign_key "salidas", "usuarios", column: "verificado_por_id"
  add_foreign_key "salidas", "ventas"
  add_foreign_key "salidas", "viajes"
  add_foreign_key "usuarios", "roles"
  add_foreign_key "usuarios", "sucursales"
  add_foreign_key "venta_lineas", "convenios"
  add_foreign_key "venta_lineas", "etiquetas"
  add_foreign_key "venta_lineas", "productos"
  add_foreign_key "venta_lineas", "promociones"
  add_foreign_key "venta_lineas", "usuarios", column: "autorizado_por_id"
  add_foreign_key "venta_lineas", "ventas"
  add_foreign_key "ventas", "clientes"
  add_foreign_key "ventas", "cortes"
  add_foreign_key "ventas", "sucursales"
  add_foreign_key "ventas", "usuarios"
  add_foreign_key "viaje_gastos", "usuarios"
  add_foreign_key "viaje_gastos", "viajes"
  add_foreign_key "viajes", "rutas"
  add_foreign_key "viajes", "sucursales"
  add_foreign_key "viajes", "usuarios"
  add_foreign_key "viajes", "usuarios", column: "chofer_id"
  add_foreign_key "viajes", "usuarios", column: "liquidado_por_id"
  add_foreign_key "zonas", "rutas"
end
