module Admin
  class PromocionesController < BaseController
    before_action { autorizar!("admin.catalogo") }
    before_action :cargar, only: %i[edit update destroy]

    def index
      @promociones = Promocion.includes(:producto, :sucursal).order(activa: :desc, created_at: :desc)
    end

    def new
      @promocion = Promocion.new(tipo: "precio", activa: true)
    end

    def create
      @promocion = Promocion.new(permitidos)
      guardar(@promocion, admin_promociones_path, "Promoción creada")
    end

    def edit
    end

    def update
      @promocion.assign_attributes(permitidos)
      guardar(@promocion, admin_promociones_path, "Promoción guardada")
    end

    def destroy
      @promocion.destroy!
      redirect_to admin_promociones_path, notice: "Promoción borrada"
    rescue ActiveRecord::RecordNotDestroyed
      redirect_to admin_promociones_path, alert: "Ya se usó en ventas: desactívala en vez de borrarla"
    end

    private

    def cargar
      @promocion = Promocion.find(params[:id])
    end

    def permitidos
      p = params.require(:promocion).permit(:nombre, :producto_id, :sucursal_id, :tipo, :precio, :porcentaje, :cantidad_minima, :desde, :hasta, :activa)
      p[:precio_centavos] = Dinero.centavos(p.delete(:precio)) if p.key?(:precio)
      p[:sucursal_id] = nil if p[:sucursal_id].blank?
      p[:cantidad_minima] = 0 if p[:cantidad_minima].blank?
      p
    end
  end
end
