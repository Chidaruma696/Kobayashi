# Conteo físico: el supervisor escanea todo lo que hay (o teclea lo que no lleva etiqueta), el
# sistema compara contra la existencia y, al cerrar, el conteo manda: se ajusta el inventario,
# las etiquetas que no aparecieron mueren y el faltante se le carga al responsable.
class Conteo < ApplicationRecord
  belongs_to :sucursal
  belongs_to :usuario
  belongs_to :responsable, class_name: "Usuario"
  has_many :lineas, class_name: "ConteoLinea", dependent: :destroy, inverse_of: :conteo
  has_many :conteo_etiquetas, dependent: :destroy
  has_many :cargos, dependent: :restrict_with_error

  before_validation :asignar_folio, on: :create

  validates :folio, presence: true, uniqueness: { scope: :sucursal_id }
  validates :estado, inclusion: { in: %w[abierto cerrado] }
  validates :alcance, inclusion: { in: %w[total parcial] }

  scope :abiertos, -> { where(estado: "abierto") }
  scope :cerrados, -> { where(estado: "cerrado") }

  def abierto? = estado == "abierto"
  def parcial? = alcance == "parcial"

  # Total: todo lo que hay en la sucursal. Parcial: solo `productos` (una lista o toda una línea),
  # con existencia o sin ella, para poder contar sobrantes; lo demás no se toca al cerrar.
  def self.abrir!(sucursal:, usuario:, responsable:, productos: nil)
    raise ArgumentError, I18n.t("errores.conteo.ya_abierto", sucursal: sucursal.nombre) if abiertos.exists?(sucursal: sucursal)
    raise ArgumentError, I18n.t("errores.conteo.parcial_vacio") if productos && productos.empty?
    transaction do
      c = create!(sucursal: sucursal, usuario: usuario, responsable: responsable, alcance: productos ? "parcial" : "total")
      if productos
        productos.each { |p| c.lineas.create!(producto: p, sistema: Existencia.de(sucursal, p)) }
      else
        Existencia.where(sucursal: sucursal).where("cantidad > 0").includes(:producto).each do |e|
          c.lineas.create!(producto: e.producto, sistema: e.cantidad)
        end
      end
      c
    end
  end

  # ¿Toca contar? Cuando la sucursal cuenta cada N días y el último cerrado es más viejo (o no hay).
  def self.vencido?(sucursal)
    return false unless sucursal.dias_conteo
    ultimo = cerrados.where(sucursal: sucursal).maximum(:cerrado_en)
    ultimo.nil? || ultimo < sucursal.dias_conteo.days.ago
  end

  def linea_de(producto)
    if parcial?
      lineas.find_by(producto: producto) or raise ArgumentError, I18n.t("errores.conteo.fuera_de_alcance", producto: producto.nombre)
    else
      lineas.find_or_create_by!(producto: producto) { |l| l.sistema = Existencia.de(sucursal, producto) }
    end
  end

  # Escanear una etiqueta: se cuentan sus hojas vivas, cada una una sola vez.
  def escanear!(etiqueta)
    raise ArgumentError, I18n.t("errores.conteo.cerrado") unless abierto?
    raise ArgumentError, I18n.t("errores.caja.etiqueta_no_viva", codigo: etiqueta.codigo, estado: I18n.t("estados.#{etiqueta.estado}")) unless etiqueta.viva?
    raise ArgumentError, I18n.t("errores.caja.etiqueta_otra_sucursal", codigo: etiqueta.codigo) unless etiqueta.sucursal_id == sucursal_id
    raise ArgumentError, I18n.t("errores.conteo.en_transito", codigo: etiqueta.codigo) if etiqueta.en_transito?
    nuevas = 0
    transaction do
      etiqueta.hojas_vivas.each { |h| linea_de(h.producto) } if parcial?
      etiqueta.hojas_vivas.each do |h|
        next if conteo_etiquetas.exists?(etiqueta: h)
        conteo_etiquetas.create!(etiqueta: h)
        linea_de(h.producto).increment!(:escaneado, h.cantidad)
        nuevas += 1
      end
    end
    raise ArgumentError, I18n.t("errores.conteo.ya_contada", codigo: etiqueta.codigo) if nuevas.zero?
    nuevas
  end

  # Lo que no lleva etiqueta se teclea; sustituye el valor anterior, no lo suma.
  def contar_manual!(producto, cantidad)
    raise ArgumentError, I18n.t("errores.conteo.cerrado") unless abierto?
    cantidad = BigDecimal(cantidad.to_s).round(3)
    raise ArgumentError, I18n.t("errores.conteo.cantidad_invalida") if cantidad.negative?
    linea_de(producto).update!(manual: cantidad)
  end

  # Etiquetas vivas de la sucursal que nadie escaneó: son las que faltan, con su barcode exacto.
  def etiquetas_no_vistas
    vivas = Etiqueta.vivas.hojas.where(sucursal: sucursal).where.not(id: conteo_etiquetas.select(:etiqueta_id)).includes(:producto)
    parcial? ? vivas.where(producto_id: lineas.select(:producto_id)) : vivas
  end

  def cerrar!(usuario:)
    raise ArgumentError, I18n.t("errores.conteo.ya_cerrado") unless abierto?
    faltante = 0
    sobrante = 0
    detalle = []
    transaction do
      # Lo que tenía etiqueta y no apareció, muere aquí (y su producto queda fuera del sistema).
      etiquetas_no_vistas.each do |e|
        e.update!(estado: "baja", motivo: I18n.t("conteos.avisos.no_aparecio", folio: folio), padre_id: nil)
      end
      lineas.includes(:producto).each do |l|
        sistema = Existencia.de(sucursal, l.producto)
        contado = l.escaneado + l.manual
        diferencia = contado - sistema
        centavos = Dinero.importe(diferencia.abs, l.producto.precio_centavos_en(sucursal))
        l.update!(sistema: sistema, diferencia: diferencia, diferencia_centavos: diferencia.negative? ? -centavos : centavos)
        next if diferencia.zero?
        Inventario.mover!(sucursal: sucursal, producto: l.producto, tipo: diferencia.negative? ? "ajuste_salida" : "ajuste_entrada",
                          cantidad: diferencia.abs, usuario: usuario, referencia: self, motivo: "Conteo #{folio}")
        if diferencia.negative?
          faltante += centavos
          detalle << "#{l.producto.nombre}: faltan #{diferencia.abs.to_s('F')} #{l.producto.unidad} (#{Dinero.pesos(centavos)})"
        else
          sobrante += centavos
        end
      end
      update!(estado: "cerrado", cerrado_en: Time.current, faltante_centavos: faltante, sobrante_centavos: sobrante)
      cargos.create!(usuario: responsable, sucursal: sucursal, monto_centavos: faltante, detalle: detalle.join("\n")) if faltante.positive?
    end
    self
  end

  def to_s
    folio
  end

  private

  def asignar_folio
    self.folio ||= Folio.siguiente!(sucursal, "conteo") if sucursal
  end
end
