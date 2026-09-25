require "test_helper"

class ProduccionTest < ActiveSupport::TestCase
  setup do
    @matriz = sucursales(:matriz)
    @admin = usuarios(:admin)
    @pollo = Producto.create!(clave: "POLLO", nombre: "Pollo entero", unidad: "kg", precio: 60)
    @ala = Producto.create!(clave: "ALA", nombre: "Ala", unidad: "kg", precio: 70)
    Inventario.mover!(sucursal: @matriz, producto: @pollo, tipo: "entrada", cantidad: 50, usuario: @admin, motivo: "compra")
  end

  def abrir
    Produccion.abrir!(sucursal: @matriz, producto: @pollo, cantidad: 50, usuario: @admin)
  end

  def salida(produccion, producto, cantidad)
    Etiqueta.create!(tipo: "paquete", producto: producto, cantidad: cantidad, sucursal: @matriz, usuario: @admin, produccion: produccion)
  end

  test "merma esperada: porcentaje, exceso y alerta; el costo entra de la última factura y se reparte por valor de venta" do
    p = abrir
    assert_nil p.costo_centavos, "sin factura no hay costo"
    assert_empty p.reparto
    prov = Proveedor.create!(nombre: "Granja", dias_credito: 0)
    Compras.facturar!(proveedor: prov, sucursal: @matriz, usuario: @admin, folio: "F-9", fecha: Date.current, lineas: [ { producto_id: @pollo.id, cantidad: "100", precio: "40" } ])
    assert_equal 40_00, @pollo.ultimo_costo_centavos
    @pollo.update!(merma_esperada: 10)
    p2 = Produccion.abrir!(sucursal: @matriz, producto: @pollo, cantidad: 0, usuario: @admin) rescue nil
    assert_nil p2
    p.cerrar!(usuario: @admin) # todo merma
    assert_equal 100.0, p.merma_pct
    assert p.merma_excedida?
    assert_equal BigDecimal("45"), p.exceso_merma, "50 de merma menos el 10 % esperado de 50"

    Inventario.mover!(sucursal: @matriz, producto: @pollo, tipo: "entrada", cantidad: 50, usuario: @admin)
    q = abrir
    assert_equal 200_000, q.costo_centavos, "50 kg × 40.00"
    salida(q, productos(:pechuga), 30) # 30 × 129 = 3870
    salida(q, @ala, 10)                # 10 × 70 = 700
    q.cerrar!(usuario: @admin)
    assert_equal 20.0, q.merma_pct
    assert q.merma_excedida?
    assert_equal BigDecimal("5"), q.exceso_merma
    reparto = q.reparto.index_by { |f| f[:producto] }
    assert_equal 169_365, reparto[productos(:pechuga)][:costo_centavos], "2000 × 3870 / 4570"
    assert_equal 30_635, reparto[@ala][:costo_centavos]
    assert_equal 200_000, reparto.values.sum { |f| f[:costo_centavos] }, "la merma no se lleva nada"
    assert_equal 5_646, reparto[productos(:pechuga)][:costo_unitario]
    assert_equal 3_064, reparto[@ala][:costo_unitario]
    assert_equal 457_000, q.valor_salidas_centavos
    assert_equal 56.2, q.margen_pct, "(4570 − 2000) / 4570"
    assert_nil p.margen_pct, "sin salidas no hay margen"
  end

  test "abrir consume la entrada; cerrar da de alta las salidas y guarda la merma" do
    p = abrir
    assert_equal BigDecimal("0"), Existencia.de(@matriz, @pollo)
    assert_match(/\APR-\d{5}\z/, p.folio)
    salida(p, productos(:pechuga), 30)
    salida(p, @ala, 10)
    assert_equal BigDecimal("10"), p.disponible
    p.cerrar!(usuario: @admin)
    assert_equal "cerrada", p.estado
    assert_equal BigDecimal("10"), p.merma
    assert_equal BigDecimal("30"), Existencia.de(@matriz, productos(:pechuga))
    assert_equal BigDecimal("10"), Existencia.de(@matriz, @ala)
    assert_raises(ArgumentError) { p.cerrar!(usuario: @admin) }
  end

  test "no puede salir más de lo que entró, ni de una producción cerrada" do
    p = abrir
    salida(p, productos(:pechuga), 45)
    e = Etiqueta.new(tipo: "paquete", producto: @ala, cantidad: "5.001", sucursal: @matriz, usuario: @admin, produccion: p)
    assert_not e.valid?
    assert_match "más de lo que entró", e.errors.full_messages.join
    salida(p, @ala, 5)
    p.cerrar!(usuario: @admin)
    assert_equal BigDecimal("0"), p.merma
    assert_not Etiqueta.new(tipo: "paquete", producto: @ala, cantidad: 1, sucursal: @matriz, usuario: @admin, produccion: p).valid?
  end

  test "sin existencia no se abre" do
    assert abrir.persisted?
    assert_raises(Inventario::SinExistencia) { abrir }
  end
end
