module Admin
  class RutasController < BaseController
    before_action { autorizar!("admin.catalogo") }
    before_action :cargar, only: %i[edit update orden guardar_orden]

    def index
      @rutas = Ruta.includes(:chofer, :clientes).order(:nombre)
    end

    def new
      @ruta = Ruta.new(activa: true)
    end

    def create
      @ruta = Ruta.new(permitidos)
      guardar(@ruta, admin_rutas_path, "Ruta creada")
    end

    def edit
    end

    def update
      @ruta.assign_attributes(permitidos)
      guardar(@ruta, admin_rutas_path, "Ruta guardada")
    end

    # Orden de reparto de la ruta: cada cliente en su zona y con su número.
    def orden
      @clientes = @ruta.clientes_en_orden
      @zonas = @ruta.zonas.activas.en_orden
    end

    def guardar_orden
      Cliente.transaction do
        (params[:clientes] || {}).each do |id, campos|
          c = @ruta.clientes.find(id)
          c.update!(zona_id: campos[:zona_id].presence, orden: campos[:orden].to_i)
        end
      end
      redirect_to orden_admin_ruta_path(@ruta), notice: "Orden de reparto guardado"
    rescue ActiveRecord::RecordInvalid => e
      redirect_to orden_admin_ruta_path(@ruta), alert: e.record.errors.full_messages.join(", ")
    end

    private

    def cargar
      @ruta = Ruta.find(params[:id])
    end

    def permitidos
      p = params.require(:ruta).permit(:nombre, :chofer_id, :activa, zonas_attributes: %i[id nombre orden activa _destroy])
      p[:chofer_id] = nil if p.key?(:chofer_id) && p[:chofer_id].blank?
      p
    end
  end
end
