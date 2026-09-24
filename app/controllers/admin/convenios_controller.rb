module Admin
  class ConveniosController < BaseController
    modulo :rutas
    before_action { autorizar!("admin.catalogo") }
    before_action :cargar, only: %i[edit update destroy]

    def index
      @convenios = Convenio.includes(:cliente).order(activo: :desc, created_at: :desc)
    end

    def new
      @convenio = Convenio.new(activo: true, tope_cajas: 0)
    end

    def create
      @convenio = Convenio.new(permitidos)
      guardar(@convenio, admin_convenios_path, t("admin.avisos.creado", que: t("admin.modelos.convenio")))
    end

    def edit
    end

    def update
      @convenio.assign_attributes(permitidos)
      guardar(@convenio, admin_convenios_path, t("admin.avisos.guardado", que: t("admin.modelos.convenio")))
    end

    def destroy
      @convenio.destroy!
      redirect_to admin_convenios_path, notice: t("admin.avisos.borrado", que: t("admin.modelos.convenio"))
    rescue ActiveRecord::RecordNotDestroyed
      redirect_to admin_convenios_path, alert: t("admin.avisos.ya_usado", que: t("admin.modelos.convenio"))
    end

    private

    def cargar
      @convenio = Convenio.find(params[:id])
    end

    def permitidos
      params.require(:convenio).permit(:cliente_id, :lineas, :excluir, :tope_cajas, :precio, :activo, :notas)
    end
  end
end
