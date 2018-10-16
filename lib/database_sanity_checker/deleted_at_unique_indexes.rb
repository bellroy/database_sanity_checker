# frozen_string_literal: true

def unique_indexes(model)
  ActiveRecord::Base.connection.indexes(model.table_name).select(&:unique)
end

RSpec.shared_examples 'Unique indexes do not include deleted_at', :aggregate_failures do
  specify do
    ActiveRecord::Base.descendants.each do |model|
      unique_indexes(model).each do |unique_index|
        expect(unique_index.columns)
          .not_to include('deleted_at'),
                  "on: #{model.table_name.inspect}, #{unique_index.columns.inspect}"
      end
    end
  end
end
