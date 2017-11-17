module BranchIOCLI
  module Configuration
    class Option
      attr_accessor :name
      attr_accessor :env_name
      attr_accessor :type
      attr_accessor :description
      attr_accessor :default_value
      attr_accessor :example
      attr_accessor :argument_optional
      attr_accessor :aliases
      attr_accessor :negatable

      def initialize(options)
        @name = options[:name]
        @env_name = options[:env_name]
        @env_name = "BRANCH_#{@name.to_s.upcase}" if @env_name.nil?

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

      def env_value
        return nil unless env_name
        default_value = ENV[env_name]
        default_value = default_value.split(",") if type == Array && default_value.kind_of?(String)
        if type.nil? && default_value.kind_of?(String)
          default_value = true if default_value =~ /^(true|yes)$/i
          default_value = false if default_value =~ /^(false|no)$/i
        end
        default_value
      end
    end
  end
end
