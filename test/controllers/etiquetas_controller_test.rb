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

  test "etiquetar sin pedido exige motivo; con permiso queda a su nombre y sin permiso queda por revisar" do
    post etiquetas_path, params: { producto_id: productos(:pechuga).id, tipo: "paquete", cantidad: "1" }
    assert_redirected_to new_etiqueta_path(producto_id: productos(:pechuga).id)
    assert_match "motivo", flash[:alert]
    assert_equal 0, Etiqueta.count
    delete salir_path
    post entrar_path, params: { usuario: "supervisora", password: "secreto1" }
    # La supervisora no tiene etiquetas.libre: no se frena, se etiqueta y queda por revisar con lo que vale.
    post etiquetas_path, params: { producto_id: productos(:pechuga).id, tipo: "paquete", cantidad: "1.5", justificacion: "urge, no hay nadie" }
    assert_nil Etiqueta.last.autorizado_por
    r = Revision.last
    assert_equal Etiqueta.last, r.revisable
    assert_equal usuarios(:supervisora), r.usuario
    assert_equal 19_350, r.valor_centavos
  end

  test "sin permiso de etiquetas responde 403 con la clave que falta" do
    delete salir_path
    post entrar_path, params: { usuario: "cajera", password: "secreto1" }
    get new_etiqueta_path
    assert_response :forbidden
    assert_match "etiquetas.crear", response.body
  end
end

class EtiquetadoraTest < ActionDispatch::IntegrationTest
  setup { post entrar_path, params: { usuario: "admin", password: "secreto1" } }

  test "la etiquetadora carga con el producto del renglón, el banner del pedido y el checklist" do
    get new_etiqueta_path(pedido_linea_id: pedido_lineas(:pechuga_5).id)
    assert_response :ok
    assert_select "[data-controller=?]", "etiquetadora pedidos-surtir"
    assert_match "Pechuga de pollo", response.body
    assert_select "div", /PARA TIENDA 1 · P-00900/
    assert_select "dialog[data-pedidos-surtir-target=dialogo]"
    assert_select "button", /Pedidos por surtir/
    assert_select "span", "2", "dos renglones pendientes en el contador"

    # Sustituto: otro producto en lugar del pedido, declarado.
    get new_etiqueta_path(pedido_linea_id: pedido_lineas(:pechuga_5).id, producto_id: productos(:catsup).id, sustituto: 1)
    assert_select "div", /SUSTITUTO: Cátsup 1 kg/
    assert_select "[data-etiquetadora-sustituto-value=true]"
  end

  test "el checklist del pedido en JSON: renglones, bultos, salida y verificación; sustituto declarado" do
    linea = pedido_lineas(:pechuga_5)
    post lote_etiquetas_path, params: { producto_id: productos(:pechuga).id, pedido_linea_id: linea.id, pesadas: [ { cantidad: "1" }, { cantidad: "2" } ], caja: "1" }, as: :json
    caja = response.parsed_body["caja"]["codigo"]
    pollo = Producto.create!(clave: "POLLO", nombre: "Pollo entero", unidad: "kg", precio: 60)
    post lote_etiquetas_path, params: { producto_id: pollo.id, pedido_linea_id: linea.id, pesadas: [ { cantidad: "1.5" } ] }, as: :json
    assert_response :unprocessable_entity, "un producto que no está en el pedido, sin declararlo sustituto, no pasa"
    post lote_etiquetas_path, params: { producto_id: pollo.id, pedido_linea_id: linea.id, pesadas: [ { cantidad: "1.5" } ], sustituto: "1" }, as: :json
    assert_response :ok
    assert_equal linea, Etiqueta.last.pedido_linea

    get pedidos_path, as: :json
    assert_equal [ "P-00900" ], response.parsed_body["pedidos"].map { |p| p["folio"] }
    get pedido_path(linea.pedido), as: :json
    d = response.parsed_body
    assert_equal "S-00001", d["salida"]["folio"]
    assert_equal 3, d["salida"]["sin_verificar"]
    r = d["renglones"].find { |x| x["id"] == linea.id }
    assert_equal "4,500", r["surtida"]
    assert_equal 90, r["pct"]
    assert_equal [ caja, Etiqueta.last.codigo ], r["bultos"].map { |b| b["codigo"] }
    assert_equal [ 2, nil ], r["bultos"].map { |b| b["paquetes"] }
    assert_equal [ nil, "Pollo entero" ], r["bultos"].map { |b| b["sustituto"] }
    assert r["bultos"].all? { |b| b["salida"]["estado"] == "preparando" && !b["verificada"] }

    post no_surtir_pedido_linea_path(linea.pedido, pedido_lineas(:catsup_10)), params: { motivo: "no hay" }, as: :json
    assert_equal "no_surtir", response.parsed_body["estado"]
    post no_surtir_pedido_linea_path(linea.pedido, pedido_lineas(:catsup_10)), params: { motivo: "" }, as: :json
    assert_response :unprocessable_entity
  end

  test "el buscador responde JSON por nombre, PLU o código de proveedor" do
    productos(:catsup).codigos_barras.create!(codigo: "7501000123457")
    get productos_etiquetas_path(q: "pech"), headers: { "Accept" => "application/json" }
    assert_equal [ "Pechuga de pollo" ], response.parsed_body.map { |p| p["nombre"] }
    get productos_etiquetas_path(q: "90002"), headers: { "Accept" => "application/json" }
    assert_equal [ "Cátsup 1 kg" ], response.parsed_body.map { |p| p["nombre"] }
    get productos_etiquetas_path(q: "7501000123457"), headers: { "Accept" => "application/json" }
    assert_includes response.parsed_body.first["codigos"], "7501000123457"
  end

  test "un lote registra las pesadas, las cierra en caja y devuelve códigos con barcode" do
    post lote_etiquetas_path, params: { producto_id: productos(:pechuga).id, pedido_linea_id: pedido_lineas(:pechuga_5).id,
                                        pesadas: [ { cantidad: "1.250" }, { cantidad: "0.980" } ], caja: "1" }, as: :json
    assert_response :ok
    datos = response.parsed_body
    assert_equal 2, datos["etiquetas"].size
    assert datos["etiquetas"].all? { |e| e["codigo"].start_with?("08") && e["svg"].include?("<svg") }
    assert datos["caja"]["codigo"].start_with?("07")
    assert_equal "2.23", datos["caja"]["cantidad"]
    assert_equal "2,230", datos["lleva"], "lleva viene formateado para pantalla, con la coma del locale"
    caja = Etiqueta.find(datos["caja"]["id"])
    assert_equal 2, caja.hijas.count
    assert_equal pedido_lineas(:pechuga_5), caja.hijas.first.pedido_linea

    # Pesadas ya registradas (impresión al instante) se agrupan por id sin duplicarse.
    suelta = Etiqueta.create!(tipo: "paquete", producto: productos(:pechuga), cantidad: 2, sucursal: sucursales(:matriz), usuario: usuarios(:admin), pedido_linea: pedido_lineas(:pechuga_5))
    assert_difference("Etiqueta.count", 2) do
      post lote_etiquetas_path, params: { producto_id: productos(:pechuga).id, pedido_linea_id: pedido_lineas(:pechuga_5).id,
                                          pesadas: [ { id: suelta.id }, { cantidad: "1" } ], caja: "1" }, as: :json
    end
    assert_response :ok
    assert_equal response.parsed_body["caja"]["id"], suelta.reload.padre_id
  end

  test "un lote rechaza un producto que no está en el pedido y exige autorización sin contexto" do
    post lote_etiquetas_path, params: { producto_id: productos(:catsup).id, pedido_linea_id: pedido_lineas(:pechuga_5).id, pesadas: [ { cantidad: "1" } ] }, as: :json
    assert_response :ok, "la cátsup sí está en el pedido, cae en su renglón"
    assert_equal pedido_lineas(:catsup_10), Etiqueta.last.pedido_linea
    post lote_etiquetas_path, params: { producto_id: productos(:pechuga).id, pesadas: [ { cantidad: "1" } ] }, as: :json
    assert_response :unprocessable_entity
    assert_match "motivo", response.parsed_body["error"]
    post lote_etiquetas_path, params: { producto_id: productos(:pechuga).id, pesadas: [ { cantidad: "1" } ], justificacion: "muestra" }, as: :json
    assert_response :ok
  end

  test "lo que se registra contra un pedido entra solo a la salida de ese destino, sin volver a escanear" do
    linea = pedido_lineas(:pechuga_5)
    post lote_etiquetas_path, params: { producto_id: productos(:pechuga).id, pedido_linea_id: linea.id, pesadas: [ { cantidad: "1" }, { cantidad: "2" } ], caja: "1" }, as: :json
    assert_response :ok
    datos = response.parsed_body
    salida = Salida.find(datos["salida"]["id"])
    assert_equal "preparando", salida.estado
    assert_equal sucursales(:tienda), salida.destino
    assert_equal 2, datos["salida"]["paquetes"]
    assert_equal datos["caja"]["id"], salida.salida_etiquetas.first.grupo_id

    # Al vuelo: cada pesada entra suelta; al cerrar la caja se reagrupan bajo ella en la misma salida.
    ids = 2.times.map do |i|
      post lote_etiquetas_path, params: { producto_id: productos(:pechuga).id, pedido_linea_id: linea.id, pesadas: [ { cantidad: "0.5" } ] }, as: :json
      assert_equal salida.folio, response.parsed_body["salida"]["folio"]
      response.parsed_body["etiquetas"].first["id"]
    end
    assert_equal [ nil ], salida.salida_etiquetas.where(etiqueta_id: ids).distinct.pluck(:grupo_id)
    post lote_etiquetas_path, params: { producto_id: productos(:pechuga).id, pedido_linea_id: linea.id, pesadas: ids.map { |id| { id: id } }, caja: "1" }, as: :json
    caja2 = response.parsed_body["caja"]["id"]
    assert_equal [ caja2 ], salida.salida_etiquetas.where(etiqueta_id: ids).distinct.pluck(:grupo_id)
    assert_equal 4, salida.salida_etiquetas.count
    assert_equal 1, Salida.count, "una sola salida por destino mientras se arma"
  end

  test "dar de baja desde la etiquetadora: sale de la salida, la caja se queda con lo que trae y el renglón baja" do
    linea = pedido_lineas(:pechuga_5)
    post lote_etiquetas_path, params: { producto_id: productos(:pechuga).id, pedido_linea_id: linea.id, pesadas: [ { cantidad: "1" }, { cantidad: "2" } ], caja: "1" }, as: :json
    datos = response.parsed_body
    caja = Etiqueta.find(datos["caja"]["id"])
    salida = Salida.find(datos["salida"]["id"])
    hija = caja.hijas.order(:cantidad).first
    post baja_etiqueta_path(hija), params: { motivo: "peso mal capturado" }, as: :json
    assert_response :ok
    assert_equal "baja", hija.reload.estado
    assert_equal "2.0", response.parsed_body["padre"]["cantidad"]
    assert_equal BigDecimal("2"), caja.reload.cantidad
    assert_equal 1, salida.salida_etiquetas.count
    assert_equal "2,000", response.parsed_body["lleva"]

    post baja_etiqueta_path(caja), params: { motivo: "producto equivocado" }, as: :json
    assert_response :ok
    assert_equal "baja", caja.reload.estado
    assert_equal 0, salida.salida_etiquetas.count
    assert_equal 0, linea.reload.cantidad_surtida
    assert_equal "pendiente", linea.estado

    # Ya sellada no se toca desde aquí.
    post lote_etiquetas_path, params: { producto_id: productos(:pechuga).id, pedido_linea_id: linea.id, pesadas: [ { cantidad: "1" } ], caja: "1" }, as: :json
    caja3 = Etiqueta.find(response.parsed_body["caja"]["id"])
    salida.reload.sellar!(usuario: usuarios(:supervisora), sin_verificar_motivo: "prueba")
    post baja_etiqueta_path(caja3), params: { motivo: "me equivoqué" }, as: :json
    assert_response :unprocessable_entity
    assert_match "sellada", response.parsed_body["error"]
    assert_equal "viva", caja3.reload.estado
  end

  test "caja fija de proveedor de N piezas" do
    post lote_etiquetas_path, params: { producto_id: productos(:catsup).id, pedido_linea_id: pedido_lineas(:catsup_10).id, caja_fija: "12" }, as: :json
    assert_response :ok
    caja = Etiqueta.find(response.parsed_body["caja"]["id"])
    assert caja.caja?
    assert_equal 12, caja.cantidad
    assert_equal 0, caja.hijas.count
  end

  test "imprimir varias etiquetas con el tamaño elegido y copias de un código de proveedor" do
    ids = 2.times.map { Etiqueta.create!(tipo: "paquete", producto: productos(:pechuga), cantidad: 1, sucursal: sucursales(:matriz), usuario: usuarios(:admin), pedido_linea: pedido_lineas(:pechuga_5)).id }
    get imprimir_etiquetas_path(ids: ids.join(","), ancho: 80, alto: 40, leyenda: "Elma Meat")
    assert_response :ok
    assert_select ".etiqueta", 2
    assert_select "svg", 2
    assert_match "size: 80mm 40mm", response.body
    assert_match "Elma Meat", response.body
    get imprimir_etiquetas_path(codigo: "750100012345", n: 3, nombre: "Cátsup")
    assert_select ".etiqueta", 3
    assert_select "svg", 3
  end
end
