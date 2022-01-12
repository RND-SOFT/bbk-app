class CreateServiceRequests < ActiveRecord::Migration[5.1]

  def change
    create_table :service_requests do |t|
      t.string :ticket_id, null: false, unique: true
      t.integer :status
      t.string :consumer, null: false, index: true
      t.string :reply_to, null: false

      t.text :request
      t.text :response
      t.text :status_info

      t.integer :retry, default: 0
      t.timestamps
    end
  end

end

