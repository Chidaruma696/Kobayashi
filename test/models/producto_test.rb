require "test_helper"

class ProductoTest < ActiveSupport::TestCase
  test "asigna el PLU siguiente al mayor, nunca por debajo de 90000" do
    p = Producto.create!(clave: "NUEVO", nombre: "Nuevo", unidad: "kg", precio: 10)
    assert_equal 90003, p.plu
  end

  test "el precio se guarda en centavos enteros" do
    p = Producto.new(clave: "X", nombre: "X", unidad: "kg")
    p.precio = "129.999"
    assert_equal 13000, p.precio_centavos
    assert_equal BigDecimal("130"), p.precio
  end

  test "rechaza unidad y precio inválidos" do
    p = Producto.new(clave: "X", nombre: "X", unidad: "litro", precio_centavos: -1)
    assert_not p.valid?
    assert p.errors[:unidad].any?
    assert p.errors[:precio_centavos].any?
  end

  test "los códigos del proveedor se normalizan a dígitos y no se repiten" do
    c = productos(:pechuga).codigos_barras.create(codigo: "750 1006 559019")
    assert_not c.persisted?, "el código de la cátsup ya existe"
    c2 = productos(:pechuga).codigos_barras.create!(codigo: " 0012345678905 ")
    assert_equal "0012345678905", c2.codigo
  end
end
