module Admin
  class ClientesController < BaseController
    modulo :rutas
    before_action { autorizar!("admin.catalogo") }
    before_action :cargar, only: %i[edit update]

    def index
      @clientes = Cliente.includes(:ruta).order(:nombre)
      @clientes = @clientes.where("nombre LIKE :q OR telefono LIKE :q", q: "%#{params[:q]}%") if params[:q].present?
    end

    def new
      @cliente = Cliente.new(activo: true)
    end

    def create
      @cliente = Cliente.new(permitidos)
      guardar(@cliente, admin_clientes_path, t("admin.avisos.creado", que: t("admin.modelos.cliente")))
    end

    def edit
    end

    def update
      @cliente.assign_attributes(permitidos)
      guardar(@cliente, admin_clientes_path, t("admin.avisos.guardado", que: t("admin.modelos.cliente")))
    end

    private

    def cargar
      @cliente = Cliente.find(params[:id])
    end

    def permitidos
      p = params.require(:cliente).permit(:nombre, :telefono, :direccion, :ruta_id, :orden, :activo, :notas, :credito, :limite_credito, :dia_corte)
      p[:ruta_id] = nil if p[:ruta_id].blank?
      p[:dia_corte] = nil if p[:dia_corte].blank?
      p
    end
  end
end
