require "test_helper"

class EtiquetaTest < ActiveSupport::TestCase
  setup do
    @matriz = sucursales(:matriz)
    @admin = usuarios(:admin)
    @pechuga = productos(:pechuga)
  end

  def paquete(cantidad = "1.250", producto: @pechuga)
    Etiqueta.create!(tipo: "paquete", producto: producto, cantidad: cantidad, sucursal: @matriz, usuario: @admin)
  end

  test "un paquete recibe un código de identidad con el PLU y una secuencia" do
    a = paquete
    b = paquete
    assert_equal({ tipo: "paquete", plu: 90_001, secuencia: 1 }, Barcode.decodificar_identidad(a.codigo))
    assert_equal 2, Barcode.decodificar_identidad(b.codigo)[:secuencia]
    assert_equal 1, Barcode.decodificar_identidad(paquete(1, producto: productos(:catsup)).codigo)[:secuencia]
  end

  test "un paquete exige producto y cantidad; una tarima no lleva producto" do
    assert_not Etiqueta.new(tipo: "paquete", sucursal: @matriz, usuario: @admin, cantidad: 0, producto: @pechuga).valid?
    assert_not Etiqueta.new(tipo: "paquete", sucursal: @matriz, usuario: @admin, cantidad: 1).valid?
    assert_not Etiqueta.new(tipo: "tarima", sucursal: @matriz, usuario: @admin, producto: @pechuga).valid?
  end

  test "cerrar caja agrupa paquetes y suma su contenido; la tarima agrupa cajas" do
    caja = Etiqueta.cerrar_caja!([ paquete("1.250"), paquete("0.750") ], usuario: @admin)
    assert caja.caja?
    assert caja.codigo.start_with?("07")
    assert_equal @pechuga, caja.producto
    assert_equal BigDecimal("2"), caja.cantidad
    assert_equal({ @pechuga => BigDecimal("2") }, caja.contenido)
    assert_equal 2, caja.hijas.count

    otra = Etiqueta.cerrar_caja!([ paquete(1, producto: productos(:catsup)) ], usuario: @admin)
    tarima = Etiqueta.armar_tarima!([ caja, otra ], usuario: @admin)
    assert tarima.codigo.start_with?("06")
    assert_nil tarima.producto
    assert_equal({ @pechuga => BigDecimal("2"), productos(:catsup) => BigDecimal("1") }, tarima.contenido)
  end

  test "no se agrupa lo que ya tiene padre, no está vivo o es de otra sucursal" do
    a = paquete
    Etiqueta.cerrar_caja!([ a ], usuario: @admin)
    assert_raises(ArgumentError) { Etiqueta.cerrar_caja!([ a.reload ], usuario: @admin) }
    b = paquete
    b.dar_de_baja!(motivo: "se rompió", usuario: @admin)
    assert_raises(ArgumentError) { Etiqueta.cerrar_caja!([ b ], usuario: @admin) }
    ajena = Etiqueta.create!(tipo: "paquete", producto: @pechuga, cantidad: 1, sucursal: sucursales(:tienda), usuario: @admin)
    assert_raises(ArgumentError) { Etiqueta.cerrar_caja!([ paquete, ajena ], usuario: @admin) }
  end

  test "una caja de proveedor lleva producto y cantidad sin paquetes" do
    caja = Etiqueta.create!(tipo: "caja", producto: productos(:catsup), cantidad: 20, sucursal: @matriz, usuario: @admin)
    assert_equal({ productos(:catsup) => BigDecimal("20") }, caja.contenido)
  end

  test "buscar tolera lo que hace el lector y prefiere la etiqueta viva" do
    a = paquete
    assert_equal a, Etiqueta.buscar(" #{a.codigo[0, 12]} ")
    assert_equal a, Etiqueta.buscar(a.codigo)
    assert_nil Etiqueta.buscar("0000000000000")
  end

  test "dar de baja una caja da de baja sus paquetes" do
    caja = Etiqueta.cerrar_caja!([ paquete, paquete ], usuario: @admin)
    caja.dar_de_baja!(motivo: "cayó al piso", usuario: @admin)
    assert_equal [ "baja", "baja" ], caja.hijas.map(&:estado)
  end
end
