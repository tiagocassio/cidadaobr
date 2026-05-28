# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    module PostgreSQL
      module OID
        class Geography < ActiveRecord::Type::Value
          def type
            :geography
          end
        end
      end
    end
  end
end

POSTGIS_PUBLIC_TABLES = %w[
  spatial_ref_sys
  geography_columns
  geometry_columns
  raster_columns
  raster_overviews
].freeze

ActiveSupport.on_load(:active_record_postgresqladapter) do
  ActiveRecord::ConnectionAdapters::PostgreSQL::TableDefinition.class_eval do
    def geography(name, **options)
      sql_type = options.delete(:sql_type) || "geography(Point,4326)"
      column(name, sql_type, **options)
    end
  end

  ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.class_eval do
    alias_method :initialize_type_map_without_geography, :initialize_type_map

    def initialize_type_map(m = type_map)
      initialize_type_map_without_geography(m)
      m.register_type "geography", ActiveRecord::ConnectionAdapters::PostgreSQL::OID::Geography.new
    end

    def valid_type?(type)
      return true if type == :geography

      super
    end
  end
end

ActiveSupport.on_load(:active_record) do
  ActiveRecord::ConnectionAdapters::PostgreSQL::SchemaDumper.class_eval do
    def ignored?(table_name)
      POSTGIS_PUBLIC_TABLES.include?(table_name) || super
    end

    def schema_type(column)
      return :geography if column.type == :geography

      super
    end
  end
end
