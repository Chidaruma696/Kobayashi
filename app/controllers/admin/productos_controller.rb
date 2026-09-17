module Admin
  class ProductosController < BaseController
    before_action { autorizar!("admin.catalogo") }
    before_action :cargar, only: %i[edit update]

    def index
      @productos = Producto.order(:nombre).includes(:codigos_barras)
      @productos = @productos.where("nombre LIKE :q OR clave LIKE :q", q: "%#{params[:q]}%") if params[:q].present?
    end

    def new
      @producto = Producto.new(unidad: "kg")
    end

    def create
      @producto = Producto.new(permitidos)
      guardar(@producto, -> { edit_admin_producto_path(@producto) }, "Producto creado")
    end

    def edit
    end

    def update
      @producto.assign_attributes(permitidos)
      guardar(@producto, admin_productos_path, "Producto guardado")
    end

    private

    def cargar
      @producto = Producto.find(params[:id])
    end

    def permitidos
      p = params.require(:producto).permit(:clave, :nombre, :linea, :unidad, :precio, :peso_fijo, :plu, :activo)
      p[:clave] = p[:clave].to_s.strip.upcase
      p[:peso_fijo] = nil if p.key?(:peso_fijo) && p[:peso_fijo].blank?
      p[:plu] = nil if p.key?(:plu) && p[:plu].blank?
      p
    end
  end
end
