# La cinta tipo Office: pestañas por módulo y, debajo, botones grandes con las acciones.
# Cada botón lleva su clave de texto (cinta.botones.*), el permiso que hace falta y el nombre de
# su icono (Bootstrap Icons); una pestaña se ve si alguno de sus botones se ve.
module RibbonHelper
  Boton = Struct.new(:clave, :ruta, :permiso, :icono)

  PESTANAS = [
    { id: :inicio, grupos: [
      { id: :ver, botones: [
        Boton.new(:inicio, :root_path, nil, "house"),
        Boton.new(:ventas_por_producto, :ventas_por_producto_path, "reportes.ver", "graph-up")
      ] },
      { id: :revisar, botones: [ Boton.new(:por_revisar, :revisiones_path, "revisiones.resolver", "clipboard-check") ] },
      { id: :ajustes, botones: [ Boton.new(:ajustes, :ajustes_path, nil, "gear") ] }
    ] },
    { id: :caja, grupos: [
      { id: :vender, botones: [
        Boton.new(:vender, :caja_path, "caja.vender", "cart3"),
        Boton.new(:ventas, :caja_ventas_path, "caja.vender", "receipt"),
        Boton.new(:devolucion, :caja_devolucion_path, "caja.devolver", "arrow-return-left")
      ] },
      { id: :corte, botones: [ Boton.new(:corte, :caja_corte_path, "caja.abrir", "cash-stack") ] }
    ] },
    { id: :pedidos, grupos: [
      { id: :pedir, botones: [
        Boton.new(:nuevo_pedido, :new_pedido_path, "pedidos.solicitar", "plus-lg"),
        Boton.new(:mis_pedidos, :pedidos_path, "pedidos.solicitar", "list-ul")
      ] },
      { id: :surtir, botones: [
        Boton.new(:cola, :pedidos_path, "pedidos.surtir", "list-ul"),
        Boton.new(:pendientes, :pendientes_pedidos_path, "pedidos.surtir", "printer")
      ] }
    ] },
    { id: :etiquetas, grupos: [
      { id: :producir, botones: [
        Boton.new(:produccion, :new_produccion_path, "produccion.abrir", "hammer"),
        Boton.new(:abiertas, :producciones_path, "produccion.abrir", "folder2-open")
      ] },
      { id: :etiquetar, botones: [
        Boton.new(:etiquetar, :new_etiqueta_path, "etiquetas.crear", "tag"),
        Boton.new(:vivas, :etiquetas_path, "etiquetas.crear", "grid-3x3-gap")
      ] }
    ] },
    { id: :salidas, grupos: [
      { id: :enviar, botones: [
        Boton.new(:nueva_salida, :new_salida_path, "salidas.surtir", "truck"),
        Boton.new(:en_curso, :salidas_path, "salidas.surtir", "list-ul")
      ] },
      { id: :recibir, botones: [ Boton.new(:por_recibir, :recibir_salidas_path, "salidas.recibir", "inbox") ] }
    ] },
    { id: :rutas, grupos: [
      { id: :viajes, botones: [
        Boton.new(:nuevo_viaje, :new_viaje_path, "rutas.armar", "truck-front"),
        Boton.new(:viajes, :viajes_path, "rutas.armar", "list-ul")
      ] },
      { id: :chofer, botones: [ Boton.new(:mi_ruta, :reparto_path, "rutas.repartir", "geo-alt") ] },
      { id: :oficina, botones: [
        Boton.new(:liquidar, :viajes_path, "rutas.liquidar", "cash-stack"),
        Boton.new(:cobranza, :cobranza_path, "cobranza.ver", "journal-text"),
        Boton.new(:canastillas, :canastillas_path, "canastillas.ver", "basket")
      ] }
    ] },
    { id: :conteos, grupos: [
      { id: :contar, botones: [
        Boton.new(:nuevo_conteo, :new_conteo_path, "conteos.hacer", "search"),
        Boton.new(:conteos, :conteos_path, "conteos.hacer", "list-ul")
      ] },
      { id: :cargos, botones: [ Boton.new(:cargos, :cargos_path, "conteos.cargos", "cash-coin") ] }
    ] },
    { id: :inventario, grupos: [
      { id: :consultar, botones: [
        Boton.new(:existencias, :inventario_path, "inventario.ver", "list"),
        Boton.new(:kardex, :kardex_inventario_path, "inventario.ver", "arrow-down-up")
      ] },
      { id: :capturar, botones: [
        Boton.new(:entrada_ajuste, :nuevo_movimiento_inventario_path, "inventario.ajustar", "pencil")
      ] }
    ] },
    { id: :admin, grupos: [
      { id: :catalogo, botones: [
        Boton.new(:productos, :admin_productos_path, "admin.catalogo", "box-seam"),
        Boton.new(:promociones, :admin_promociones_path, "admin.catalogo", "percent")
      ] },
      { id: :reparto, modulo: "rutas", botones: [
        Boton.new(:clientes, :admin_clientes_path, "admin.catalogo", "people"),
        Boton.new(:rutas, :admin_rutas_path, "admin.catalogo", "signpost-split"),
        Boton.new(:convenios, :admin_convenios_path, "admin.catalogo", "file-earmark-text"),
        Boton.new(:tipos_canastilla, :admin_tipos_canastilla_path, "admin.catalogo", "basket3")
      ] },
      { id: :gente, botones: [
        Boton.new(:usuarios, :admin_usuarios_path, "admin.usuarios", "person"),
        Boton.new(:roles, :admin_roles_path, "admin.usuarios", "key"),
        Boton.new(:sucursales, :admin_sucursales_path, "admin.usuarios", "shop")
      ] }
    ] }
  ].freeze

  def boton_visible?(boton)
    boton.permiso.nil? || puede?(boton.permiso)
  end

  def grupo_visible?(grupo)
    (grupo[:modulo].nil? || Modulo.activo?(grupo[:modulo])) && grupo[:botones].any? { |b| boton_visible?(b) }
  end

  # Una pestaña se ve si su módulo está encendido y alguno de sus grupos se ve.
  def pestanas_visibles
    PESTANAS.select { |p| Modulo.activo?(p[:id]) && p[:grupos].any? { |g| grupo_visible?(g) } }
  end

  # Ajustes cuelga de Inicio en la cinta, pero es su propia pestaña activa: cae en Inicio.
  def pestana_activa
    PESTANAS.find { |p| p[:id] == controller.pestana_ribbon } || PESTANAS.first
  end

  def ruta_de_pestana(pestana)
    boton = pestana[:grupos].select { |g| grupo_visible?(g) }.flat_map { |g| g[:botones] }.find { |b| boton_visible?(b) }
    boton ? send(boton.ruta) : root_path
  end
end
