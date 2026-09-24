module ApplicationHelper
  def pesos(centavos)
    Dinero.pesos(centavos)
  end

  def cantidad(valor, producto)
    "#{number_with_precision(valor, precision: producto.decimales)} #{producto.unidad}"
  end

  # Color estable por destino, para no confundir pedidos de dos tiendas cuando se surten a la vez.
  def color_destino(nombre)
    h = nombre.to_s.upcase.each_char.reduce(0) { |acc, c| (acc * 31 + c.ord) % 360 }
    "hsl(#{h}, 65%, 38%)"
  end
end
