# encoding: UTF-8

module GoodDataMarketo
  VERSION = "0.0.1"

  class << self

    attr_accessor :logging

    def client(config = {})
      GoodDataMarketo.logging = false
      GoodDataMarketo::Client.new(config)
    end

    def freeze(*args) # Bloc freeze args.
      args.each(&:freeze).freeze
    end

    alias :connect :client

  end
end

require 'gooddata_marketo/client'
