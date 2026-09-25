require "test_helper"

# Pantallas de Compras: cinta, alta de proveedor, recepción escaneando el código del proveedor,
# factura ligada, cuentas por pagar con pago desde la gaveta, envases, y el módulo apagado.
class ComprasControllerTest < ActionDispatch::IntegrationTest
  setup do
    post entrar_path, params: { usuario: "admin", password: "secreto1" }
    @matriz = sucursales(:matriz)
  end

  test "el flujo completo: proveedor, recepción por código, factura ligada, pago y envases" do
    get root_path
    assert_select "aside[data-lateral-target=panel] div", /Compras/

    post proveedores_path, params: { proveedor: { nombre: "Cátsup y más", dias_credito: 30, telefono: "555" } }
    prov = Proveedor.find_by!(nombre: "Cátsup y más")
    assert_redirected_to proveedores_path

    get buscar_productos_path(q: "750100655901"), headers: { "Accept" => "application/json" }
    lista = JSON.parse(response.body)
    assert_equal [ productos(:catsup).id ], lista.map { |p| p["id"] }, "el código del proveedor resuelve el producto"

    post recepciones_path, params: { recepcion: { proveedor_id: prov.id, remision: "R-1", fecha: Date.current, canastillas: 2, clave: "k1",
                                                  lineas_attributes: { "0" => { producto_id: productos(:catsup).id, cantidad: "12", cajas: "1" } } } }
    r = Recepcion.last
    assert_redirected_to recepcion_path(r)
    assert_equal 12, Existencia.de(@matriz, productos(:catsup))
    get recepcion_path(r)
    assert_select "h1", /RC-/
    assert_select "td", /Cátsup/

    post facturas_path, params: { factura: { proveedor_id: prov.id, folio: "B-9", fecha: Date.current, recepcion_ids: [ r.id ],
                                             lineas_attributes: { "0" => { producto_id: productos(:catsup).id, cantidad: "12", precio: "25" } } } }
    f = FacturaProveedor.last
    assert_redirected_to factura_path(f)
    assert_equal 300_00, f.monto_centavos
    assert_equal f, r.reload.factura
    get factura_path(f)
    assert_select "td", /✓/

    get cuentas_path
    assert_select "td", /Cátsup y más/
    get cuenta_path(prov)
    assert_select "p", /No hay caja abierta/
    Corte.abrir!(sucursal: @matriz, usuario: usuarios(:admin), fondo_centavos: 500_00)
    post pagar_cuenta_path(prov), params: { monto: "300", forma: "efectivo", factura_proveedor_id: f.id }
    assert_redirected_to cuenta_path(prov)
    assert_equal 0, prov.saldo_centavos
    assert_equal 200_00, Corte.abierto_en(@matriz).efectivo_esperado_centavos

    get envases_path
    assert_select "td", /2 canastilla/
    post envases_path, params: { proveedor_id: prov.id, envase: "canastilla", tipo: "devolucion", cantidad: 2 }
    assert_redirected_to envases_path
    assert_equal({}, prov.saldo_envases)
  end

  test "con el módulo apagado sus pantallas lo dicen y desaparece de la cinta" do
    Modulo.guardar!(Modulo::OPCIONALES - [ "compras" ], comprobar: false)
    get root_path
    assert_select "aside[data-lateral-target=panel] div", { text: /Compras/, count: 0 }
    get proveedores_path
    assert_response :not_found
  ensure
    Modulo.guardar!(Modulo::OPCIONALES, comprobar: false)
  end

  test "la cajera no entra a compras" do
    post entrar_path, params: { usuario: "cajera", password: "secreto1" }
    get cuentas_path
    assert_response :forbidden
  end
end
