module BranchIOCLI
  module Configuration
    class Option
      attr_accessor :name
      attr_accessor :type
      attr_accessor :description
      attr_accessor :default_value
      attr_accessor :example
      attr_accessor :argument_optional
      attr_accessor :aliases
      attr_accessor :negatable

      def initialize(options)
        @name = options[:name]
        @type = options[:type]
        @description = options[:description]
        @default_value = options[:default_value]
        @example = options[:example]
        @argument_optional = options[:argument_optional] || false
        @aliases = options[:aliases] || []
        @aliases = [@aliases] unless @aliases.kind_of?(Array)
        @negatable = options[:type].nil? if options[:negatable].nil?

        @argument_optional ||= @negatable
      end
    end
  end
end
