require "test_helper"

class EtiquetasControllerTest < ActionDispatch::IntegrationTest
  setup { post entrar_path, params: { usuario: "admin", password: "secreto1" } }

  test "etiquetar un paquete responde por turbo stream y lo deja vivo en la matriz" do
    post etiquetas_path, params: { producto_id: productos(:pechuga).id, tipo: "paquete", cantidad: "1.250", pedido_linea_id: pedido_lineas(:pechuga_5).id },
         headers: { "Accept" => "text/vnd.turbo-stream.html" }
    assert_response :ok
    etiqueta = Etiqueta.last
    assert_equal "paquete", etiqueta.tipo
    assert_equal BigDecimal("1.25"), etiqueta.cantidad
    assert_equal sucursales(:matriz), etiqueta.sucursal
    assert_match etiqueta.codigo, response.body

    get etiquetas_path
    assert_select "li", /Pechuga/
    get etiqueta_path(etiqueta)
    assert_select "svg"
    get buscar_etiquetas_path(codigo: etiqueta.codigo), headers: { "Accept" => "application/json" }
    assert_equal etiqueta.id, response.parsed_body["id"]
  end

  test "cerrar caja y dar de baja desde la interfaz" do
    ids = 2.times.map { Etiqueta.create!(tipo: "paquete", producto: productos(:pechuga), cantidad: 1, sucursal: sucursales(:matriz), usuario: usuarios(:admin), pedido_linea: pedido_lineas(:pechuga_5)).id }
    post cerrar_caja_etiquetas_path, params: { ids: ids }
    caja = Etiqueta.where(tipo: "caja").last
    assert_redirected_to etiqueta_path(caja)
    post baja_etiqueta_path(caja), params: { motivo: "se cayó" }
    assert_redirected_to etiquetas_path
    assert_equal "baja", caja.reload.estado
    post baja_etiqueta_path(caja), params: { motivo: "" }
    assert_redirected_to etiquetas_path
    assert_match "motivo", flash[:alert]
  end

  test "etiquetar sin pedido exige PIN de quien autoriza y motivo" do
    post etiquetas_path, params: { producto_id: productos(:pechuga).id, tipo: "paquete", cantidad: "1" }
    assert_redirected_to new_etiqueta_path(producto_id: productos(:pechuga).id)
    assert_match "autorización", flash[:alert]
    assert_equal 0, Etiqueta.count
    delete salir_path
    post entrar_path, params: { usuario: "supervisora", password: "secreto1" }
    # La supervisora no tiene etiquetas.libre; el PIN del admin sí lo cubre.
    post etiquetas_path, params: { producto_id: productos(:pechuga).id, tipo: "paquete", cantidad: "1", pin: "9999", justificacion: "muestra para cliente" }
    assert_redirected_to new_etiqueta_path(producto_id: productos(:pechuga).id)
    assert_equal usuarios(:admin), Etiqueta.last.autorizado_por
  end

  test "sin permiso de etiquetas responde 403 con la clave que falta" do
    delete salir_path
    post entrar_path, params: { usuario: "cajera", password: "secreto1" }
    get new_etiqueta_path
    assert_response :forbidden
    assert_match "etiquetas.crear", response.body
  end
end
