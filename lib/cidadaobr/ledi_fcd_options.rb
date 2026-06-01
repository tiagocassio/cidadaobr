# frozen_string_literal: true

module Cidadaobr
  # e-SUS APS / LEDI 7.4 — Cadastro Domiciliar (FCD) coded fields for web forms.
  module LediFcdOptions
    PROPERTY_TYPES = {
      1 => "Domicílio",
      2 => "Comércio",
      3 => "Terreno baldio",
      4 => "Ponto estratégico",
      5 => "Escola",
      6 => "Creche",
      7 => "Abrigo",
      8 => "Instituição de longa permanência",
      9 => "Unidade prisional",
      10 => "Unidade socioeducativa",
      11 => "Delegacia",
      12 => "Estabelecimento religioso"
    }.freeze

    HOUSING_CONDITION_FIELDS = {
      localizacao: {
        1 => "Urbana",
        2 => "Rural"
      },
      tipo_domicilio: {
        1 => "Casa",
        2 => "Apartamento",
        3 => "Cômodo",
        4 => "Maloca",
        5 => "Improvisado",
        6 => "Barraco",
        7 => "Outro"
      },
      situacao_moradia_posse_terra: {
        1 => "Próprio",
        2 => "Financiado",
        3 => "Alugado",
        4 => "Arrendado",
        5 => "Cedido",
        6 => "Ocupação",
        7 => "Situação de rua",
        8 => "Outra"
      },
      tipo_acesso_domicilio: {
        1 => "Pavimento",
        2 => "Chão batido",
        3 => "Fluvial",
        4 => "Outro"
      },
      material_paredes: {
        1 => "Alvenaria com revestimento",
        2 => "Alvenaria sem revestimento",
        3 => "Taipa com revestimento",
        4 => "Taipa sem revestimento",
        5 => "Madeira emparelhada",
        6 => "Palha",
        7 => "Outro material"
      },
      abastecimento_agua: {
        1 => "Rede encanada",
        2 => "Poço / nascente",
        3 => "Cisterna",
        4 => "Carro pipa",
        5 => "Outro"
      },
      agua_consumo: {
        1 => "Filtrada",
        2 => "Fervida",
        3 => "Clorada",
        4 => "Mineral",
        5 => "Sem tratamento"
      },
      forma_escoamento_banheiro: {
        1 => "Rede coletora",
        2 => "Fossa séptica",
        3 => "Fossa rudimentar",
        4 => "Direto para rio / lago / mar",
        5 => "Céu aberto",
        6 => "Outra forma"
      },
      destino_lixo: {
        1 => "Coletado",
        2 => "Queimado",
        3 => "Enterrado",
        4 => "Jogado em terreno baldio / água",
        5 => "Outro"
      }
    }.freeze
  end
end
