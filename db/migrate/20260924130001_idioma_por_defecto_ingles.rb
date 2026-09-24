class IdiomaPorDefectoIngles < ActiveRecord::Migration[8.1]
  # El sistema arranca en inglés; cada quien elige el suyo.
  def up
    change_column_default :usuarios, :idioma, from: "es", to: "en"
  end

  def down
    change_column_default :usuarios, :idioma, from: "en", to: "es"
  end
end
