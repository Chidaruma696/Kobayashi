module ApplicationHelper
  def pesos(centavos)
    Dinero.pesos(centavos)
  end

  def cantidad(valor, producto)
    "#{number_with_precision(valor, precision: producto.decimales)} #{producto.unidad}"
  end
end
