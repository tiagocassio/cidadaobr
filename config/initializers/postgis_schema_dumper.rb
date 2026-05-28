# frozen_string_literal: true

# PostGIS images install tiger/topology schemas. Dump only public application tables.
ActiveSupport.on_load(:active_record) do
  ActiveRecord::SchemaDumper.class_eval do
    POSTGIS_PUBLIC_TABLES = %w[
      spatial_ref_sys
      geography_columns
      geometry_columns
      raster_columns
      raster_overviews
    ].freeze

    private

    def tables(stream)
      excluded = POSTGIS_PUBLIC_TABLES.map { |table| connection.quote(table) }.join(", ")

      @connection.select_values(<<~SQL.squish).sort.each do |table|
        SELECT table_name
        FROM information_schema.tables
        WHERE table_schema = 'public'
          AND table_type = 'BASE TABLE'
          AND table_name NOT IN (#{excluded})
        ORDER BY table_name
      SQL
        table(table, stream) unless ignored?(table)
      end
    end
  end
end
