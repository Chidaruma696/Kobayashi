require "test_helper"

class CanastillasRutasTest < ActiveSupport::TestCase
  test "el saldo de la ruta es la suma de lo que deben sus clientes" do
    roja = TipoCanastilla.create!(nombre: "Roja", color: "#c00")
    admin = usuarios(:admin)
    taqueria = clientes(:taqueria)
    otro = Cliente.create!(nombre: "Fonda", ruta: taqueria.ruta, credito: "contado")
    suelto = Cliente.create!(nombre: "Mostrador", credito: "contado")
    Canastillas.ajustar!(tipo_canastilla: roja, cantidad: 3, motivo: "inicial", sucursal: sucursales(:matriz), usuario: admin, cliente: taqueria)
    Canastillas.ajustar!(tipo_canastilla: roja, cantidad: 2, motivo: "inicial", sucursal: sucursales(:matriz), usuario: admin, cliente: otro)
    Canastillas.ajustar!(tipo_canastilla: roja, cantidad: 1, motivo: "inicial", sucursal: sucursales(:matriz), usuario: admin, cliente: suelto)
    saldos = Canastillas.saldos_rutas
    assert_equal({ roja.id => 5 }, saldos[taqueria.ruta_id])
    assert_equal({ roja.id => 1 }, saldos[nil], "los clientes sin ruta van aparte")
  end
end
