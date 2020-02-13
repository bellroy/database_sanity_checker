# frozen_string_literal: true

RSpec.shared_examples 'unique index sanity checks' do
  specify 'unique indexes must not include deleted_at' do
    sql = <<~SQL
      SELECT tablename, indexname FROM pg_indexes WHERE indexdef ~ 'CREATE UNIQUE INDEX .* ON .* USING btree \([^\)]*deleted_at[^\)]*\).*';
    SQL
    records = ActiveRecord::Base.connection.execute sql
    output = records.map do |record|
      "#{record['tablename']} has a unique index (#{record['indexname']}) on deleted_at - nullable columns cannot be used in unique indexes"
    end.join("\n")
    raise output unless output.blank?
  end

  specify 'unique indexes must only operate on not-deleted rows' do
    sql = <<~SQL
      SELECT i.tablename, i.indexname
      FROM information_schema.columns c
      INNER JOIN pg_indexes i ON c.table_schema = i.schemaname AND c.table_name = i.tablename
      WHERE column_name = 'deleted_at'
      AND indexdef NOT LIKE '%btree (id)'
      AND indexdef LIKE 'CREATE UNIQUE INDEX%'
      AND indexdef NOT LIKE '% WHERE %(deleted_at IS NULL)%';
    SQL
    records = ActiveRecord::Base.connection.execute sql
    output = records.map do |record|
      "#{record['tablename']} has a unique index (#{record['indexname']}) that does not filter out deleted records"
    end.join("\n")
    raise output unless output.blank?
  end
end
