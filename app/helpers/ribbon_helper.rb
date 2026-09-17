# La cinta tipo Office: pestañas por módulo y, debajo, botones grandes con las acciones.
# Cada botón lleva el permiso que hace falta; una pestaña se ve si alguno de sus botones se ve.
module RibbonHelper
  Boton = Struct.new(:nombre, :ruta, :permiso, :icono)

  PESTANAS = [
    { id: :inicio, nombre: "Inicio", grupos: [
      { nombre: "General", botones: [ Boton.new("Inicio", :root_path, nil, "⌂") ] }
    ] },
    { id: :etiquetas, nombre: "Etiquetas", grupos: [
      { nombre: "Etiquetar", botones: [
        Boton.new("Etiquetar", :new_etiqueta_path, "etiquetas.crear", "🏷"),
        Boton.new("Vivas", :etiquetas_path, "etiquetas.crear", "▦")
      ] }
    ] },
    { id: :inventario, nombre: "Inventario", grupos: [
      { nombre: "Consultar", botones: [
        Boton.new("Existencias", :inventario_path, "inventario.ver", "≡"),
        Boton.new("Kardex", :kardex_inventario_path, "inventario.ver", "⇅")
      ] },
      { nombre: "Capturar", botones: [
        Boton.new("Entrada / ajuste", :nuevo_movimiento_inventario_path, "inventario.ajustar", "✎")
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
