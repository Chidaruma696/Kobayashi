require "test_helper"

class SupervisionTest < ActiveSupport::TestCase
  setup do
    @tienda = sucursales(:tienda)
    @super = usuarios(:supervisora)
    Inventario.mover!(sucursal: @tienda, producto: productos(:pechuga), tipo: "entrada", cantidad: 5, usuario: @super)
    @a = Etiqueta.create!(tipo: "paquete", producto: productos(:pechuga), cantidad: "2.000", sucursal: @tienda, usuario: @super, justificacion: "prueba")
    @b = Etiqueta.create!(tipo: "paquete", producto: productos(:pechuga), cantidad: "3.000", sucursal: @tienda, usuario: @super, justificacion: "prueba")
    @s = Supervision.abrir!(sucursal: @tienda, usuario: @super)
  end

  test "escanea, empareja pesadas y nunca toca el inventario" do
    assert_equal @s, Supervision.abrir!(sucursal: @tienda, usuario: @super), "una abierta por sucursal"
    assert_equal 1, @s.escanear!(@a, usuario: @super)
    assert_raises(ArgumentError) { @s.escanear!(@a, usuario: @super) }
    assert_equal @b, @s.pesar!("3.000", usuario: @super), "la pesada encuentra la etiqueta viva de ese peso"
    assert_nil @s.pesar!("3.000", usuario: @super), "ya vista: no hay otra pareja"
    assert_nil @s.pesar!("1.234", usuario: @super)
    assert_equal 2, @s.sin_pareja.count
    assert_equal 2, @s.vistas.con_pareja.count
    assert_empty @s.no_vistas
    existencia = Existencia.de(@tienda, productos(:pechuga))
    @s.cerrar!
    assert_equal "cerrada", @s.estado
    assert_equal existencia, Existencia.de(@tienda, productos(:pechuga)), "nunca ajusta"
    assert @a.reload.viva? && @b.reload.viva?, "nunca mata etiquetas"
    assert_raises(ArgumentError) { @s.escanear!(@a, usuario: @super) }
  end
end
