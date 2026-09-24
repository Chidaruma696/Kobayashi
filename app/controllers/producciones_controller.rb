class ProduccionesController < ApplicationController
  pestana :etiquetas
  modulo :etiquetas

  before_action { autorizar!("produccion.abrir") }

  def index
    @abiertas = Produccion.where(sucursal: sucursal_actual).abiertas.includes(:producto, :usuario).order(:created_at)
    @cerradas = Produccion.where(sucursal: sucursal_actual).where(estado: "cerrada").includes(:producto).order(created_at: :desc).limit(20)
  end

  def new
    @productos = Producto.activos.order(:nombre)
  end

  # Entra un producto en una cantidad; lo que sale se etiqueta bajo la producción. Nada más.
  def create
    producto = Producto.activos.find(params[:producto_id])
    produccion = Produccion.abrir!(sucursal: sucursal_actual, producto: producto, cantidad: params[:cantidad], usuario: usuario_actual)
    redirect_to new_etiqueta_path(produccion_id: produccion.id), notice: t("produccion.abierta_aviso", folio: produccion.folio, cantidad: produccion.cantidad.to_s("F"), producto: produccion.producto.nombre)
  rescue Inventario::SinExistencia, ActiveRecord::RecordInvalid, ArgumentError => e
    redirect_to new_produccion_path, alert: e.message
  end

  def show
    @produccion = Produccion.where(sucursal: sucursal_actual).includes(:producto).find(params[:id])
    @salidas = @produccion.salidas
  end

  def cerrar
    produccion = Produccion.where(sucursal: sucursal_actual).find(params[:id])
    produccion.cerrar!(usuario: usuario_actual)
    redirect_to produccion_path(produccion), notice: t("produccion.cerrada_aviso", merma: "#{produccion.merma.to_s("F")} #{produccion.producto.unidad}")
  rescue ArgumentError => e
    redirect_to produccion_path(params[:id]), alert: e.message
  end
end
