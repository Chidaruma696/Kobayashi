class ConteosController < ApplicationController
  pestana :conteos
  modulo :conteos

  before_action { autorizar!("conteos.hacer") }
  before_action :cargar_conteo, only: %i[show escanear manual cerrar]

  def index
    @conteos = Conteo.where(sucursal: sucursal_actual).includes(:usuario, :responsable).order(created_at: :desc).limit(30)
  end

  def new
    @abierto = Conteo.abiertos.find_by(sucursal: sucursal_actual)
    @responsables = Usuario.activos.where(sucursal: sucursal_actual).order(:nombre)
  end

  def create
    conteo = Conteo.abrir!(sucursal: sucursal_actual, usuario: usuario_actual, responsable: Usuario.activos.find(params[:responsable_id]))
    redirect_to conteo_path(conteo), notice: t("conteos.avisos.abierto", folio: conteo.folio)
  rescue ArgumentError => e
    redirect_to new_conteo_path, alert: e.message
  end

  def show
    @lineas = @conteo.lineas.includes(:producto).joins(:producto).order("productos.nombre")
    @no_vistas = @conteo.etiquetas_no_vistas.limit(200) if @conteo.abierto?
    @productos = Producto.activos.order(:nombre)
  end

  def escanear
    etiqueta = Etiqueta.buscar(params[:codigo]) or raise ArgumentError, "no se encontró «#{params[:codigo]}»"
    n = @conteo.escanear!(etiqueta)
    redirect_to conteo_path(@conteo), notice: t("conteos.avisos.contados", n: n)
  rescue ArgumentError => e
    redirect_to conteo_path(@conteo), alert: e.message
  end

  def manual
    producto = Producto.activos.find(params[:producto_id])
    @conteo.contar_manual!(producto, params[:cantidad])
    redirect_to conteo_path(@conteo), notice: "#{producto.nombre}: #{params[:cantidad]} contado a mano"
  rescue ArgumentError => e
    redirect_to conteo_path(@conteo), alert: e.message
  end

  def cerrar
    @conteo.cerrar!(usuario: usuario_actual)
    aviso = "Conteo #{@conteo.folio} cerrado: faltante #{Dinero.pesos(@conteo.faltante_centavos)}, sobrante #{Dinero.pesos(@conteo.sobrante_centavos)}"
    aviso += " · cargo a #{@conteo.responsable}" if @conteo.faltante_centavos.positive?
    redirect_to conteo_path(@conteo), notice: aviso
  rescue ArgumentError, Inventario::SinExistencia => e
    redirect_to conteo_path(@conteo), alert: e.message
  end

  private

  def cargar_conteo
    @conteo = Conteo.where(sucursal: sucursal_actual).find(params[:id])
  end
end
