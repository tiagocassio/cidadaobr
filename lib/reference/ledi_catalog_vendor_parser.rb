# frozen_string_literal: true

module Reference
  class LediCatalogVendorParser
    THRIFT_FILES = {
      "cadastro_individual_types.rb" => "FCI",
      "cadastro_domiciliar_types.rb" => "FCD",
      "ficha_atendimento_individual_types.rb" => "FAI",
      "ficha_atendimento_odonto_types.rb" => "FAO",
      "ficha_atendimento_procedimento_types.rb" => "FP",
      "ficha_vacinacao_types.rb" => "FV",
      "ficha_visita_domiciliar_types.rb" => "FVD",
      "ficha_atendimento_domiciliar_types.rb" => "FAD",
      "ficha_avaliacao_elegibilidade_types.rb" => "FAE",
      "ficha_complementar_zika_microcefalia_types.rb" => "FCZM",
      "cuidado_compartilhado_types.rb" => "FCC",
      "ficha_atividade_coletiva_types.rb" => "FAC",
      "ficha_consumo_alimentar_types.rb" => "MCA"
    }.freeze

    ROOT_STRUCT_BY_FILE = {
      "cadastro_individual_types.rb" => "CadastroIndividualThrift",
      "cadastro_domiciliar_types.rb" => "CadastroDomiciliarThrift",
      "ficha_atendimento_individual_types.rb" => "FichaAtendimentoIndividualMasterThrift",
      "ficha_atendimento_odonto_types.rb" => "FichaAtendimentoOdontologicoMasterThrift",
      "ficha_atendimento_procedimento_types.rb" => "FichaProcedimentoMasterThrift",
      "ficha_vacinacao_types.rb" => "FichaVacinacaoMasterThrift",
      "ficha_visita_domiciliar_types.rb" => "FichaVisitaDomiciliarMasterThrift",
      "ficha_atendimento_domiciliar_types.rb" => "FichaAtendimentoDomiciliarMasterThrift",
      "ficha_avaliacao_elegibilidade_types.rb" => "FichaAvaliacaoElegibilidadeThrift",
      "ficha_complementar_zika_microcefalia_types.rb" => "FichaComplementarZikaMicrocefaliaThrift",
      "cuidado_compartilhado_types.rb" => "CuidadoCompartilhadoThrift",
      "ficha_atividade_coletiva_types.rb" => "FichaAtividadeColetivaThrift",
      "ficha_consumo_alimentar_types.rb" => "FichaConsumoAlimentarThrift"
    }.freeze

    THRIFT_TYPE_MAP = {
      "::Thrift::Types::STRING" => "string",
      "::Thrift::Types::I32" => "integer",
      "::Thrift::Types::I64" => "integer",
      "::Thrift::Types::DOUBLE" => "number",
      "::Thrift::Types::BOOL" => "boolean",
      "::Thrift::Types::LIST" => "array",
      "::Thrift::Types::MAP" => "object",
      "::Thrift::Types::SET" => "array"
    }.freeze

    class << self
      def call(ledi_version: Rails.application.config.ledi.fetch(:version))
        vendor_dir = Rails.root.join("vendor/ledi/#{ledi_version}/gen-rb")
        return 0 unless vendor_dir.directory?

        imported = 0
        timestamp = Time.current
        THRIFT_FILES.each do |filename, record_type|
          path = vendor_dir.join(filename)
          next unless path.exist?

          field_map = fields_for(path, filename)
          next if field_map.empty?

          upsert_fields!(record_type, field_map, ledi_version, timestamp)
          imported += field_map.size
        end

        imported
      end

      UPSERT_BATCH_SIZE = 500

      def upsert_fields!(record_type, field_map, ledi_version, timestamp)
        field_map.each_slice(UPSERT_BATCH_SIZE) do |slice|
          rows = slice.map do |field_path, field_meta|
            {
              id: SecureRandom.uuid,
              record_type: record_type,
              field_path: field_path,
              ledi_version: ledi_version,
              data_type: field_meta.fetch(:data_type),
              required: field_meta.fetch(:required),
              min_occurs: field_meta.fetch(:min_occurs),
              created_at: timestamp,
              updated_at: timestamp
            }
          end

          LediFieldCatalog.upsert_all(
            rows,
            unique_by: :index_ledi_field_catalogs_on_type_path_version,
            update_only: %i[data_type required min_occurs updated_at],
            record_timestamps: false
          )
        end
      end

      private

      def fields_for(path, filename)
        structs = parse_struct_definitions(path.read)
        root = ROOT_STRUCT_BY_FILE[filename] || structs.keys.find { |name| name.end_with?("MasterThrift") }
        return {} unless root && structs[root]

        expand_struct_fields(structs, root, prefix: nil)
      end

      def parse_struct_definitions(content)
        structs = {}
        pos = 0

        while (class_index = content.index(/class\s+(\w+)/, pos))
          class_name = Regexp.last_match(1)
          fields_marker = content.index("FIELDS = {", class_index)
          unless fields_marker
            pos = class_index + 1
            next
          end

          brace_start = content.index("{", fields_marker)
          unless brace_start
            pos = class_index + 1
            next
          end

          fields_block = extract_braced_content(content, brace_start)
          unless fields_block
            pos = class_index + 1
            next
          end

          pos = brace_start + fields_block.length + 2

          fields = {}
          field_entries(fields_block).each do |field_def|
            name = field_def[/:name => '([^']+)'/, 1]
            next unless name

            thrift_type = field_def[/:type => (.+?)(?:,|\s*\})/, 1]&.strip
            struct_class = field_def[/:class => .*::(\w+)/, 1]
            optional = field_def.include?(":optional => true")
            fields[camel_to_snake(name)] = { type: thrift_type, struct_class: struct_class, optional: optional }
          end
          structs[class_name] = fields if fields.any?
        end

        structs
      end

      def extract_braced_content(content, brace_start)
        depth = 0

        (brace_start...content.length).each do |index|
          case content[index]
          when "{"
            depth += 1
          when "}"
            depth -= 1
            return content[(brace_start + 1)...index] if depth.zero?
          end
        end

        nil
      end

      def expand_struct_fields(structs, class_name, prefix:)
        fields = structs[class_name] || {}
        result = {}

        fields.each do |name, meta|
          path = [ prefix, name ].compact.join(".")
          if meta[:type] == "::Thrift::Types::STRUCT" && meta[:struct_class] && structs[meta[:struct_class]]
            result.merge!(expand_struct_fields(structs, meta[:struct_class], prefix: path))
          else
            optional = meta.fetch(:optional, false)
            result[path] = {
              data_type: THRIFT_TYPE_MAP.fetch(meta[:type], "string"),
              required: !optional,
              min_occurs: optional ? 0 : 1
            }
          end
        end

        result
      end

      def field_entries(fields_block)
        entries = []
        pos = 0

        while (match = fields_block.index(/\w+ => \{/, pos))
          brace_start = fields_block.index("{", match)
          depth = 0
          brace_end = nil

          (brace_start...fields_block.length).each do |index|
            case fields_block[index]
            when "{" then depth += 1
            when "}"
              depth -= 1
              if depth.zero?
                brace_end = index
                break
              end
            end
          end

          break unless brace_end

          entries << fields_block[(brace_start + 1)...brace_end]
          pos = brace_end + 1
        end

        entries
      end

      def camel_to_snake(value)
        value.gsub(/([A-Z])/, '_\1').downcase.sub(/\A_/, "")
      end
    end
  end
end
