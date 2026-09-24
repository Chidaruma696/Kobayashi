module Admin
  class TiposCanastillaController < BaseController
    modulo :rutas
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
      guardar(@tipo, admin_tipos_canastilla_path, t("admin.avisos.creado", que: t("admin.modelos.tipo_canastilla")))
    end

    def edit
    end

    def update
      @tipo.assign_attributes(permitidos)
      guardar(@tipo, admin_tipos_canastilla_path, t("admin.avisos.guardado", que: t("admin.modelos.tipo_canastilla")))
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
