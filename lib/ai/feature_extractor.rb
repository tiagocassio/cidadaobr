# frozen_string_literal: true

module Ai
  class FeatureExtractor
    # Bump when extraction logic changes (invalidates source_payload_digest comparisons).
    LOGIC_VERSION = "v1"

    HEALTH_CONDITION_KEYS = %w[
      status_eh_hipertensao_arterial_hta
      status_tem_diabetes
      status_eh_gestante
      status_teve_avc_derrame
      status_teve_infarto
      status_tem_doenca_cardiaca
      status_tem_doenca_respiratoria
      status_tem_hanseniase
      status_tem_tuberculose
      status_tem_teve_cancer
    ].freeze

    def self.call(clinical_record:)
      new(clinical_record: clinical_record).call
    end

    def initialize(clinical_record:)
      @clinical_record = clinical_record
      @payload = clinical_record.payload_json || {}
    end

    def call
      {
        record_type: @clinical_record.record_type,
        citizen: citizen_features,
        health_conditions: health_condition_flags,
        medications_count: medications_count,
        active_problems_count: active_problems_count,
        measurements: measurement_features
      }.compact
    end

    private

    def citizen_features
      identification = payload_section("identificacao_usuario_cidadao", "identificacaoUsuarioCidadao")
      birth_date = epoch_to_date(
        identification["data_nascimento_cidadao"] || identification["dataNascimentoCidadao"]
      )
      sex = identification["sexo_cidadao"] || identification["sexoCidadao"]

      {
        age_years: age_years(birth_date),
        sex: sex&.to_s,
        pregnant: truthy?(section_value(health_conditions, "status_eh_gestante"))
      }.compact
    end

    def health_condition_flags
      HEALTH_CONDITION_KEYS.index_with { |key| truthy?(section_value(health_conditions, key)) }
        .select { |_key, value| value }
    end

    def health_conditions
      payload_section(
        "condicoes_de_saude",
        "condicoesDeSaude",
        "situacao_de_saude",
        "situacaoDeSaude"
      )
    end

    # v1 semantics: max count across payload sections (not sum over nested attendances).
    def medications_count
      section_counts = Ledi::PayloadNavigation.each_section(@payload, record_type: @clinical_record.record_type).map do |section|
        Array(section["medicamentos"] || section["medicamentosUsados"]).size
      end
      section_counts.max || 0
    end

    # v1 semantics: max count across payload sections (not sum over nested attendances).
    def active_problems_count
      section_counts = Ledi::PayloadNavigation.each_section(@payload, record_type: @clinical_record.record_type).map do |section|
        count_active_problems(section["problema_condicao"] || section["problemaCondicao"])
      end
      section_counts.max || 0
    end

    def measurement_features
      systolic = diastolic = glucose = nil

      Ledi::PayloadNavigation.each_section(@payload, record_type: @clinical_record.record_type) do |section|
        systolic ||= Ledi::PayloadNavigation.dig(section, "medicoes.pressao_arterial_sistolica") ||
                     Ledi::PayloadNavigation.dig(section, "medicoes.pressaoArterialSistolica") ||
                     Ledi::PayloadNavigation.dig(section, "pressao_sistolica") ||
                     Ledi::PayloadNavigation.dig(section, "pressaoSistolica")
        diastolic ||= Ledi::PayloadNavigation.dig(section, "medicoes.pressao_arterial_diastolica") ||
                      Ledi::PayloadNavigation.dig(section, "medicoes.pressaoArterialDiastolica") ||
                      Ledi::PayloadNavigation.dig(section, "pressao_diastolica") ||
                      Ledi::PayloadNavigation.dig(section, "pressaoDiastolica")
        glucose ||= Ledi::PayloadNavigation.dig(section, "medicoes.glicemia") ||
                    Ledi::PayloadNavigation.dig(section, "medicoes.glicemia_capilar") ||
                    Ledi::PayloadNavigation.dig(section, "glicemia")
      end

      { systolic_bp: systolic, diastolic_bp: diastolic, glucose: glucose }.compact.presence
    end

    def age_years(birth_date)
      return unless birth_date

      today = Time.zone.today
      age = today.year - birth_date.year
      age -= 1 if today.month < birth_date.month ||
                  (today.month == birth_date.month && today.day < birth_date.day)
      age
    end

    def epoch_to_date(value)
      return if value.blank?

      Time.zone.at(value.to_i / 1000).to_date
    end

    def truthy?(value)
      value == 1 || value.to_s.in?(%w[1 true t yes])
    end

    def payload_section(*keys)
      keys.lazy.map { |key| @payload[key] }.find { |section| section.present? } || {}
    end

    def section_value(section, key)
      section[key] || section[key.camelize(:lower)]
    end

    def count_active_problems(problems)
      Array(problems).count do |problem|
        next false unless problem.is_a?(Hash)

        situation = problem["situacao"] || problem["situacao_problema"] || problem["situacaoProblema"]
        situation.blank? || situation.to_s != "2"
      end
    end
  end
end
