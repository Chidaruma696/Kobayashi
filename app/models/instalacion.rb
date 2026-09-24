# Primer arranque: con la base vacía se crean los roles base, la matriz, el nombre del negocio y
# el administrador, todo en una transacción. Devuelve el administrador ya creado.
module Instalacion
  def self.instalar!(negocio:, sucursal:, codigo:, nombre:, usuario:, password:, idioma:)
    ActiveRecord::Base.transaction do
      Rol.base!
      matriz = Sucursal.find_or_create_by!(codigo: codigo.to_s.strip.upcase.presence || "MTZ") do |s|
        s.nombre = sucursal.to_s.strip.presence || "Matriz"
        s.tipo = "matriz"
      end
      Ajuste.guardar!("negocio.nombre" => negocio) if negocio.present?
      Usuario.create!(nombre: nombre, usuario: usuario.to_s.strip.downcase, password: password,
                      rol: Rol.find_by!(nombre: "administrador"), sucursal: matriz,
                      idioma: idioma.to_s.presence_in(Usuario::IDIOMAS) || "en")
    end
  end
end
