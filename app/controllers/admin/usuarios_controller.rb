module Admin
  class UsuariosController < BaseController
    before_action { autorizar!("admin.usuarios") }
    before_action :cargar, only: %i[edit update]

    def index
      @usuarios = Usuario.includes(:rol, :sucursal).order(:nombre)
    end

    def new
      @usuario = Usuario.new(sucursal: sucursal_actual, activo: true)
    end

    def create
      @usuario = Usuario.new(permitidos)
      guardar(@usuario, admin_usuarios_path, "Usuario creado")
    end

    def edit
    end

    def update
      @usuario.assign_attributes(permitidos)
      guardar(@usuario, admin_usuarios_path, "Usuario guardado")
    end

    private

    def cargar
      @usuario = Usuario.find(params[:id])
    end

    # Contraseña y PIN solo cambian si se escriben.
    def permitidos
      p = params.require(:usuario).permit(:nombre, :usuario, :rol_id, :sucursal_id, :activo, :password, :pin)
      p[:usuario] = p[:usuario].to_s.strip.downcase
      p.delete(:password) if p[:password].blank?
      p.delete(:pin) if p[:pin].blank?
      p
    end
  end
end
