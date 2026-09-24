# Ajustes: lo de cada quien (idioma, tema, densidad, letra) y lo del sistema (negocio, etiqueta,
# caja), esto último solo para quien administra usuarios.
class AjustesController < ApplicationController
  pestana :ajustes

  def index
    @ajustes = Ajuste.todos
  end

  def preferencias
    usuario_actual.update!(params.require(:usuario).permit(:idioma, :tema, :densidad, :letra))
    redirect_to ajustes_path, notice: I18n.t("ajustes.guardado", locale: usuario_actual.idioma)
  rescue ActiveRecord::RecordInvalid => e
    redirect_to ajustes_path, alert: e.record.errors.full_messages.join(", ")
  end

  def sistema
    autorizar!("admin.usuarios")
    Ajuste.guardar!(params.fetch(:ajuste, {}).to_unsafe_h)
    redirect_to ajustes_path, notice: t("ajustes.guardado")
  rescue ArgumentError, ActiveRecord::RecordInvalid => e
    redirect_to ajustes_path, alert: e.message
  end
end
