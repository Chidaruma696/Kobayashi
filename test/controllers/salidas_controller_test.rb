require "test_helper"

class SalidasControllerTest < ActionDispatch::IntegrationTest
  setup do
    @matriz = sucursales(:matriz)
    @tienda = sucursales(:tienda)
    Inventario.mover!(sucursal: @matriz, producto: productos(:pechuga), tipo: "entrada", cantidad: 10, usuario: usuarios(:admin))
    @p = Etiqueta.create!(tipo: "paquete", producto: productos(:pechuga), cantidad: "4.000", sucursal: @matriz, usuario: usuarios(:admin), pedido_linea: pedido_lineas(:pechuga_5))
  end

  test "flujo completo por pantalla: abrir, surtir, verificar, sellar, enviar, recibir y cerrar" do
    post entrar_path, params: { usuario: "admin", password: "secreto1" }
    post salidas_path, params: { sucursal_destino_id: @tienda.id }
    salida = Salida.last
    assert_redirected_to salida_path(salida)
    post agregar_salida_path(salida), params: { codigo: @p.codigo }
    assert_equal 1, salida.salida_etiquetas.count
    post agregar_salida_path(salida), params: { codigo: "0000000000000" }
    assert_match "no se encontró", flash[:alert]
    post verificar_salida_path(salida), params: { codigo: @p.codigo }
    assert_match "propia carga", flash[:alert]
    delete salir_path

    post entrar_path, params: { usuario: "supervisora", password: "secreto1" }
    post verificar_salida_path(salida), params: { codigo: @p.codigo }
    post sellar_salida_path(salida)
    assert_equal "sellada", salida.reload.estado
    post enviar_salida_path(salida)
    assert_redirected_to salidas_path
    assert_equal "enviada", salida.reload.estado
    assert_equal BigDecimal("6"), Existencia.de(@matriz, productos(:pechuga))
    delete salir_path

    post entrar_path, params: { usuario: "cajera", password: "secreto1" }
    get recibir_salidas_path
    assert_select "td", /#{salida.folio}/
    get salida_path(salida)
    assert_select "h2", /Recibir/
    post recibir_etiqueta_salida_path(salida), params: { codigo: @p.codigo }
    assert_equal BigDecimal("4"), Existencia.de(@tienda, productos(:pechuga))
    post cerrar_recepcion_salida_path(salida)
    assert_redirected_to recibir_salidas_path
    assert_equal "recibida", salida.reload.estado
  end

  test "la tienda no toca las salidas de otros" do
    post entrar_path, params: { usuario: "cajera", password: "secreto1" }
    otra = Sucursal.create!(codigo: "T02", nombre: "Tienda 2")
    salida = Salida.nueva!(origen: @matriz, destino: otra, usuario: usuarios(:admin))
    get salida_path(salida)
    assert_response :not_found
  end
end
