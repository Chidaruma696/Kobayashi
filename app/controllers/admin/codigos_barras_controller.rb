module Admin
  class CodigosBarrasController < BaseController
    before_action { autorizar!("admin.catalogo") }

    def create
      producto = Producto.find(params[:producto_id])
      codigo = producto.codigos_barras.build(codigo: params[:codigo])
      if codigo.save
        redirect_to edit_admin_producto_path(producto), notice: "Código #{codigo.codigo} agregado"
      else
        redirect_to edit_admin_producto_path(producto), alert: codigo.errors.full_messages.join(", ")
      end
    end

    def destroy
      producto = Producto.find(params[:producto_id])
      producto.codigos_barras.find(params[:id]).destroy!
      redirect_to edit_admin_producto_path(producto), notice: "Código quitado"
    end
  end
end
