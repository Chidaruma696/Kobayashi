class SesionesController < ApplicationController
  skip_before_action :exigir_sesion, only: %i[new create]
  layout "sesion"

  def new
    redirect_to root_path if usuario_actual
  end

  def create
    usuario = Usuario.activos.find_by(usuario: params[:usuario].to_s.strip.downcase)
    if usuario&.authenticate(params[:password])
      iniciar_sesion(usuario)
      redirect_to root_path, notice: "Hola, #{usuario.nombre}"
    else
      flash.now[:alert] = "Usuario o contraseña incorrectos"
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    cerrar_sesion
    redirect_to entrar_path, notice: "Sesión cerrada"
  end
end
