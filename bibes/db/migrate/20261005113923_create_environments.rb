class CreateEnvironments < ActiveRecord::Migration[8.1]
  def change
    create_table :environments do |t|
      t.string :name

      t.timestamps
    end
  end
end
