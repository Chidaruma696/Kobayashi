require "test_helper"

class ProduccionTest < ActiveSupport::TestCase
  setup do
    @matriz = sucursales(:matriz)
    @admin = usuarios(:admin)
    @pollo = Producto.create!(clave: "POLLO", nombre: "Pollo entero", unidad: "kg", precio: 60)
    @ala = Producto.create!(clave: "ALA", nombre: "Ala", unidad: "kg", precio: 70)
    Inventario.mover!(sucursal: @matriz, producto: @pollo, tipo: "entrada", cantidad: 50, usuario: @admin, motivo: "compra")
  end

  def abrir(pedido: pedidos(:abierto), **extra)
    Produccion.abrir!(sucursal: @matriz, producto: @pollo, cantidad: 50, usuario: @admin, pedido: pedido, **extra)
  end

  def salida(produccion, producto, cantidad)
    Etiqueta.create!(tipo: "paquete", producto: producto, cantidad: cantidad, sucursal: @matriz, usuario: @admin,
                     produccion: produccion, pedido_linea: produccion.pedido&.linea_de(producto))
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
    assert_equal "surtido", pedido_lineas(:pechuga_5).reload.estado
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

  test "sin pedido no hay producción, ni contra uno cerrado, ni sin existencia" do
    assert_raises(ActiveRecord::RecordInvalid) { abrir(pedido: nil) }
    pedidos(:abierto).update!(estado: "cerrado")
    e = assert_raises(ActiveRecord::RecordInvalid) { abrir }
    assert_match "abierto", e.message
    pedidos(:abierto).update!(estado: "solicitado")
    assert abrir.persisted?
    assert_raises(Inventario::SinExistencia) { abrir }
  end
end
