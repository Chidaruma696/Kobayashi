class SalidasController < ApplicationController
  pestana :salidas

  before_action :cargar_salida, except: %i[index new create por_recibir]

  def index
    autorizar!("salidas.surtir")
    @salidas = Salida.where(sucursal_origen: sucursal_actual).where.not(estado: %w[recibida cancelada]).includes(:sucursal_destino, :usuario).order(:created_at)
    @historial = Salida.where(sucursal_origen: sucursal_actual).where(estado: %w[recibida cancelada]).includes(:sucursal_destino).order(created_at: :desc).limit(15)
  end

  def por_recibir
    autorizar!("salidas.recibir")
    @salidas = Salida.where(sucursal_destino: sucursal_actual).en_transito.includes(:sucursal_origen, :usuario).order(:enviado_en)
    @recibidas = Salida.where(sucursal_destino: sucursal_actual).where(estado: "recibida").includes(:sucursal_origen).order(recibido_en: :desc).limit(15)
  end

  def new
    autorizar!("salidas.surtir")
    @destinos = Sucursal.activas.where.not(id: sucursal_actual.id).order(:nombre)
    @pedido = Pedido.abiertos.find_by(id: params[:pedido_id], sucursal_origen: sucursal_actual)
  end

  def create
    autorizar!("salidas.surtir")
    salida = Salida.nueva!(origen: sucursal_actual, destino: Sucursal.find(params[:sucursal_destino_id]), usuario: usuario_actual, motivo: params[:motivo].presence)
    redirect_to salida_path(salida), notice: "Salida #{salida.folio} abierta: escanea lo que va"
  rescue ActiveRecord::RecordInvalid => e
    redirect_to new_salida_path, alert: e.record.errors.full_messages.join(", ")
  end

  def show
    @filas = @salida.salida_etiquetas.includes(:verificado_por, etiqueta: :producto, grupo: :producto).order(:grupo_id, :id)
    @grupos = @filas.group_by(&:grupo)
    @pedidos = Pedido.abiertos.where(sucursal_origen: @salida.sucursal_origen, sucursal_destino: @salida.sucursal_destino).includes(lineas: :producto) if @salida.preparando? && !@salida.devolucion?
    @recibiendo = @salida.enviada? && @salida.sucursal_destino_id == sucursal_actual.id
  end

  # --- surtir
  def agregar
    autorizar!("salidas.surtir")
    con_etiqueta { |e| n = @salida.agregar!(e); "#{e.tipo} #{e.codigo} agregada (#{n} paquetes)" }
  end

  def quitar
    autorizar!("salidas.surtir")
    con_etiqueta { |e| n = @salida.quitar!(e); "#{n} paquetes fuera de la salida" }
  end

  def manual
    autorizar!("salidas.surtir")
    autoriza = autorizador("etiquetas.libre", params[:pin]) or raise ArgumentError, "un renglón sin etiqueta necesita el PIN de quien lo autorice"
    @salida.agregar_manual!(producto: Producto.activos.find(params[:producto_id]), cantidad: params[:cantidad], motivo: params[:motivo].to_s.strip, autorizado_por: autoriza)
    redirect_to salida_path(@salida), notice: "Renglón manual agregado"
  rescue ArgumentError, ActiveRecord::RecordInvalid => e
    redirect_to salida_path(@salida), alert: e.message
  end

  # --- verificar y sellar
  def verificar
    autorizar!("salidas.verificar")
    con_etiqueta { |e| @salida.verificar!(e, usuario: usuario_actual); "#{e.codigo} verificada" }
  end

  def sellar
    autorizar!("salidas.verificar")
    @salida.sellar!(usuario: usuario_actual)
    redirect_to salida_path(@salida), notice: "Salida #{@salida.folio} sellada por #{usuario_actual}"
  rescue ArgumentError => e
    redirect_to salida_path(@salida), alert: e.message
  end

  def enviar
    autorizar!("salidas.surtir")
    @salida.enviar!(usuario: usuario_actual)
    redirect_to salidas_path, notice: "Salida #{@salida.folio} enviada a #{@salida.sucursal_destino}"
  rescue ArgumentError, Inventario::SinExistencia => e
    redirect_to salida_path(@salida), alert: e.message
  end

  def cancelar
    autorizar!("salidas.surtir")
    @salida.cancelar!
    redirect_to salidas_path, notice: "Salida #{@salida.folio} cancelada"
  rescue ArgumentError => e
    redirect_to salida_path(@salida), alert: e.message
  end

  # --- recibir
  def recibir_etiqueta
    autorizar!("salidas.recibir")
    con_etiqueta { |e| n = @salida.recibir!(e, usuario: usuario_actual); "#{n} paquetes recibidos" }
  end

  def reportar
    autorizar!("salidas.recibir")
    con_etiqueta { |e| n = @salida.reportar!(e, motivo: params[:motivo].to_s.strip, usuario: usuario_actual); "#{n} paquetes reportados como faltantes" }
  end

  def cerrar_recepcion
    autorizar!("salidas.recibir")
    @salida.cerrar_recepcion!(usuario: usuario_actual, motivo_pendientes: params[:motivo].presence)
    redirect_to recibir_salidas_path, notice: "Salida #{@salida.folio} recibida"
  rescue ArgumentError => e
    redirect_to salida_path(@salida), alert: e.message
  end

  private

  def cargar_salida
    @salida = Salida.where(sucursal_origen: sucursal_actual).or(Salida.where(sucursal_destino: sucursal_actual)).includes(:sucursal_origen, :sucursal_destino, :usuario).find(params[:id])
  end

  def con_etiqueta
    etiqueta = Etiqueta.buscar(params[:codigo]) or raise ArgumentError, "no se encontró la etiqueta «#{params[:codigo]}»"
    redirect_to salida_path(@salida), notice: yield(etiqueta)
  rescue ArgumentError, Inventario::SinExistencia => e
    redirect_to salida_path(@salida), alert: e.message
  end
end
