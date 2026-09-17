require "test_helper"

class InventarioControllerTest < ActionDispatch::IntegrationTest
  test "una cajera ve existencias pero necesita el PIN de un supervisor para ajustar" do
    post entrar_path, params: { usuario: "cajera", password: "secreto1" }
    get inventario_path
    assert_response :ok
    post movimientos_inventario_path, params: { producto_id: productos(:pechuga).id, tipo: "entrada", cantidad: "3", motivo: "llegó" }
    assert_response :unprocessable_entity
    assert_equal BigDecimal("0"), Existencia.de(sucursales(:tienda), productos(:pechuga))
    post movimientos_inventario_path, params: { producto_id: productos(:pechuga).id, tipo: "entrada", cantidad: "3", motivo: "llegó", pin: "4321" }
    assert_redirected_to kardex_inventario_path(producto_id: productos(:pechuga).id, sucursal_id: sucursales(:tienda).id)
    assert_equal BigDecimal("3"), Existencia.de(sucursales(:tienda), productos(:pechuga))
    assert_match "Supervisora", Movimiento.last.motivo
    follow_redirect!
    assert_select "td", /Entrada/
  end

  test "una tienda no puede mirar otra sucursal, la matriz sí" do
    post entrar_path, params: { usuario: "cajera", password: "secreto1" }
    get inventario_path(sucursal_id: sucursales(:matriz).id)
    assert_select "h1", /Tienda 1/
    delete salir_path
    post entrar_path, params: { usuario: "admin", password: "secreto1" }
    get inventario_path(sucursal_id: sucursales(:tienda).id)
    assert_select "h1", /Tienda 1/
  end

  test "un ajuste de salida sin existencia avisa sin romper" do
    post entrar_path, params: { usuario: "admin", password: "secreto1" }
    post movimientos_inventario_path, params: { producto_id: productos(:pechuga).id, tipo: "merma", cantidad: "1", motivo: "x" }
    assert_response :unprocessable_entity
    assert_match "insuficiente", response.body
  end
end
