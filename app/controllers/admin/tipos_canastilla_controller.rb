module Admin
  class TiposCanastillaController < BaseController
    before_action { autorizar!("admin.catalogo") }
    before_action :cargar, only: %i[edit update]

    def index
      @tipos = TipoCanastilla.order(activo: :desc, nombre: :asc)
    end

    def new
      @tipo = TipoCanastilla.new(activo: true)
    end

    def create
      @tipo = TipoCanastilla.new(permitidos)
      guardar(@tipo, admin_tipos_canastilla_path, "Tipo de canastilla creado")
    end

    def edit
    end

    def update
      @tipo.assign_attributes(permitidos)
      guardar(@tipo, admin_tipos_canastilla_path, "Tipo de canastilla guardado")
    end

    private

    def cargar
      @tipo = TipoCanastilla.find(params[:id])
    end

    def permitidos
      params.require(:tipo_canastilla).permit(:nombre, :color, :activo)
    end
  end
end
