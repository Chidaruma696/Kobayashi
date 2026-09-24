# El sistema arranca en modo claro; el modo oscuro o seguir al sistema lo elige cada quien.
class TemaClaroPorDefecto < ActiveRecord::Migration[8.1]
  def up
    change_column_default :usuarios, :tema, from: "sistema", to: "claro"
  end

  def down
    change_column_default :usuarios, :tema, from: "claro", to: "sistema"
  end
end
