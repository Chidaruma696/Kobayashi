# Dinero en centavos enteros; aquí viven las conversiones y el formato.
module Dinero
  def self.centavos(pesos)
    return 0 if pesos.blank?
    (BigDecimal(pesos.to_s) * 100).round.to_i
  end

  def self.pesos(centavos)
    negativo = centavos.to_i.negative?
    entero, dec = centavos.to_i.abs.divmod(100)
    "#{negativo ? '−' : ''}$#{entero.to_s.reverse.scan(/\d{1,3}/).join(',').reverse}.#{dec.to_s.rjust(2, '0')}"
  end

  # Importe de una línea: cantidad × precio unitario, redondeado a centavos.
  def self.importe(cantidad, precio_centavos)
    (BigDecimal(cantidad.to_s) * precio_centavos).round.to_i
  end
end
