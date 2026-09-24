require "test_helper"

class FoliosPorSucursalTest < ActiveSupport::TestCase
  test "cada sucursal lleva su propia numeración: dos tiendas pueden tener su K-00001" do
    a = Conteo.abrir!(sucursal: sucursales(:matriz), usuario: usuarios(:admin), responsable: usuarios(:admin))
    b = Conteo.abrir!(sucursal: sucursales(:tienda), usuario: usuarios(:supervisora), responsable: usuarios(:cajera))
    assert_equal a.folio, b.folio
    assert_equal "K-00001", b.folio
    assert_raises(ActiveRecord::RecordInvalid) { Conteo.create!(sucursal: sucursales(:tienda), usuario: usuarios(:supervisora), responsable: usuarios(:cajera), folio: "K-00001") }
  end
end

class FolioTest < ActiveSupport::TestCase
  test "numera por sucursal y prefijo, empezando en 1 y con cinco dígitos" do
    assert_equal "B-00001", Folio.siguiente!(sucursales(:matriz), "B")
    assert_equal "B-00002", Folio.siguiente!(sucursales(:matriz), "B")
    assert_equal "B-00001", Folio.siguiente!(sucursales(:tienda), "B")
    assert_equal "S-00001", Folio.siguiente!(sucursales(:matriz), "S")
  end

  test "no repite folios aunque se pidan muchos seguidos" do
    folios = 50.times.map { Folio.siguiente!(sucursales(:tienda), "B") }
    assert_equal folios.uniq.size, folios.size
    assert_equal "B-00050", folios.last
  end
end
