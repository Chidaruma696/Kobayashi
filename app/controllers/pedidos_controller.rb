class PedidosController < ApplicationController
  pestana :pedidos

  def index
    autorizar!("pedidos.surtir")
    @abiertos = Pedido.where(sucursal_origen: sucursal_actual).abiertos.includes(:sucursal_destino, :cliente, :usuario, lineas: %i[producto etiquetas]).order(:created_at)
    @recientes = Pedido.where(sucursal_origen: sucursal_actual).where.not(estado: %w[solicitado surtiendo]).includes(:sucursal_destino, :cliente).recientes.limit(20)
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
      redirect_to pedido_path(@pedido), notice: "Pedido #{@pedido.folio} enviado a #{@pedido.sucursal_origen}"
    else
      cargar_destinos
      flash.now[:alert] = @pedido.errors.full_messages.join(", ")
      render :new, status: :unprocessable_entity
    end
  end

  def show
    @pedido = Pedido.includes(lineas: :producto).find(params[:id])
    raise SinPermiso, "pedidos.surtir" unless [ @pedido.sucursal_origen_id, @pedido.sucursal_destino_id ].include?(sucursal_actual.id) || puede?("admin.usuarios")
    @surtidor = @pedido.sucursal_origen_id == sucursal_actual.id && puede?("pedidos.surtir")
    @producciones = @pedido.producciones.abiertas
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
end
