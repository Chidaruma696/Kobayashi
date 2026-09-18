class EtiquetasController < ApplicationController
  pestana :etiquetas

  before_action { autorizar!("etiquetas.crear") }

  def index
    vivas = Etiqueta.vivas.sueltas.where(sucursal: sucursal_actual).includes(:producto).recientes
    @paquetes = vivas.where(tipo: "paquete")
    @cajas = vivas.where(tipo: "caja")
    @tarimas = vivas.where(tipo: "tarima")
  end

  # La etiquetadora: producto, lista de pesadas (o piezas), báscula, y Registrar e imprimir.
  def new
    cargar_contexto
    producto = @linea&.producto || Producto.activos.find_by(id: params[:producto_id])
    @producto_json = producto && producto_json(producto)
    @pendientes = PedidoLinea.joins(:pedido).where(pedidos: { sucursal_origen_id: sucursal_actual.id, estado: %w[solicitado surtiendo] }, estado: "pendiente")
                             .includes(:producto, pedido: %i[sucursal_destino cliente]).order("pedidos.created_at")
  end

  # Alta de una etiqueta suelta desde un formulario normal (lo usa también la caja de la ficha).
  def create
    cargar_contexto
    producto = Producto.activos.find(params[:producto_id])
    tipo = params[:tipo] == "caja" ? "caja" : "paquete"
    linea, autoriza = resolver_contexto(producto)
    @etiqueta = Etiqueta.create!(tipo: tipo, producto: producto, cantidad: params[:cantidad], sucursal: sucursal_actual,
                                 usuario: usuario_actual, pedido_linea: linea, produccion: @produccion,
                                 autorizado_por: autoriza, justificacion: params[:justificacion].presence)
    dejar_por_revisar([ @etiqueta ], linea, autoriza)
    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to new_etiqueta_path(contexto_params.merge(producto_id: producto.id)), notice: "Etiqueta #{@etiqueta.codigo} creada" }
    end
  rescue ActiveRecord::RecordInvalid, ArgumentError => e
    mensaje = e.respond_to?(:record) ? e.record.errors.full_messages.join(", ") : e.message
    respond_to do |format|
      format.turbo_stream { render turbo_stream: turbo_stream.update("aviso", partial: "aviso", locals: { texto: mensaje }), status: :unprocessable_entity }
      format.html { redirect_to new_etiqueta_path(contexto_params.merge(producto_id: params[:producto_id])), alert: mensaje }
    end
  end

  # Registra de golpe lo que armó la etiquetadora (JSON):
  #   pesadas: [{ cantidad: "1.250" } | { id: 12 }]   paquetes nuevos, o ya registrados (impresión al instante)
  #   caja: "1"                                        agrupa todos los paquetes en una caja
  #   caja_fija: "12"                                  caja de proveedor de N piezas, sin paquetes (modo D)
  # Devuelve las etiquetas con su código definitivo y el SVG del barcode.
  def lote
    cargar_contexto
    producto = Producto.activos.find(params[:producto_id])
    linea, autoriza = resolver_contexto(producto)
    base = { producto: producto, sucursal: sucursal_actual, usuario: usuario_actual, pedido_linea: linea, produccion: @produccion,
             autorizado_por: autoriza, justificacion: params[:justificacion].presence }
    paquetes = []
    caja = nil
    Etiqueta.transaction do
      Array(params[:pesadas]).each do |p|
        p = p.respond_to?(:to_unsafe_h) ? p.to_unsafe_h : p.to_h
        paquetes << if p["id"].present?
          Etiqueta.vivas.where(sucursal: sucursal_actual, tipo: "paquete", padre_id: nil).find(p["id"])
        else
          Etiqueta.create!(base.merge(tipo: "paquete", cantidad: p["cantidad"]))
        end
      end
      if params[:caja_fija].present?
        caja = Etiqueta.create!(base.merge(tipo: "caja", cantidad: params[:caja_fija]))
      elsif params[:caja].present? && paquetes.any?
        caja = Etiqueta.cerrar_caja!(paquetes, usuario: usuario_actual)
      end
      dejar_por_revisar(paquetes.select(&:previously_new_record?) + [ caja ].compact.select(&:previously_new_record?).reject(&:agrupando), linea, autoriza)
    end
    render json: { etiquetas: paquetes.map { |e| etiqueta_json(e) }, caja: (etiqueta_json(caja) if caja),
                   lleva: lleva_de(linea, @produccion, producto) }
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotFound, ArgumentError => e
    mensaje = e.respond_to?(:record) ? e.record.errors.full_messages.join(", ") : e.message
    render json: { error: mensaje }, status: :unprocessable_entity
  end

  # Buscador de la etiquetadora: nombre, clave, PLU o código de proveedor (JSON).
  def productos
    q = params[:q].to_s.strip
    productos = Producto.activos.includes(:codigos_barras).order(:nombre)
    if q.present?
      escaneado = Escaneo.resolver(q)
      productos = if escaneado&.producto? && escaneado.producto.activo
        Producto.where(id: escaneado.producto.id).includes(:codigos_barras)
      else
        productos.where("LOWER(nombre) LIKE :q OR LOWER(clave) LIKE :q OR CAST(plu AS TEXT) LIKE :q", q: "%#{q.downcase}%")
      end
    end
    render json: productos.limit(30).map { |p| producto_json(p) }
  end

  # Para el lector: qué etiqueta de esta sucursal es este código (JSON).
  def buscar
    etiqueta = Etiqueta.buscar(params[:codigo])
    if etiqueta && etiqueta.sucursal_id == sucursal_actual.id
      render json: { id: etiqueta.id, codigo: etiqueta.codigo, tipo: etiqueta.tipo, estado: etiqueta.estado,
                     producto: etiqueta.producto&.nombre, cantidad: etiqueta.cantidad }
    else
      head :not_found
    end
  end

  def show
    @etiqueta = Etiqueta.find(params[:id])
    @etiquetas = [ @etiqueta ]
    configurar_impresion
    render layout: "etiqueta"
  end

  # Varias etiquetas de una vez (ids=1,2,3), o N copias de un código de proveedor (codigo=…&n=…&nombre=…).
  def imprimir
    configurar_impresion
    if params[:codigo].present?
      n = params[:n].to_i.clamp(1, 500)
      @sueltas = Array.new(n) { { codigo: CodigoBarras.normalizar(params[:codigo]), nombre: params[:nombre].to_s, cantidad: params[:cantidad].to_s } }
      @etiquetas = []
    else
      ids = params[:ids].to_s.split(",").map(&:to_i)
      @etiquetas = Etiqueta.where(sucursal: sucursal_actual, id: ids).includes(:producto).index_by(&:id).values_at(*ids).compact
      @sueltas = []
    end
    render layout: "etiqueta"
  end

  def cerrar_caja
    agrupar { |hijas| Etiqueta.cerrar_caja!(hijas, usuario: usuario_actual) }
  end

  def armar_tarima
    agrupar { |hijas| Etiqueta.armar_tarima!(hijas, usuario: usuario_actual) }
  end

  def baja
    etiqueta = Etiqueta.where(sucursal: sucursal_actual).find(params[:id])
    etiqueta.dar_de_baja!(motivo: params[:motivo].to_s.strip, usuario: usuario_actual)
    redirect_to etiquetas_path, notice: "#{etiqueta} dada de baja"
  rescue ArgumentError => e
    redirect_to etiquetas_path, alert: e.message
  end

  private

  # Renglón de pedido o producción abierta de esta sucursal desde los que se etiqueta.
  def cargar_contexto
    @linea = PedidoLinea.joins(:pedido).where(pedidos: { sucursal_origen_id: sucursal_actual.id, estado: %w[solicitado surtiendo] })
                        .includes(:producto, :pedido).find_by(id: params[:pedido_linea_id])
    @produccion = Produccion.abiertas.where(sucursal: sucursal_actual).includes(:producto, :pedido).find_by(id: params[:produccion_id])
  end

  # [renglón, autorizador]: el renglón del pedido que corresponde a este producto, o quien autoriza
  # etiquetar sin pedido ni producción. Cambiar de producto dentro de un pedido cae en su renglón.
  def resolver_contexto(producto)
    linea = @linea
    linea = @linea.pedido.linea_de(producto) if @linea && @linea.producto_id != producto.id
    linea ||= @produccion&.pedido&.linea_de(producto)
    raise ArgumentError, "#{producto.nombre} no está en el pedido #{@linea.pedido.folio}" if @linea && linea.nil?
    return [ linea, nil ] if linea || @produccion
    raise ArgumentError, "sin pedido ni producción escribe el motivo (con PIN de quien autoriza, o queda por revisar)" if params[:justificacion].blank?
    [ nil, autorizador_o_revision("etiquetas.libre", params[:pin]) ]
  end

  # Etiquetas sueltas sin nadie que las autorizara: a la bandeja de revisión, cada una con lo que vale.
  def dejar_por_revisar(etiquetas, linea, autoriza)
    return if linea || @produccion || autoriza
    etiquetas.each do |e|
      revisar_si_hace_falta(e, nil, motivo: params[:justificacion], valor_centavos: Revision.valor(e.cantidad, e.producto, sucursal_actual))
    end
  end

  def contexto_params
    { pedido_linea_id: @linea&.id, produccion_id: @produccion&.id }.compact
  end

  def lleva_de(linea, produccion, producto)
    if linea
      helpers.number_with_precision(linea.reload.cantidad_surtida, precision: producto.decimales)
    elsif produccion
      helpers.number_with_precision(produccion.reload.disponible, precision: 3)
    end
  end

  def etiqueta_json(e)
    { id: e.id, codigo: e.codigo, tipo: e.tipo, cantidad: e.cantidad.to_s("F"), nombre: e.producto&.nombre,
      unidad: e.producto&.unidad, svg: helpers.ean13_svg(e.codigo, alto: 36, modulo: 2) }
  end

  def producto_json(p)
    { id: p.id, nombre: p.nombre, clave: p.clave, plu: p.plu, unidad: p.unidad, decimales: p.decimales,
      peso_fijo: p.peso_fijo&.to_s("F"), codigos: p.codigos_barras.map(&:codigo) }
  end

  # Tamaño y textos de la etiqueta impresa; vienen del navegador (ajustes guardados) o valen los de fábrica.
  def configurar_impresion
    @ancho = params[:ancho].present? ? params[:ancho].to_i.clamp(20, 200) : 55
    @alto = params[:alto].present? ? params[:alto].to_i.clamp(15, 200) : 45
    @leyenda = params[:leyenda].to_s
    @alto_barras = params[:bc].present? ? params[:bc].to_i.clamp(20, 200) : 36
    @letra_nombre = params[:fn].present? ? params[:fn].to_i.clamp(8, 36) : 14
  end

  def agrupar
    hijas = Etiqueta.where(sucursal: sucursal_actual, id: Array(params[:ids])).to_a
    grupo = yield(hijas)
    redirect_to etiqueta_path(grupo), notice: "#{grupo.tipo.capitalize} #{grupo.codigo} creada con #{hijas.size} etiquetas"
  rescue ArgumentError => e
    redirect_to etiquetas_path, alert: e.message
  end
end
