# frozen_string_literal: true

module Ledi
  module ThriftReader
    module_function

    def read(binary, thrift_class)
      transport = Thrift::MemoryBufferTransport.new(binary.to_s.b)
      protocol = Thrift::BinaryProtocol.new(transport)
      instance = thrift_class.new
      instance.read(protocol)
      instance.validate if instance.respond_to?(:validate)
      instance
    end

    def write(thrift_struct)
      buffer = +""
      transport = Thrift::MemoryBufferTransport.new(buffer)
      protocol = Thrift::BinaryProtocol.new(transport)
      thrift_struct.write(protocol)
      buffer
    end
  end
end
