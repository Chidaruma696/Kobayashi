module Admin
  class RutasController < BaseController
    before_action { autorizar!("admin.catalogo") }
    before_action :cargar, only: %i[edit update]

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

    private

    def cargar
      @ruta = Ruta.find(params[:id])
    end

    def permitidos
      p = params.require(:ruta).permit(:nombre, :chofer_id, :activa)
      p[:chofer_id] = nil if p[:chofer_id].blank?
      p
    end
  end
end
