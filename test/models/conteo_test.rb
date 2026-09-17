require "test_helper"

class ConteoTest < ActiveSupport::TestCase
  setup do
    @tienda = sucursales(:tienda)
    @super = usuarios(:supervisora)
    @cajera = usuarios(:cajera)
    Inventario.mover!(sucursal: @tienda, producto: productos(:pechuga), tipo: "entrada", cantidad: 5, usuario: @super)
    Inventario.mover!(sucursal: @tienda, producto: productos(:catsup), tipo: "entrada", cantidad: 10, usuario: @super)
    @a = paquete("2.000")
    @b = paquete("3.000")
  end

  def paquete(cantidad)
    Etiqueta.create!(tipo: "paquete", producto: productos(:pechuga), cantidad: cantidad, sucursal: @tienda, usuario: @super, autorizado_por: usuarios(:admin), justificacion: "prueba")
  end

  test "abre con la existencia, escanea una vez cada etiqueta y teclea lo que no lleva etiqueta" do
    c = Conteo.abrir!(sucursal: @tienda, usuario: @super, responsable: @cajera)
    assert_match(/\AK-\d{5}\z/, c.folio)
    assert_equal({ productos(:pechuga) => BigDecimal("5"), productos(:catsup) => BigDecimal("10") }, c.lineas.to_h { |l| [ l.producto, l.sistema ] })
    assert_equal 1, c.escanear!(@a)
    assert_raises(ArgumentError) { c.escanear!(@a) }
    c.contar_manual!(productos(:catsup), 9)
    c.contar_manual!(productos(:catsup), 8)
    assert_equal BigDecimal("2"), c.lineas.find_by(producto: productos(:pechuga)).contado
    assert_equal BigDecimal("8"), c.lineas.find_by(producto: productos(:catsup)).contado
    assert_equal [ @b ], c.etiquetas_no_vistas.to_a
    assert_raises(ArgumentError) { Conteo.abrir!(sucursal: @tienda, usuario: @super, responsable: @cajera) }
  end

  test "al cerrar manda el conteo: ajusta el inventario, mata las etiquetas no vistas y carga el faltante" do
    c = Conteo.abrir!(sucursal: @tienda, usuario: @super, responsable: @cajera)
    c.escanear!(@a)
    c.contar_manual!(productos(:catsup), 8)
    c.cerrar!(usuario: @super)
    assert_equal "cerrado", c.estado
    assert_equal BigDecimal("2"), Existencia.de(@tienda, productos(:pechuga))
    assert_equal BigDecimal("8"), Existencia.de(@tienda, productos(:catsup))
    assert_equal "baja", @b.reload.estado
    assert_match c.folio, @b.motivo
    # faltan 3 kg de pechuga (3 × 129) y 2 cátsup (2 × 42) = 387 + 84 = 471
    assert_equal 47_100, c.faltante_centavos
    assert_equal 0, c.sobrante_centavos
    cargo = Cargo.last
    assert_equal @cajera, cargo.usuario
    assert_equal 47_100, cargo.monto_centavos
    assert_match "Pechuga", cargo.detalle
    assert_equal 2, Movimiento.where(referencia: c).count
    assert_raises(ArgumentError) { c.cerrar!(usuario: @super) }
    cargo.resolver!("cobrado", usuario: @super)
    assert_equal "cobrado", cargo.estado
    assert_raises(ArgumentError) { cargo.resolver!("perdonado", usuario: @super) }
  end

  test "un sobrante no genera cargo y un conteo exacto no mueve nada" do
    c = Conteo.abrir!(sucursal: @tienda, usuario: @super, responsable: @cajera)
    c.escanear!(@a)
    c.escanear!(@b)
    c.contar_manual!(productos(:catsup), 11)
    c.cerrar!(usuario: @super)
    assert_equal 0, c.faltante_centavos
    assert_equal 4_200, c.sobrante_centavos
    assert_equal 0, Cargo.count
    assert_equal BigDecimal("11"), Existencia.de(@tienda, productos(:catsup))
  end
end
