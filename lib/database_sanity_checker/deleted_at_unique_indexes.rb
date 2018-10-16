# frozen_string_literal: true

RSpec.shared_examples 'Unique indexes do not include deleted_at', :aggregate_failures do
  def unique_indexes(model)
    ApplicationRecord.connection.indexes(model.table_name).select(&:unique)
  end

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
