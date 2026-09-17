class CajaController < ApplicationController
  pestana :caja

  before_action :cargar_corte

  # ---- vender
  def index
    autorizar!("caja.vender")
    @clave = SecureRandom.uuid
  end

  # Qué es lo que se escaneó o tecleó, para el ticket (JSON).
  def escanear
    autorizar!("caja.vender")
    r = Escaneo.resolver(params[:codigo])
    return render json: { error: "No se encontró «#{params[:codigo]}»" }, status: :not_found unless r
    if r.etiqueta?
      e = r.etiqueta
      return render json: { error: "La etiqueta #{e.codigo} está #{e.estado}" }, status: :unprocessable_entity unless e.viva?
      return render json: { error: "La etiqueta #{e.codigo} es de otra sucursal" }, status: :unprocessable_entity unless e.sucursal_id == sucursal_actual.id
      return render json: { error: "Es una #{e.tipo}: escanea los paquetes" }, status: :unprocessable_entity unless e.paquete? || (e.caja? && e.producto)
    end
    p = r.producto
    render json: { etiqueta_id: r.etiqueta&.id, codigo: r.etiqueta&.codigo, producto_id: p.id, nombre: p.nombre, unidad: p.unidad,
                   decimales: p.decimales, cantidad: r.etiqueta&.cantidad, precio_centavos: p.precio_centavos_en(sucursal_actual) }
  end

  def cobrar
    autorizar!("caja.vender")
    lineas = JSON.parse(params[:lineas].to_s).map { |l| l.symbolize_keys.slice(:etiqueta_id, :producto_id, :cantidad, :precio_centavos) }
    pagos = JSON.parse(params[:pagos].to_s).map(&:symbolize_keys)
    venta = Caja.cobrar!(sucursal: sucursal_actual, usuario: usuario_actual, lineas: lineas, pagos: pagos, clave: params[:clave],
                         autorizador: autorizador("caja.bajar_precio", params[:pin]))
    render json: { url: caja_ticket_path(venta, imprimir: 1), folio: venta.folio, cambio: Dinero.pesos(venta.cambio_centavos) }
  rescue Caja::Error, JSON::ParserError, ActiveRecord::RecordNotFound, ActiveRecord::RecordInvalid => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def ventas
    autorizar!("caja.vender")
    @ventas = Venta.where(sucursal: sucursal_actual).includes(:usuario, :pagos, lineas: :producto).recientes.limit(100)
  end

  def ticket
    autorizar!("caja.vender")
    @venta = Venta.where(sucursal: sucursal_actual).includes(:pagos, :usuario, lineas: %i[producto etiqueta]).find(params[:id])
    render layout: "ticket"
  end

  # ---- corte
  def corte
    autorizar!("caja.abrir")
    @cortes = Corte.where(sucursal: sucursal_actual).where(estado: "cerrado").includes(:usuario).order(cerrado_en: :desc).limit(15)
  end

  def abrir
    autorizar!("caja.abrir")
    Corte.abrir!(sucursal: sucursal_actual, usuario: usuario_actual, fondo_centavos: Dinero.centavos(params[:fondo]))
    redirect_to caja_path, notice: "Caja abierta con fondo de #{Dinero.pesos(Dinero.centavos(params[:fondo]))}"
  rescue ArgumentError, ActiveRecord::RecordInvalid => e
    redirect_to caja_corte_path, alert: e.message
  end

  def cerrar
    autorizar!("caja.abrir")
    raise ArgumentError, "no hay caja abierta" unless @corte
    @corte.cerrar!(contado_centavos: Dinero.centavos(params[:contado]), usuario: usuario_actual)
    redirect_to caja_corte_path, notice: "Corte #{@corte.folio} cerrado: esperado #{Dinero.pesos(@corte.esperado_centavos)}, contado #{Dinero.pesos(@corte.contado_centavos)}, diferencia #{Dinero.pesos(@corte.diferencia_centavos)}"
  rescue ArgumentError => e
    redirect_to caja_corte_path, alert: e.message
  end

  def retirar
    raise ArgumentError, "no hay caja abierta" unless @corte
    autoriza = autorizador("caja.retirar", params[:pin]) or raise ArgumentError, "hace falta el PIN de quien autorice el retiro"
    @corte.retirar!(monto_centavos: Dinero.centavos(params[:monto]), motivo: params[:motivo], usuario: usuario_actual, autorizado_por: autoriza)
    redirect_to caja_corte_path, notice: "Retiro de #{Dinero.pesos(Dinero.centavos(params[:monto]))} registrado"
  rescue ArgumentError, ActiveRecord::RecordInvalid => e
    redirect_to caja_corte_path, alert: e.message
  end

  # ---- devoluciones: solo con ticket o etiqueta
  def devolucion
    autorizar!("caja.devolver")
    return if params[:codigo].blank?
    @venta = Venta.where(sucursal: sucursal_actual).then { |v| v.find_by(codigo: Barcode.variantes(params[:codigo])) || v.find_by(folio: params[:codigo].to_s.strip.upcase) }
    if @venta.nil? && (etiqueta = Etiqueta.buscar(params[:codigo]))
      @venta = Venta.where(sucursal: sucursal_actual).joins(:lineas).find_by(venta_lineas: { etiqueta_id: etiqueta.id })
    end
    flash.now[:alert] = "Sin ticket ni etiqueta no hay devolución: no se encontró «#{params[:codigo]}»" unless @venta
  end

  def devolver
    autorizar!("caja.devolver")
    venta = Venta.where(sucursal: sucursal_actual).find(params[:venta_id])
    lineas = params.fetch(:lineas, {}).to_unsafe_h.map { |id, cant| { venta_linea_id: id, cantidad: cant } }.reject { |l| l[:cantidad].blank? || l[:cantidad].to_d <= 0 }
    dev = Caja.devolver!(venta: venta, lineas: lineas, motivo: params[:motivo].to_s.strip, usuario: usuario_actual)
    redirect_to caja_ventas_path, notice: "Devolución #{dev.folio} de #{Dinero.pesos(dev.total_centavos)} sobre #{venta.folio}"
  rescue Caja::Error, ActiveRecord::RecordInvalid => e
    redirect_to caja_devolucion_path(codigo: params[:codigo]), alert: e.message
  end

  private

  def cargar_corte
    @corte = Corte.abierto_en(sucursal_actual)
  end
end
