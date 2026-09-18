module Admin
  class ConveniosController < BaseController
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
      guardar(@convenio, admin_convenios_path, "Convenio creado")
    end

    def edit
    end

    def update
      @convenio.assign_attributes(permitidos)
      guardar(@convenio, admin_convenios_path, "Convenio guardado")
    end

    def destroy
      @convenio.destroy!
      redirect_to admin_convenios_path, notice: "Convenio borrado"
    rescue ActiveRecord::RecordNotDestroyed
      redirect_to admin_convenios_path, alert: "Ya se usó en notas: desactívalo en vez de borrarlo"
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
