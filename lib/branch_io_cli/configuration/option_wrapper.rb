module BranchIOCLI
  module Configuration
    # Proxy class for use with Command.new.
    class OptionWrapper
      attr_reader :hash
      attr_reader :options
      attr_reader :add_defaults

      def initialize(hash, options, add_defaults = true)
        raise ArgumentError if hash.nil?

        @hash = hash
        @options = options
        @add_defaults = add_defaults

        build_option_hash
      end

      def method_missing(method_sym, *arguments, &block)
        option = @option_hash[method_sym]
        return super unless option

        value = hash[method_sym]
        return value unless add_defaults && value.nil?
        option.default_value
      end

      def build_option_hash
        @option_hash = options.inject({}) { |hash, o| hash.merge o.name => o }
      end
    end
  end
end
