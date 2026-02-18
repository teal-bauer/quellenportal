class InitSchema < ActiveRecord::Migration[7.1]
  def up
    create_table :records do |t|
      t.datetime :created_at, null: false
      t.datetime :updated_at, null: false

      t.string :title
      t.string :summary
      t.string :call_number
      t.string :source_date_text
      t.string :source_id
      t.string :link
      t.string :location
      t.string :language_code

      # Use a JSON column for the parents array as a replacement for the Postgres array type:
      # https://fractaledmind.github.io/2023/09/12/enhancing-rails-sqlite-array-columns/
      t.json :parents, default: [], null: false
      t.check_constraint "JSON_TYPE(parents) = 'array'",
                         name: 'parents_is_array'

      t.date :source_date_start
      t.date :source_date_end

      t.index :title
      t.index :summary
      t.index %i[title summary]
      t.index :call_number
      t.index :source_id, unique: true
    end
  end

  create_table :origins do |t|
    t.datetime :created_at, null: false
    t.datetime :updated_at, null: false

    t.integer :label, default: 0
    t.string :name

    t.index %i[label name], unique: true
    t.index :name
  end

  create_table :originations, id: false do |t|
    t.integer :record_id
    t.integer :origin_id

    t.index :origin_id
    t.index :record_id
    t.index %i[record_id origin_id], unique: true
  end

  create_table :cached_counts do |t|
    t.datetime :created_at, null: false
    t.datetime :updated_at, null: false

    t.string :model
    t.string :scope
    t.integer :count

    t.index %i[model scope], unique: true
  end

  def down
    raise ActiveRecord::IrreversibleMigration,
          'The initial migration is not revertable'
  end
end
