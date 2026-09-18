# Las reglas de crédito de ruta, calculadas en vivo sobre la cuenta del cliente. Si paga, se
# desbloquea solo. Cobranza puede forzar con un bloqueo o desbloqueo manual, y el manual manda.
#
#   contado           crédito jamás
#   nota_x_nota       con cualquier adeudo, bloqueado: paga la anterior para sacar la nueva
#   limite            saldo >= límite, bloqueado (límite 0 = sin tope)
#   semanal           debe algo de antes del corte (su día de corte, o el lunes de esta semana), bloqueado
#   contado_abonando  con saldo y sin abono en los últimos 7 días, bloqueado
#   especial          con día de corte propio, igual que semanal; sin día, solo manual
module Credito
  TIPOS = {
    "contado" => "Contado (sin crédito)",
    "nota_x_nota" => "Nota por nota",
    "limite" => "Límite de crédito",
    "semanal" => "Semanal (paga al corte)",
    "contado_abonando" => "Contado abonando (7 días)",
    "especial" => "Especial (día de corte propio)"
  }.freeze
  DIAS = %w[lunes martes miércoles jueves viernes sábado domingo].freeze

  Estado = Struct.new(:tipo, :saldo_centavos, :bloqueado, :motivo, :regla, :vencido_centavos, :manual, keyword_init: true) do
    def permite_credito? = tipo != "contado" && !bloqueado
  end

  def self.evaluar(cliente, hoy: Date.current)
    movs = cliente.movimientos_credito.en_orden.to_a
    saldo = movs.sum(&:monto_centavos)
    vivos, ultimo_abono = cargos_vivos(movs)
    estado = Estado.new(tipo: cliente.credito, saldo_centavos: saldo, bloqueado: false, motivo: "", regla: "", vencido_centavos: 0, manual: false)
    aplicar_regla(estado, cliente, vivos, ultimo_abono, hoy)
    case cliente.bloqueo_manual
    when "bloqueado"
      estado.bloqueado = true
      estado.manual = true
      estado.motivo = "Bloqueado por cobranza: #{cliente.bloqueo_motivo}"
    when "desbloqueado"
      if estado.bloqueado
        estado.bloqueado = false
        estado.manual = true
        estado.motivo = "Desbloqueado por cobranza: #{cliente.bloqueo_motivo}"
      end
    end
    estado
  end

  # Antigüedad de saldos: los abonos matan los cargos más viejos (FIFO); lo que sobra de un
  # abono queda a favor y cubre cargos futuros. Devuelve [[fecha, restante]...] y la fecha del último abono.
  def self.cargos_vivos(movs)
    cargos = []
    a_favor = 0
    ultimo_abono = nil
    movs.each do |m|
      monto = m.monto_centavos
      if monto.positive?
        usa = [ a_favor, monto ].min
        a_favor -= usa
        cargos << [ m.fecha, monto - usa ] if monto - usa > 0
      else
        resta = -monto
        ultimo_abono = m.fecha if m.tipo == "abono"
        cargos.each do |c|
          break if resta.zero?
          aplica = [ c[1], resta ].min
          c[1] -= aplica
          resta -= aplica
        end
        a_favor += resta
      end
    end
    [ cargos.select { |c| c[1].positive? }, ultimo_abono ]
  end

  def self.aging(cliente, hoy: Date.current)
    vivos, = cargos_vivos(cliente.movimientos_credito.en_orden.to_a)
    cubetas = { "0-30" => 0, "31-60" => 0, "61-90" => 0, "90+" => 0 }
    vivos.each do |fecha, restante|
      dias = (hoy - fecha).to_i
      clave = dias <= 30 ? "0-30" : dias <= 60 ? "31-60" : dias <= 90 ? "61-90" : "90+"
      cubetas[clave] += restante
    end
    cubetas
  end

  def self.aplicar_regla(e, cliente, vivos, ultimo_abono, hoy)
    saldo = e.saldo_centavos
    case cliente.credito
    when "contado"
      e.regla = "Contado: el crédito no aplica"
    when "nota_x_nota"
      e.regla = "Paga la nota anterior para sacar la nueva"
      bloquear(e, saldo, "debe #{Dinero.pesos(saldo)}: paga la nota anterior") if saldo.positive?
    when "limite"
      lim = cliente.limite_credito_centavos
      e.regla = lim.positive? ? "Límite de crédito #{Dinero.pesos(lim)}" : "Límite sin configurar"
      bloquear(e, saldo, "tope de crédito: debe #{Dinero.pesos(saldo)} de #{Dinero.pesos(lim)}") if lim.positive? && saldo >= lim
    when "semanal", "especial"
      if cliente.credito == "especial" && cliente.dia_corte.nil?
        e.regla = "Especial sin día de corte: solo bloqueo manual"
        return
      end
      corte = fecha_corte(hoy, cliente.dia_corte)
      e.regla = cliente.dia_corte ? "Paga al corte de los #{DIAS[cliente.dia_corte]}" : "Paga su semana (lunes a sábado)"
      vencido = vivos.select { |fecha, _| cliente.dia_corte ? fecha <= corte : fecha < corte }.sum { |_, r| r }
      bloquear(e, vencido, "llegó el corte con #{Dinero.pesos(vencido)} sin pagar") if vencido.positive?
    when "contado_abonando"
      e.regla = "Crédito solo si abona cada 7 días"
      if saldo.positive? && (ultimo_abono.nil? || ultimo_abono < hoy - 7)
        bloquear(e, saldo, "dejó de abonar (#{ultimo_abono ? "último abono #{I18n.l(ultimo_abono)}" : 'sin abonos'}) y debe #{Dinero.pesos(saldo)}")
      end
    end
  end

  def self.bloquear(e, vencido, motivo)
    e.bloqueado = true
    e.vencido_centavos = vencido
    e.motivo = motivo
  end

  # Con día propio: ese día de esta semana (o de la pasada si aún no llega). Sin día: el lunes de esta semana.
  def self.fecha_corte(hoy, dia_corte)
    lunes = hoy - hoy.cwday + 1
    return lunes if dia_corte.nil?
    corte = lunes + dia_corte
    corte > hoy ? corte - 7 : corte
  end
end
