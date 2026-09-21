class CreateElectricityMeterTables < ActiveRecord::Migration[8.1]
  def change
    create_table :utilities, id: :uuid do |t|
      t.string :name, null: false
      t.bigint :tariff_micros_per_wh, null: false
      t.timestamps
    end

    create_table :meters, id: :uuid do |t|
      t.references :utility, null: false, foreign_key: true, type: :uuid
      t.string :reference, null: false
      t.timestamps
    end
    add_index :meters, %i[utility_id reference], unique: true

    create_table :ledger_accounts, id: :uuid do |t|
      t.integer :ledger, null: false
      t.integer :code, null: false
      t.boolean :debits_must_not_exceed_credits, null: false, default: false
      t.decimal :debits_posted, precision: 39, scale: 0, null: false, default: 0
      t.decimal :credits_posted, precision: 39, scale: 0, null: false, default: 0
      t.timestamps
    end

    create_table :ledger_transfers, id: :uuid do |t|
      t.uuid :event_id, null: false
      t.uuid :debit_account_id, null: false
      t.uuid :credit_account_id, null: false
      t.decimal :amount, precision: 39, scale: 0, null: false
      t.integer :ledger, null: false
      t.integer :code, null: false
      t.timestamps
    end
    add_index :ledger_transfers, :event_id
    add_index :ledger_transfers, :debit_account_id
    add_index :ledger_transfers, :credit_account_id
  end
end
