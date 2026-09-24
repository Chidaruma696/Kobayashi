require "test_helper"

class CatalogoDesdeEtiquetadoraTest < ActionDispatch::IntegrationTest
  setup { post entrar_path, params: { usuario: "admin", password: "secreto1" } }

  test "la etiquetadora vincula códigos de fábrica y peso fijo por JSON" do
    catsup = productos(:catsup)
    post admin_producto_codigos_path(catsup), params: { codigo: "750 1000 12345 7" }, as: :json
    assert_response :ok
    assert_equal "7501000123457", response.parsed_body["codigo"]
    post admin_producto_codigos_path(catsup), params: { codigo: "7501000123457" }, as: :json
    assert_response :unprocessable_entity
    patch admin_producto_path(catsup), params: { producto: { peso_fijo: "0.2" } }, as: :json
    assert_response :ok
    assert_equal BigDecimal("0.2"), catsup.reload.peso_fijo
    get productos_etiquetas_path(q: "cats"), headers: { "Accept" => "application/json" }
    assert_includes response.parsed_body.first["codigos_detalle"].map { |c| c["codigo"] }, "7501000123457"
    assert_difference("catsup.codigos_barras.count", -1) do
      delete admin_producto_codigo_path(catsup, catsup.codigos_barras.find_by(codigo: "7501000123457")), as: :json
      assert_response :no_content
    end
  end
end

class AdminTest < ActionDispatch::IntegrationTest
  setup { post entrar_path, params: { usuario: "admin", password: "secreto1" } }

  test "productos: crear, editar, códigos" do
    get admin_productos_path
    assert_select "td", /Pechuga/
    post admin_productos_path, params: { producto: { clave: "ala", nombre: "Ala de pollo", linea: "Pollo", unidad: "kg", precio: "75.50", activo: "1" } }
    p = Producto.find_by!(clave: "ALA")
    assert_redirected_to edit_admin_producto_path(p)
    assert_equal 7_550, p.precio_centavos
    assert_operator p.plu, :>=, 90_000
    post admin_producto_codigos_path(p), params: { codigo: "750 1234 567890" }
    assert_equal "7501234567890", p.codigos_barras.first.codigo
    delete admin_producto_codigo_path(p, p.codigos_barras.first)
    assert_equal 0, p.codigos_barras.count
    patch admin_producto_path(p), params: { producto: { clave: "ALA", nombre: "Ala", unidad: "kg", precio: "0", activo: "0" } }
    assert_equal false, p.reload.activo
    post admin_productos_path, params: { producto: { clave: "", nombre: "", unidad: "kg" } }
    assert_response :unprocessable_entity
    patch admin_producto_path(p), params: { producto: { clave: "ALA", nombre: "Ala", unidad: "kg", precio: "75.50", activo: "1" }, precios: { sucursales(:tienda).id => "80", sucursales(:matriz).id => "" } }
    assert_equal 8_000, p.reload.precio_centavos_en(sucursales(:tienda))
    assert_equal 7_550, p.precio_centavos_en(sucursales(:matriz))
    get edit_admin_producto_path(p)
    assert_select "input[name='precios[#{sucursales(:tienda).id}]'][value='80.0']"
  end

  test "usuarios y roles: crear, cambiar rol, permisos con comodín" do
    post admin_roles_path, params: { rol: { nombre: "bodega", permisos: [ "", "etiquetas.*", "salidas.surtir" ] } }
    rol = Rol.find_by!(nombre: "bodega")
    assert rol.permite?("etiquetas.libre")
    assert_not rol.permite?("caja.vender")
    post admin_usuarios_path, params: { usuario: { nombre: "Beto", usuario: "Beto", rol_id: rol.id, sucursal_id: sucursales(:matriz).id, password: "clave1234", activo: "1" } }
    u = Usuario.find_by!(usuario: "beto")
    assert u.authenticate("clave1234")
    patch admin_usuario_path(u), params: { usuario: { nombre: "Beto", usuario: "beto", rol_id: roles(:cajero).id, sucursal_id: sucursales(:tienda).id, password: "", activo: "1" } }
    assert u.reload.authenticate("clave1234"), "la contraseña no cambia si se deja vacía"
    assert_equal roles(:cajero), u.rol
    patch admin_rol_path(rol), params: { rol: { nombre: "bodega", permisos: [ "*" ] } }
    assert rol.reload.permite?("admin.usuarios")
    get admin_roles_path
    assert_select "td", /bodega/
  end

  test "promociones: crear, listar y borrar" do
    post admin_promociones_path, params: { promocion: { nombre: "Martes", producto_id: productos(:catsup).id, sucursal_id: "", tipo: "precio", precio: "39.90", cantidad_minima: "", activa: "1" } }
    promo = Promocion.last
    assert_redirected_to admin_promociones_path
    assert_equal 3_990, promo.precio_centavos
    assert_nil promo.sucursal_id
    get admin_promociones_path
    assert_select "td", /Martes/
    get caja_escanear_path(codigo: "CATS"), headers: { "Accept" => "application/json" }
    assert_equal "Martes", response.parsed_body["promociones"].first["nombre"]
    delete admin_promocion_path(promo)
    assert_equal 0, Promocion.count
  end

  test "clientes y rutas" do
    post admin_rutas_path, params: { ruta: { nombre: "Sur", chofer_id: usuarios(:cajera).id, activa: "1" } }
    ruta = Ruta.find_by!(nombre: "Sur")
    post admin_clientes_path, params: { cliente: { nombre: "Doña Lupe", telefono: "555", ruta_id: ruta.id, orden: 2, activo: "1" } }
    c = Cliente.find_by!(nombre: "Doña Lupe")
    assert_equal ruta, c.ruta
    get admin_clientes_path(q: "lupe")
    assert_select "td", /Lupe/
    get admin_rutas_path
    assert_select "td", /Lupe/
    post pedidos_path, params: { pedido: { destino: "cliente:#{c.id}", lineas_attributes: { "0" => { producto_id: productos(:catsup).id, cantidad: "3" } } } }
    assert_equal c, Pedido.last.cliente
    get new_salida_path(pedido_id: Pedido.last.id)
    assert_select "select[name=destino]", 0
    assert_select "strong", /Lupe/
  end

  test "sucursales con límite en pesos y sin permiso 403" do
    post admin_sucursales_path, params: { sucursal: { codigo: "t03", nombre: "Tienda 3", tipo: "tienda", limite_efectivo: "5000", activa: "1" } }
    s = Sucursal.find_by!(codigo: "T03")
    assert_equal 500_000, s.limite_efectivo_centavos
    delete salir_path
    post entrar_path, params: { usuario: "cajera", password: "secreto1" }
    get admin_productos_path
    assert_response :forbidden
  end
end
