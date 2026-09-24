require "test_helper"

# Autorización diferida: lo hecho sin nadie que lo autorizara se revisa al final del día.
class RevisionesTest < ActionDispatch::IntegrationTest
  setup do
    @tienda = sucursales(:tienda)
    post entrar_path, params: { usuario: "cajera", password: "secreto1" }
    post caja_abrir_path, params: { fondo: "500.00" }
    post caja_retirar_path, params: { monto: "150", motivo: "pago al gas, no había nadie" }
    @revision = Revision.last
  end

  test "la cajera no ve la bandeja; la supervisora la ve en el inicio y observa con cargo" do
    get revisiones_path
    assert_response :forbidden
    delete salir_path
    post entrar_path, params: { usuario: "supervisora", password: "secreto1" }
    get root_path
    assert_select "div", /1.*espera revisión/
    get revisiones_path
    assert_select "td", /Retiro de \$150\.00/
    assert_select "td", /pago al gas/
    post resolver_revision_path(@revision), params: { estado: "observada", nota: "sin comprobante", cargo: "150" }
    assert_redirected_to revisiones_path
    @revision.reload
    assert_equal "observada", @revision.estado
    assert_equal usuarios(:supervisora), @revision.revisado_por
    cargo = @revision.cargo
    assert_equal usuarios(:cajera), cargo.usuario
    assert_equal @tienda, cargo.sucursal
    assert_equal 15_000, cargo.monto_centavos
    assert_match "sin comprobante", cargo.detalle
    get cargos_path
    assert_select "td", /Cajera/
    assert_select "a", "revisión"
    get root_path
    assert_select "div", { text: /espera revisión/, count: 0 }
  end

  test "aprobar cierra la revisión sin cargo y no se resuelve dos veces" do
    post entrar_path, params: { usuario: "supervisora", password: "secreto1" }
    post resolver_revision_path(@revision), params: { estado: "aprobada", nota: "ok, avisó por teléfono" }
    assert_equal "aprobada", @revision.reload.estado
    assert_nil @revision.cargo
    post resolver_revision_path(@revision), params: { estado: "observada", cargo: "150" }
    assert_match "ya está aprobada", flash[:alert]
    assert_equal 0, Cargo.count
  end

  test "el renglón manual de una devolución también queda por revisar" do
    post entrar_path, params: { usuario: "supervisora", password: "secreto1" }
    Inventario.mover!(sucursal: @tienda, producto: productos(:catsup), tipo: "entrada", cantidad: 4, usuario: usuarios(:supervisora))
    post salidas_path, params: { destino: "sucursal:#{sucursales(:matriz).id}", motivo: "devolución" }
    salida = Salida.last
    post manual_salida_path(salida), params: { producto_id: productos(:catsup).id, cantidad: "2", motivo: "se despegó" }
    linea = salida.lineas.last
    assert_nil linea.autorizado_por
    assert_equal usuarios(:supervisora), linea.usuario
    assert_equal linea, Revision.last.revisable
    assert_equal 8_400, Revision.last.valor_centavos
    get revisiones_path
    assert_select "td", /Renglón sin etiqueta en DV-/
    assert_equal 2, Revision.pendientes.count
  end
end
