# Supervisión: revisar la tienda sin ajustar nada. Una abierta por sucursal, que se acumula días.
class SupervisionesController < ApplicationController
  pestana :conteos
  modulo :conteos

  before_action { autorizar!("conteos.hacer") }
  before_action :cargar_supervision, only: %i[show escanear pesar cerrar]

  def index
    @abierta = Supervision.abiertas.find_by(sucursal: sucursal_actual)
    @cerradas = Supervision.where(sucursal: sucursal_actual, estado: "cerrada").includes(:usuario).order(cerrado_en: :desc).limit(20)
  end

  def create
    s = Supervision.abrir!(sucursal: sucursal_actual, usuario: usuario_actual)
    redirect_to supervision_path(s)
  end

  def show
    @vistas = @supervision.vistas.con_pareja.includes(:usuario, etiqueta: :producto).order(created_at: :desc).limit(50)
    @sin_pareja = @supervision.sin_pareja.includes(:usuario).limit(50)
    @no_vistas = @supervision.no_vistas.limit(300)
    @productos = Producto.activos.where(unidad: "kg").order(:nombre)
    @total_vivas = Etiqueta.vivas.hojas.where(sucursal: sucursal_actual).count
  end

  def escanear
    etiqueta = Etiqueta.buscar(params[:codigo]) or raise ArgumentError, t("errores.etiqueta.no_encontrada", codigo: params[:codigo])
    n = @supervision.escanear!(etiqueta, usuario: usuario_actual)
    redirect_to supervision_path(@supervision), notice: t("supervision.avisos.vistas", n: n)
  rescue ArgumentError => e
    redirect_to supervision_path(@supervision), alert: e.message
  end

  def pesar
    producto = Producto.activos.find_by(id: params[:producto_id])
    pareja = @supervision.pesar!(params[:cantidad], usuario: usuario_actual, producto: producto)
    if pareja
      redirect_to supervision_path(@supervision), notice: t("supervision.avisos.esta", codigo: pareja.codigo, producto: pareja.producto.nombre)
    else
      redirect_to supervision_path(@supervision), alert: t("supervision.avisos.no_esta", cantidad: params[:cantidad])
    end
  rescue ArgumentError => e
    redirect_to supervision_path(@supervision), alert: e.message
  end

  def cerrar
    @supervision.cerrar!
    redirect_to supervisiones_path, notice: t("supervision.avisos.cerrada", folio: @supervision.folio)
  rescue ArgumentError => e
    redirect_to supervision_path(@supervision), alert: e.message
  end

  private

  def cargar_supervision
    @supervision = Supervision.where(sucursal: sucursal_actual).find(params[:id])
  end
end
