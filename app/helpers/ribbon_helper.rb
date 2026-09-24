# La cinta tipo Office: pestañas por módulo y, debajo, botones grandes con las acciones.
# Cada botón lleva el permiso que hace falta y el nombre de su icono (Bootstrap Icons); una pestaña
# se ve si alguno de sus botones se ve.
module RibbonHelper
  Boton = Struct.new(:nombre, :ruta, :permiso, :icono)

  PESTANAS = [
    { id: :inicio, nombre: "Inicio", grupos: [
      { nombre: "Ver", botones: [
        Boton.new("Inicio", :root_path, nil, "house"),
        Boton.new("Ventas por producto", :ventas_por_producto_path, "reportes.ver", "graph-up")
      ] },
      { nombre: "Revisar", botones: [ Boton.new("Por revisar", :revisiones_path, "revisiones.resolver", "clipboard-check") ] }
    ] },
    { id: :caja, nombre: "Caja", grupos: [
      { nombre: "Vender", botones: [
        Boton.new("Vender", :caja_path, "caja.vender", "cart3"),
        Boton.new("Ventas", :caja_ventas_path, "caja.vender", "receipt"),
        Boton.new("Devolución", :caja_devolucion_path, "caja.devolver", "arrow-return-left")
      ] },
      { nombre: "Corte", botones: [ Boton.new("Corte", :caja_corte_path, "caja.abrir", "cash-stack") ] }
    ] },
    { id: :pedidos, nombre: "Pedidos", grupos: [
      { nombre: "Pedir", botones: [
        Boton.new("Nuevo pedido", :new_pedido_path, "pedidos.solicitar", "plus-lg"),
        Boton.new("Mis pedidos", :pedidos_path, "pedidos.solicitar", "list-ul")
      ] },
      { nombre: "Surtir", botones: [
        Boton.new("Cola", :pedidos_path, "pedidos.surtir", "list-ul"),
        Boton.new("Pendientes", :pendientes_pedidos_path, "pedidos.surtir", "printer")
      ] }
    ] },
    { id: :etiquetas, nombre: "Etiquetas", grupos: [
      { nombre: "Producir", botones: [
        Boton.new("Producción", :new_produccion_path, "produccion.abrir", "hammer"),
        Boton.new("Abiertas", :producciones_path, "produccion.abrir", "folder2-open")
      ] },
      { nombre: "Etiquetar", botones: [
        Boton.new("Etiquetar", :new_etiqueta_path, "etiquetas.crear", "tag"),
        Boton.new("Vivas", :etiquetas_path, "etiquetas.crear", "grid-3x3-gap")
      ] }
    ] },
    { id: :salidas, nombre: "Salidas", grupos: [
      { nombre: "Enviar", botones: [
        Boton.new("Nueva salida", :new_salida_path, "salidas.surtir", "truck"),
        Boton.new("En curso", :salidas_path, "salidas.surtir", "list-ul")
      ] },
      { nombre: "Recibir", botones: [ Boton.new("Por recibir", :recibir_salidas_path, "salidas.recibir", "inbox") ] }
    ] },
    { id: :rutas, nombre: "Rutas", grupos: [
      { nombre: "Viajes", botones: [
        Boton.new("Nuevo viaje", :new_viaje_path, "rutas.armar", "truck-front"),
        Boton.new("Viajes", :viajes_path, "rutas.armar", "list-ul")
      ] },
      { nombre: "Chofer", botones: [ Boton.new("Mi ruta", :reparto_path, "rutas.repartir", "geo-alt") ] },
      { nombre: "Oficina", botones: [
        Boton.new("Liquidar", :viajes_path, "rutas.liquidar", "cash-stack"),
        Boton.new("Cobranza", :cobranza_path, "cobranza.ver", "journal-text"),
        Boton.new("Canastillas", :canastillas_path, "canastillas.ver", "basket")
      ] }
    ] },
    { id: :conteos, nombre: "Conteos", grupos: [
      { nombre: "Contar", botones: [
        Boton.new("Nuevo conteo", :new_conteo_path, "conteos.hacer", "search"),
        Boton.new("Conteos", :conteos_path, "conteos.hacer", "list-ul")
      ] },
      { nombre: "Cargos", botones: [ Boton.new("Cargos", :cargos_path, "conteos.cargos", "cash-coin") ] }
    ] },
    { id: :inventario, nombre: "Inventario", grupos: [
      { nombre: "Consultar", botones: [
        Boton.new("Existencias", :inventario_path, "inventario.ver", "list"),
        Boton.new("Kardex", :kardex_inventario_path, "inventario.ver", "arrow-down-up")
      ] },
      { nombre: "Capturar", botones: [
        Boton.new("Entrada / ajuste", :nuevo_movimiento_inventario_path, "inventario.ajustar", "pencil")
      ] }
    ] },
    { id: :admin, nombre: "Admin", grupos: [
      { nombre: "Catálogo", botones: [
        Boton.new("Productos", :admin_productos_path, "admin.catalogo", "box-seam"),
        Boton.new("Promociones", :admin_promociones_path, "admin.catalogo", "percent")
      ] },
      { nombre: "Reparto", botones: [
        Boton.new("Clientes", :admin_clientes_path, "admin.catalogo", "people"),
        Boton.new("Rutas", :admin_rutas_path, "admin.catalogo", "signpost-split"),
        Boton.new("Convenios", :admin_convenios_path, "admin.catalogo", "file-earmark-text"),
        Boton.new("Canastillas", :admin_tipos_canastilla_path, "admin.catalogo", "basket3")
      ] },
      { nombre: "Gente", botones: [
        Boton.new("Usuarios", :admin_usuarios_path, "admin.usuarios", "person"),
        Boton.new("Roles", :admin_roles_path, "admin.usuarios", "key"),
        Boton.new("Sucursales", :admin_sucursales_path, "admin.usuarios", "shop")
      ] }
    ] }
  ].freeze

  def boton_visible?(boton)
    boton.permiso.nil? || puede?(boton.permiso)
  end

  def pestanas_visibles
    PESTANAS.select { |p| p[:grupos].any? { |g| g[:botones].any? { |b| boton_visible?(b) } } }
  end

  def pestana_activa
    PESTANAS.find { |p| p[:id] == controller.pestana_ribbon } || PESTANAS.first
  end

  def ruta_de_pestana(pestana)
    boton = pestana[:grupos].flat_map { |g| g[:botones] }.find { |b| boton_visible?(b) }
    boton ? send(boton.ruta) : root_path
  end
end
