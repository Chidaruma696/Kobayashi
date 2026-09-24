class ApplicationController < ActionController::Base
  allow_browser versions: :modern
  stale_when_importmap_changes

  class SinPermiso < StandardError; end

  # Pestaña de la cinta que corresponde a este controlador (ver RibbonHelper).
  class_attribute :pestana_ribbon, default: :inicio
  def self.pestana(id) = self.pestana_ribbon = id

  before_action :exigir_sesion
  helper_method :usuario_actual, :sucursal_actual, :puede?

  rescue_from SinPermiso do |e|
    render "errores/sin_permiso", status: :forbidden, locals: { clave: e.message }
  end

  private

  def usuario_actual
    Current.usuario ||= Usuario.activos.includes(:rol, :sucursal).find_by(id: cookies.signed[:usuario_id])
  end

  def sucursal_actual
    Current.sucursal ||= usuario_actual&.sucursal
  end

  def exigir_sesion
    redirect_to entrar_path, alert: "Inicia sesión para continuar" unless usuario_actual
  end

  def puede?(clave)
    usuario_actual&.puede?(clave) || false
  end

  # Corta la petición si el usuario no tiene el permiso.
  def autorizar!(clave)
    raise SinPermiso, clave unless puede?(clave)
  end

  # Autorización diferida (no hay PIN): si quien opera tiene el permiso, queda a su nombre; si no,
  # la operación sigue igual y queda por revisar (ver Revision). Devuelve quien autoriza o nil.
  def autorizador_o_revision(clave)
    puede?(clave) ? usuario_actual : nil
  end

  # Deja la operación en la bandeja de revisión si nadie la autorizó.
  def revisar_si_hace_falta(registro, autoriza, motivo:, valor_centavos: 0, sucursal: sucursal_actual)
    return if autoriza
    Revision.abrir!(registro, usuario: usuario_actual, sucursal: sucursal, motivo: motivo, valor_centavos: valor_centavos)
  end

  def iniciar_sesion(usuario)
    cookies.signed.permanent[:usuario_id] = { value: usuario.id, httponly: true, same_site: :lax }
    Current.usuario = usuario
  end

  def cerrar_sesion
    cookies.delete(:usuario_id)
    Current.reset
  end
end
