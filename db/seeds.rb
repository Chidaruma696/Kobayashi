# Datos mínimos para arrancar: sucursales, roles y un administrador. Idempotente.
matriz = Sucursal.find_or_create_by!(codigo: "MTZ") { |s| s.nombre = "Matriz"; s.tipo = "matriz" }
Sucursal.find_or_create_by!(codigo: "T01") { |s| s.nombre = "Tienda 1"; s.tipo = "tienda" }

roles = {
  "administrador" => [ "*" ],
  "cajero" => [ "caja.vender", "caja.abrir", "caja.retirar", "caja.devolver", "inventario.ver", "pedidos.solicitar", "salidas.recibir", "salidas.surtir", "salidas.verificar" ],
  "etiquetador" => [ "etiquetas.crear", "produccion.abrir", "pedidos.surtir", "inventario.ver", "salidas.surtir", "salidas.recibir" ],
  "chofer" => [ "rutas.repartir", "pedidos.solicitar" ],
  "supervisor" => [ "caja.*", "inventario.*", "etiquetas.*", "pedidos.*", "produccion.*", "salidas.*", "rutas.*", "cobranza.*", "canastillas.*", "conteos.*", "reportes.ver", "revisiones.resolver" ]
}
roles.each do |nombre, permisos|
  Rol.find_or_initialize_by(nombre: nombre).update!(permisos: permisos)
end

if Rails.env.development? && !Usuario.exists?(usuario: "admin")
  Usuario.create!(nombre: "Administrador", usuario: "admin", password: "admin1234",
                  rol: Rol.find_by!(nombre: "administrador"), sucursal: matriz)
  puts "Usuario de desarrollo: admin / admin1234"
end

if Rails.env.development? && Producto.none?
  [
    [ "PECH", "Pechuga de pollo", "Pollo", "kg", 129.00 ],
    [ "PIER", "Pierna y muslo", "Pollo", "kg", 89.50 ],
    [ "BIST", "Bistec de res", "Res", "kg", 215.00 ],
    [ "CHOR", "Chorizo", "Embutido", "kg", 98.00 ],
    [ "QUES", "Queso Oaxaca", "Lácteos", "kg", 180.00 ],
    [ "HUEV", "Casillero de huevo", "Huevo", "pieza", 95.00 ],
    [ "CATS", "Cátsup Clemente 1 kg", "Abarrotes", "pieza", 42.00 ]
  ].each do |clave, nombre, linea, unidad, precio|
    Producto.create!(clave: clave, nombre: nombre, linea: linea, unidad: unidad, precio: precio)
  end
  Producto.find_by!(clave: "CATS").codigos_barras.create!(codigo: "7501006559019")
end
