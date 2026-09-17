require "test_helper"

class UsuarioTest < ActiveSupport::TestCase
  test "puede? depende del rol y de estar activo" do
    assert usuarios(:cajera).puede?("caja.vender")
    assert_not usuarios(:cajera).puede?("caja.bajar_precio")
    assert_not usuarios(:inactivo).puede?("caja.vender")
  end

  test "autorizador encuentra a quien tiene el permiso y el PIN" do
    assert_equal usuarios(:supervisora), Usuario.autorizador("caja.bajar_precio", "4321")
    assert_nil Usuario.autorizador("caja.bajar_precio", "0000")
    assert_nil Usuario.autorizador("caja.bajar_precio", "")
  end

  test "el nombre de usuario es en minúsculas y el PIN son dígitos" do
    u = Usuario.new(nombre: "X", usuario: "Con Espacios", password: "12345678", pin: "12ab",
                    rol: roles(:cajero), sucursal: sucursales(:tienda))
    assert_not u.valid?
    assert u.errors[:usuario].any?
    assert u.errors[:pin].any?
  end
end
