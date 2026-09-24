# Ajustes del sistema, clave/valor, con sus valores de fábrica. Lo que no está guardado vale el
# default; `Ajuste[clave]` devuelve siempre algo.
class Ajuste < ApplicationRecord
  DEFAULTS = {
    "negocio.nombre" => "",              # vacío = el nombre de la sucursal
    "negocio.direccion" => "",
    "negocio.telefono" => "",
    "negocio.pie_ticket" => "¡Gracias por su compra!",
    "etiqueta.ancho" => "55",            # mm
    "etiqueta.alto" => "45",
    "etiqueta.leyenda" => "",
    "etiqueta.barras" => "36",           # alto del código de barras, px
    "etiqueta.letra" => "14",
    "caja.piso_precio" => "50",          # % del catálogo por debajo del cual no se vende ni con permiso
    "caja.limite_gaveta" => "3000",      # pesos, para sucursales nuevas
    "modulos.etiquetas" => "1",          # módulos opcionales: "1" encendido, "0" apagado (ver Modulo)
    "modulos.pedidos" => "1",
    "modulos.salidas" => "1",
    "modulos.rutas" => "1",
    "modulos.conteos" => "1"
  }.freeze
  ENTEROS = %w[etiqueta.ancho etiqueta.alto etiqueta.barras etiqueta.letra caja.piso_precio caja.limite_gaveta].freeze

  validates :clave, presence: true, uniqueness: true, inclusion: { in: DEFAULTS.keys }

  def self.[](clave)
    valor = find_by(clave: clave)&.valor
    valor.presence || DEFAULTS.fetch(clave)
  end

  def self.entero(clave)
    self[clave].to_i
  end

  # Guarda varios de golpe: { "negocio.nombre" => "…" }. Lo vacío vuelve al default.
  def self.guardar!(valores)
    transaction do
      valores.each do |clave, valor|
        next unless DEFAULTS.key?(clave)
        valor = valor.to_s.strip
        raise ArgumentError, I18n.t("errores.ajuste.entero", clave: clave) if ENTEROS.include?(clave) && valor.present? && valor !~ /\A\d+\z/
        registro = find_or_initialize_by(clave: clave)
        valor.blank? ? registro.destroy : registro.update!(valor: valor)
      end
    end
  end

  def self.todos
    DEFAULTS.keys.index_with { |k| self[k] }
  end
end
