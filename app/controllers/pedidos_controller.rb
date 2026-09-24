class PedidosController < ApplicationController
  pestana :pedidos

  def index
    autorizar!("pedidos.surtir")
    @abiertos = Pedido.where(sucursal_origen: sucursal_actual).abiertos.includes(:sucursal_destino, :cliente, :usuario, lineas: %i[producto etiquetas]).order(:created_at)
    @recientes = Pedido.where(sucursal_origen: sucursal_actual).where.not(estado: %w[solicitado surtiendo]).includes(:sucursal_destino, :cliente).recientes.limit(20)
    respond_to do |format|
      format.html
      format.json { render json: { pedidos: @abiertos.map { |p| resumen_json(p) } } }
    end
  end

  def new
    autorizar!("pedidos.solicitar")
    @pedido = Pedido.new(sucursal_destino: sucursal_actual)
    @pedido.lineas.build
    cargar_destinos
  end

  def create
    autorizar!("pedidos.solicitar")
    @pedido = Pedido.new(sucursal_origen: Sucursal.matriz, usuario: usuario_actual, notas: params[:pedido][:notas],
                         lineas_attributes: params[:pedido][:lineas_attributes].to_unsafe_h.values.map { |l| l.slice("producto_id", "cantidad") })
    if sucursal_actual.matriz?
      tipo, id = params[:pedido][:destino].to_s.split(":")
      tipo == "cliente" ? @pedido.cliente = Cliente.activos.find(id) : @pedido.sucursal_destino = Sucursal.find(id)
    else
      @pedido.sucursal_destino = sucursal_actual
    end
    if @pedido.save
      volver = params[:volver].to_s
      redirect_to (volver.start_with?("/") ? volver : pedido_path(@pedido)), notice: "Pedido #{@pedido.folio} enviado a #{@pedido.sucursal_origen}"
    else
      cargar_destinos
      flash.now[:alert] = @pedido.errors.full_messages.join(", ")
      render :new, status: :unprocessable_entity
    end
  end

  # La ficha del pedido (HTML) o el checklist que usa la etiquetadora (JSON).
  def show
    @pedido = Pedido.includes(lineas: :producto).find(params[:id])
    raise SinPermiso, "pedidos.surtir" unless [ @pedido.sucursal_origen_id, @pedido.sucursal_destino_id ].include?(sucursal_actual.id) || puede?("admin.usuarios")
    @surtidor = @pedido.sucursal_origen_id == sucursal_actual.id && puede?("pedidos.surtir")
    @producciones = @pedido.producciones.abiertas
    respond_to do |format|
      format.html
      format.json { render json: checklist_json(@pedido) }
    end
  end

  def cargar_destinos
    @destinos = sucursal_actual.matriz? ? Sucursal.activas.where.not(id: sucursal_actual.id).order(:nombre) : [ sucursal_actual ]
    @clientes = sucursal_actual.matriz? ? Cliente.activos.includes(:ruta).order(:nombre) : []
  end

  def cancelar
    autorizar!("pedidos.solicitar")
    pedido = Pedido.find(params[:id])
    pedido.cancelar!
    redirect_to pedido_path(pedido), notice: "Pedido cancelado"
  rescue ArgumentError => e
    redirect_to pedido_path(params[:id]), alert: e.message
  end

  private

  def resumen_json(p)
    { id: p.id, folio: p.folio, destino: p.destino.to_s, estado: p.estado, notas: p.notas, usuario: p.usuario.to_s,
      creado: helpers.l(p.created_at, format: :short), renglones: p.lineas.size, resueltos: p.lineas.count { |l| !l.pendiente? } }
  end

  # El pedido con sus renglones y, por renglón, los bultos que lo surten (cajas o paquetes sueltos),
  # en qué salida van y si ya los verificó otra persona.
  def checklist_json(p)
    salida = Salida.armandose_para(p)
    { pedido: resumen_json(p).merge(abierto: p.abierto?),
      salida: (salida && { id: salida.id, folio: salida.folio, url: salida_path(salida), paquetes: salida.salida_etiquetas.count, sin_verificar: salida.sin_verificar.count }),
      renglones: p.lineas.includes(:producto).map { |l| linea_json(l) } }
  end

  def linea_json(l)
    d = l.producto.decimales
    hojas = l.etiquetas.where(estado: %w[viva vendida]).hojas.includes(:producto, :padre).order(:id).to_a
    filas = SalidaEtiqueta.where(etiqueta_id: hojas.map(&:id)).includes(:salida).index_by(&:etiqueta_id)
    bultos = hojas.group_by { |h| h.padre&.viva? ? h.padre : nil }.flat_map do |caja, hs|
      caja ? [ bulto_json(l, caja, hs, filas) ] : hs.map { |h| bulto_json(l, h, [ h ], filas) }
    end
    { id: l.id, producto_id: l.producto_id, producto: l.producto.nombre, unidad: l.producto.unidad,
      cantidad: helpers.number_with_precision(l.cantidad, precision: d), surtida: helpers.number_with_precision(l.cantidad_surtida, precision: d),
      pct: (l.cantidad.positive? ? [ (l.cantidad_surtida / l.cantidad * 100).round, 100 ].min : 0),
      estado: l.estado, motivo: l.motivo, bultos: bultos }
  end

  def bulto_json(linea, etiqueta, hojas, filas)
    fs = hojas.filter_map { |h| filas[h.id] }
    salida = fs.first&.salida
    sustituto = hojas.any? { |h| h.producto_id != linea.producto_id }
    { id: etiqueta.id, codigo: etiqueta.codigo, tipo: etiqueta.tipo, paquetes: (etiqueta.caja? && hojas.first != etiqueta ? hojas.size : nil),
      cantidad: helpers.number_with_precision(hojas.sum(&:cantidad), precision: linea.producto.decimales),
      sustituto: (hojas.first.producto.nombre if sustituto),
      salida: (salida && { folio: salida.folio, estado: salida.estado, url: salida_path(salida) }),
      verificada: fs.any? && fs.all?(&:verificada?) }
  end
end
