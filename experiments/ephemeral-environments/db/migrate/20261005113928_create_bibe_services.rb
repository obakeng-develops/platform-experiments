class CreateBibeServices < ActiveRecord::Migration[8.1]
  def change
    create_table :bibe_services do |t|
      t.string :version
      t.boolean :pinned
      t.references :bibe, null: false, foreign_key: true
      t.references :service, null: false, foreign_key: true

      t.timestamps
    end
  end
end
