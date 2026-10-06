class CreateBibes < ActiveRecord::Migration[8.1]
  def change
    create_table :bibes do |t|
      t.string :name
      t.string :engineer
      t.string :namespace
      t.string :environment

      t.timestamps
    end
  end
end
