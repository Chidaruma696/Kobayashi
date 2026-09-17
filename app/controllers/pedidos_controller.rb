class PedidosController < ApplicationController
  pestana :pedidos

  def index
    autorizar!("pedidos.surtir")
    @abiertos = Pedido.where(sucursal_origen: sucursal_actual).abiertos.includes(:sucursal_destino, :usuario, lineas: %i[producto etiquetas]).order(:created_at)
    @recientes = Pedido.where(sucursal_origen: sucursal_actual).where.not(estado: %w[solicitado surtiendo]).includes(:sucursal_destino).recientes.limit(20)
  end

  def new
    autorizar!("pedidos.solicitar")
    @pedido = Pedido.new(sucursal_destino: sucursal_actual)
    @pedido.lineas.build
    @destinos = sucursal_actual.matriz? ? Sucursal.activas.where.not(id: sucursal_actual.id).order(:nombre) : [ sucursal_actual ]
  end

  def create
    autorizar!("pedidos.solicitar")
    destino = sucursal_actual.matriz? ? Sucursal.find(params[:pedido][:sucursal_destino_id]) : sucursal_actual
    @pedido = Pedido.new(sucursal_origen: Sucursal.matriz, sucursal_destino: destino, usuario: usuario_actual,
                         notas: params[:pedido][:notas], lineas_attributes: params[:pedido][:lineas_attributes].to_unsafe_h.values.map { |l| l.slice("producto_id", "cantidad") })
    if @pedido.save
      redirect_to pedido_path(@pedido), notice: "Pedido #{@pedido.folio} enviado a #{@pedido.sucursal_origen}"
    else
      @destinos = sucursal_actual.matriz? ? Sucursal.activas.where.not(id: sucursal_actual.id).order(:nombre) : [ sucursal_actual ]
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

  def cancelar
    autorizar!("pedidos.solicitar")
    pedido = Pedido.find(params[:id])
    pedido.cancelar!
    redirect_to pedido_path(pedido), notice: "Pedido cancelado"
  rescue ArgumentError => e
    redirect_to pedido_path(params[:id]), alert: e.message
  end
end
