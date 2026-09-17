# Qué es lo que se escaneó: una etiqueta nuestra, un producto del proveedor por su código,
# o un producto por PLU o clave tecleados. Lo usan la caja, la recepción y el conteo.
module Escaneo
  Resultado = Struct.new(:tipo, :etiqueta, :producto, keyword_init: true) do
    def etiqueta? = tipo == :etiqueta
    def producto? = tipo == :producto
  end

  def self.resolver(texto)
    texto = texto.to_s.strip
    return nil if texto.empty?

    if (etiqueta = Etiqueta.buscar(texto))
      return Resultado.new(tipo: :etiqueta, etiqueta: etiqueta, producto: etiqueta.producto)
    end
    if (codigo = CodigoBarras.includes(:producto).find_by(codigo: Barcode.variantes(texto)))
      return Resultado.new(tipo: :producto, producto: codigo.producto)
    end
    digitos = Barcode.digitos(texto)
    if digitos == texto && (producto = Producto.activos.find_by(plu: digitos.to_i))
      return Resultado.new(tipo: :producto, producto: producto)
    end
    if (producto = Producto.activos.find_by(clave: texto.upcase))
      return Resultado.new(tipo: :producto, producto: producto)
    end
    nil
  end
end
