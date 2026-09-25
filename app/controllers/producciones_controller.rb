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
    @reparto = @produccion.reparto.index_by { |f| f[:producto] }
  end

  # Cerrar es cerrar; si la merma se pasó de lo que el producto espera, queda por revisar con el
  # exceso valuado a precio de catálogo. Es un aviso que no frena a nadie.
  def cerrar
    produccion = Produccion.where(sucursal: sucursal_actual).find(params[:id])
    produccion.cerrar!(usuario: usuario_actual)
    aviso = t("produccion.cerrada_aviso", merma: "#{produccion.merma.to_s("F")} #{produccion.producto.unidad}")
    if produccion.merma_excedida?
      motivo = t("produccion.merma_excedida", pct: produccion.merma_pct, esperada: produccion.producto.merma_esperada.to_s("F"), folio: produccion.folio)
      revisar_si_hace_falta(produccion, nil, motivo: motivo, valor_centavos: Revision.valor(produccion.exceso_merma, produccion.producto, sucursal_actual))
      aviso += t("produccion.merma_por_revisar")
    end
    redirect_to produccion_path(produccion), notice: aviso
  rescue ArgumentError => e
    redirect_to produccion_path(params[:id]), alert: e.message
  end
end
