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
      attr_accessor :confirm_symbol
      attr_accessor :valid_values_proc
      attr_accessor :validate_proc
      attr_accessor :convert_proc

      def initialize(options)
        @name = options[:name]
        @env_name = options[:env_name]
        @type = options[:type]
        @description = options[:description]
        @default_value = options[:default_value]
        @example = options[:example]
        @argument_optional = options[:argument_optional] || false
        @aliases = options[:aliases] || []
        @aliases = [@aliases] unless @aliases.kind_of?(Array)
        @negatable = options[:type].nil? if options[:negatable].nil?
        @confirm_symbol = options[:confirm_symbol] || @name
        @valid_values_proc = options[:valid_values_proc]
        @validate_proc = options[:validate_proc]
        @convert_proc = options[:convert_proc]

        raise ArgumentError, "Use :validate_proc or :valid_values_proc, but not both." if @valid_values_proc && @validate_proc

        @env_name = "BRANCH_#{@name.to_s.upcase}" if @env_name.nil?
        @argument_optional ||= @negatable
      end

      def valid_values
        if valid_values_proc && valid_values_proc.kind_of?(Proc)
          valid_values_proc.call
        elsif type.nil?
          [true, false]
        end
      end

      def ui_type
        case type
        when nil
          "Boolean"
        when Array
          "Comma-separated list"
        else
          type.to_s
        end
      end

      def env_value
        return nil unless env_name
        convert ENV[env_name]
      end

      def convert(value)
        return convert_proc.call(value) if convert_proc

        case type
        when Array
          value = value.split(",") if value.kind_of?(String)
        when String
          value = value.strip
        when nil
          value = true if value.kind_of?(String) && value =~ /^(true|yes)$/i
          value = false if value.kind_of?(String) && value =~ /^(false|no)$/i
        end

        value
      end

      def valid?(value)
        return validate_proc.call(value) if validate_proc

        value = convert value
        if valid_values && type != Array
          valid_values.include? value
        elsif valid_values
          value.all? { |v| valid_values.include?(v) }
        elsif type
          value.kind_of? type
        else
          value == true || value == false
        end
      end
    end
  end
end
