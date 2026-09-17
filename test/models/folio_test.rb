require "test_helper"

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
