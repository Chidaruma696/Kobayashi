require "test_helper"

class EscaneoTest < ActiveSupport::TestCase
  test "resuelve etiquetas propias, códigos del proveedor, PLU y clave" do
    e = Etiqueta.create!(tipo: "paquete", producto: productos(:pechuga), cantidad: 1, sucursal: sucursales(:matriz), usuario: usuarios(:admin), pedido_linea: pedido_lineas(:pechuga_5))
    r = Escaneo.resolver(e.codigo)
    assert r.etiqueta?
    assert_equal e, r.etiqueta
    assert_equal productos(:pechuga), r.producto

    r = Escaneo.resolver("750100655901")
    assert r.producto?
    assert_equal productos(:catsup), r.producto

    assert_equal productos(:pechuga), Escaneo.resolver("90001").producto
    assert_equal productos(:pechuga), Escaneo.resolver("pech").producto
    assert_nil Escaneo.resolver("nada")
    assert_nil Escaneo.resolver("")
  end
end
