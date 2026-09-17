# Los modelos y tablas de Kobayashi están en español: Rails necesita saber cómo se pluralizan.
ActiveSupport::Inflector.inflections(:en) do |inflect|
  inflect.plural(/([lnrd])$/i, '\1es')
  inflect.singular(/([lnrd])es$/i, '\1')
  inflect.irregular "sucursal", "sucursales"
  inflect.irregular "rol", "roles"
  inflect.irregular "sesion", "sesiones"
  inflect.irregular "devolucion", "devoluciones"
  inflect.irregular "recepcion", "recepciones"
  inflect.irregular "linea", "lineas"
  inflect.uncountable %w[codigo_barras codigos_barras]
end
