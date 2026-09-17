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

ActiveRecord::Schema[8.1].define(version: 2026_09_17_235003) do
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
    t.datetime "created_at", null: false
    t.string "estado", default: "solicitado", null: false
    t.string "folio", null: false
    t.text "notas"
    t.integer "sucursal_destino_id", null: false
    t.integer "sucursal_origen_id", null: false
    t.datetime "updated_at", null: false
    t.integer "usuario_id", null: false
    t.index ["folio"], name: "index_pedidos_on_folio", unique: true
    t.index ["sucursal_destino_id"], name: "index_pedidos_on_sucursal_destino_id"
    t.index ["sucursal_origen_id", "estado"], name: "index_pedidos_on_sucursal_origen_id_and_estado"
    t.index ["sucursal_origen_id"], name: "index_pedidos_on_sucursal_origen_id"
    t.index ["usuario_id"], name: "index_pedidos_on_usuario_id"
    t.check_constraint "estado IN ('solicitado', 'surtiendo', 'cerrado', 'cancelado')", name: "pedidos_estado"
  end

  create_table "producciones", force: :cascade do |t|
    t.integer "autorizado_por_id"
    t.decimal "cantidad", precision: 12, scale: 3, null: false
    t.datetime "created_at", null: false
    t.string "estado", default: "abierta", null: false
    t.string "folio", null: false
    t.string "justificacion"
    t.decimal "merma", precision: 12, scale: 3
    t.integer "pedido_id"
    t.integer "producto_id", null: false
    t.integer "sucursal_id", null: false
    t.datetime "updated_at", null: false
    t.integer "usuario_id", null: false
    t.index ["autorizado_por_id"], name: "index_producciones_on_autorizado_por_id"
    t.index ["folio"], name: "index_producciones_on_folio", unique: true
    t.index ["pedido_id"], name: "index_producciones_on_pedido_id"
    t.index ["producto_id"], name: "index_producciones_on_producto_id"
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
    t.check_constraint "unidad IN ('kg', 'pieza')", name: "productos_unidad"
  end

  create_table "roles", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "nombre", null: false
    t.json "permisos", default: [], null: false
    t.datetime "updated_at", null: false
    t.index ["nombre"], name: "index_roles_on_nombre", unique: true
  end

  create_table "sucursales", force: :cascade do |t|
    t.boolean "activa", default: true, null: false
    t.string "codigo", null: false
    t.datetime "created_at", null: false
    t.string "nombre", null: false
    t.string "tipo", default: "tienda", null: false
    t.datetime "updated_at", null: false
    t.index ["codigo"], name: "index_sucursales_on_codigo", unique: true
    t.check_constraint "tipo IN ('matriz', 'tienda')", name: "sucursales_tipo"
  end

  create_table "usuarios", force: :cascade do |t|
    t.boolean "activo", default: true, null: false
    t.datetime "created_at", null: false
    t.string "nombre", null: false
    t.string "password_digest", null: false
    t.string "pin_digest"
    t.integer "rol_id", null: false
    t.integer "sucursal_id", null: false
    t.datetime "updated_at", null: false
    t.string "usuario", null: false
    t.index ["rol_id"], name: "index_usuarios_on_rol_id"
    t.index ["sucursal_id"], name: "index_usuarios_on_sucursal_id"
    t.index ["usuario"], name: "index_usuarios_on_usuario", unique: true
  end

  add_foreign_key "codigos_barras", "productos"
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
  add_foreign_key "pedido_lineas", "pedidos"
  add_foreign_key "pedido_lineas", "productos"
  add_foreign_key "pedidos", "sucursales", column: "sucursal_destino_id"
  add_foreign_key "pedidos", "sucursales", column: "sucursal_origen_id"
  add_foreign_key "pedidos", "usuarios"
  add_foreign_key "producciones", "pedidos"
  add_foreign_key "producciones", "productos"
  add_foreign_key "producciones", "sucursales"
  add_foreign_key "producciones", "usuarios"
  add_foreign_key "producciones", "usuarios", column: "autorizado_por_id"
  add_foreign_key "usuarios", "roles"
  add_foreign_key "usuarios", "sucursales"
end
