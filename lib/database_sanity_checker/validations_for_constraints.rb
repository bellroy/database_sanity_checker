# frozen_string_literal: true

class IndexValidatorHelper
  attr_reader :model

  def initialize(model)
    @model = model
  end

  def unique_indexes
    ApplicationRecord.connection.indexes(model.table_name).select(&:unique)
  end

  def index_is_a_function?(index)
    index.is_a?(String) && index.starts_with?('upper(')
  end

  def extract_index_name_from_function(index)
    index.match(/\(\w+\)/).to_s.match(/\w+/).to_s
  end
end

RSpec.shared_examples 'ActiveRecord validations exist for each database constraint', :aggregate_failures do
  before do
    Rails.application.eager_load!
  end

  context 'when NOT_NULL constraint exists' do
    ActiveRecord::Base.descendants.each do |model|
      next if model == ActiveRecord::SchemaMigration

      not_null_columns = begin
                           model.columns.reject(&:null).reject { |column| column.name == 'id' }
                         rescue StandardError
                           next
                         end
      not_null_columns.each do |column|
        column_name = column.name

        next if column_name.in?(%w[created_at updated_at])
        next if %i[boolean json].include?(column.type)
        next unless column.default.nil? && column.default_function.nil?

        presence_validator = model.validators_on(column_name).find do |validator|
          validator.is_a?(ActiveRecord::Validations::PresenceValidator)
        end

        presence_is_enforced = presence_validator.present? || begin
          if column_name.ends_with?('_id')
            reflection = model.reflections[column_name[0..-4]] || {}
            !reflection.options[:optional] if reflection.present?
          else
            false
          end
        end

        context "with model #{model} and column: #{column_name}" do
          specify do
            expect(presence_is_enforced).to be true
          end
        end
      end
    end
  end

  context 'when NOT_NULL constraint exists for boolean fields' do
    ActiveRecord::Base.descendants.each do |model|
      not_null_columns = begin
                           model.content_columns.reject(&:null)
                         rescue StandardError
                           next
                         end
      not_null_columns.each do |column|
        column_name = column.name

        next unless column.type == :boolean

        inclusion_validator = model.validators_on(column_name).find do |validator|
          validator.is_a?(ActiveModel::Validations::InclusionValidator)
        end

        context "with model #{model} and column: #{column_name}" do
          specify do
            expect(inclusion_validator).to be_present
            expect(inclusion_validator.options).to eq(in: [true, false])
          end
        end
      end
    end
  end

  context 'when UNIQUE constraint exists' do
    ActiveRecord::Base.descendants.each do |model|
      helper = IndexValidatorHelper.new(model)

      helper.unique_indexes.each do |index|
        case_sensitive = false
        if helper.index_is_a_function?(index.columns)
          case_sensitive = true
          columns_names = [helper.extract_index_name_from_function(index.columns)]
        else
          columns_names = index.columns
        end

        columns_to_check = columns_names.map(&:to_sym) - [:deleted_at]

        uniqueness_validator = model.validators_on(*columns_to_check).find do |validator|
          validator_fields = validator.attributes
          scope_fields = [validator.options[:scope]].flatten.compact
          fields_from_validator = scope_fields + validator_fields - [:deleted_at]

          valid = validator.is_a?(ActiveRecord::Validations::UniquenessValidator) &&
                  columns_to_check.sort == fields_from_validator.sort

          if case_sensitive
            valid && validator.options[:case_sensitive] == case_sensitive
          else
            valid
          end
        end

        context "with #{model} and columns: #{columns_to_check}" do
          specify do
            expect(uniqueness_validator).to be_present
          end
        end
      end
    end
  end
end
