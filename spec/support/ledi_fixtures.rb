# frozen_string_literal: true

module LediFixtures
  module_function

  def installation
    Br::Gov::Saude::Esusab::Dadotransp::DadoInstalacaoThrift.new(
      contraChave: "cidadaobr",
      cpfOuCnpj: "39053344705",
      nomeOuRazaoSocial: "CidadãoBR Test"
    )
  end

  def build_transport(serialized_type:, inner_binary:, cnes:, ibge:, ine: nil, serialized_uuid: nil)
    remetente = installation
    transport = Br::Gov::Saude::Esusab::Dadotransp::DadoTransporteThrift.new(
      uuidDadoSerializado: serialized_uuid || SecureRandom.uuid,
      tipoDadoSerializado: serialized_type,
      cnesDadoSerializado: cnes,
      codIbge: ibge,
      ineDadoSerializado: ine,
      dadoSerializado: inner_binary,
      remetente: remetente,
      originadora: remetente
    )
    transport.codIbge = nil if ibge.nil?
    Ledi::ThriftReader.write(transport)
  end

  def fci_binary(cpf: "39053344705", cns: nil, cnes: "2000001", ibge: "3550308", ine: nil, serialized_uuid: nil)
    identificacao = Br::Gov::Saude::Esusab::Ras::Cadastroindividual::IdentificacaoUsuarioCidadaoThrift.new(
      nomeCidadao: "Maria da Silva",
      cpfCidadao: cpf,
      cnsCidadao: cns,
      dataNascimentoCidadao: Time.utc(1990, 5, 15).to_i * 1000,
      sexoCidadao: 1
    )

    cadastro = Br::Gov::Saude::Esusab::Ras::Cadastroindividual::CadastroIndividualThrift.new(
      uuid: SecureRandom.uuid,
      tpCdsOrigem: 3,
      identificacaoUsuarioCidadao: identificacao
    )

    build_transport(
      serialized_type: 2,
      inner_binary: Ledi::ThriftReader.write(cadastro),
      cnes: cnes,
      ibge: ibge,
      ine: ine,
      serialized_uuid: serialized_uuid
    )
  end

  def fcd_binary(cpf_responsavel: "39053344705", cnes: "2000001", ibge: "3550308")
    endereco = Br::Gov::Saude::Esusab::Ras::Common::EnderecoLocalPermanenciaThrift.new(
      nomeLogradouro: "Rua das Flores",
      numero: "100",
      bairro: "Centro",
      cep: "01001000",
      codigoIbgeMunicipio: ibge
    )

    familia = Br::Gov::Saude::Esusab::Ras::Cadastrodomiciliar::FamiliaRowThrift.new(
      cpfResponsavel: cpf_responsavel
    )

    domicilio = Br::Gov::Saude::Esusab::Ras::Cadastrodomiciliar::CadastroDomiciliarThrift.new(
      uuid: SecureRandom.uuid,
      tpCdsOrigem: 3,
      enderecoLocalPermanencia: endereco,
      familias: [ familia ]
    )

    build_transport(
      serialized_type: 3,
      inner_binary: Ledi::ThriftReader.write(domicilio),
      cnes: cnes,
      ibge: ibge
    )
  end

  def fai_binary(cpf: "39053344705", cnes: "2000001", ibge: "3550308")
    child = Br::Gov::Saude::Esusab::Ras::Atendindividual::FichaAtendimentoIndividualChildThrift.new(
      cpfCidadao: cpf,
      dataHoraInicialAtendimento: Time.current.to_i * 1000,
      localDeAtendimento: 1,
      sexo: 1,
      turno: 1,
      tipoAtendimento: 1
    )

    master = Br::Gov::Saude::Esusab::Ras::Atendindividual::FichaAtendimentoIndividualMasterThrift.new(
      uuidFicha: SecureRandom.uuid,
      tpCdsOrigem: 3,
      atendimentosIndividuais: [ child ]
    )

    build_transport(
      serialized_type: 4,
      inner_binary: Ledi::ThriftReader.write(master),
      cnes: cnes,
      ibge: ibge
    )
  end
end
