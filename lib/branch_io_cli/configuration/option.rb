module BranchIOCLI
  module Configuration
    class Option
      def self.global_options
        [
          new(
            name: :confirm,
            description: "Enable or disable many prompts",
            default_value: true,
            skip_confirmation: true
          )
        ]
      end

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
      attr_accessor :label
      attr_accessor :skip_confirmation

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
        @negatable = options[:negatable]
        @negatable = options[:type].nil? if options[:negatable].nil?
        @confirm_symbol = options[:confirm_symbol] || @name
        @valid_values_proc = options[:valid_values_proc]
        @validate_proc = options[:validate_proc]
        @convert_proc = options[:convert_proc]
        @label = options[:label] || @name.to_s.capitalize.gsub(/_/, ' ')
        @skip_confirmation = options[:skip_confirmation]

        raise ArgumentError, "Use :validate_proc or :valid_values_proc, but not both." if @valid_values_proc && @validate_proc

        @env_name = "BRANCH_#{@name.to_s.upcase}" if @env_name.nil?
        @argument_optional ||= @negatable
      end

      def valid_values
        return valid_values_proc.call if valid_values_proc && valid_values_proc.kind_of?(Proc)
      end

      def ui_type
        if type.nil?
          "Boolean"
        elsif type == Array
          "Comma-separated list"
        else
          type.to_s
        end
      end

      def env_value
        convert(ENV[env_name]) if env_name
      end

      def convert(value)
        return convert_proc.call(value) if convert_proc

        if type == Array
          value = value.split(",") if value.kind_of?(String)
        elsif type == String && value.kind_of?(String)
          value = value.strip
          value = nil if value.empty?
        elsif type.nil?
          value = true if value.kind_of?(String) && value =~ /^[ty]/i
          value = false if value.kind_of?(String) && value =~ /^[fn]/i
        end

        value
      end

      def display_value(value)
        if type.nil?
          value ? "yes" : "no"
        elsif value.nil?
          "(none)"
        else
          value.to_s
        end
      end

      def valid?(value)
        return validate_proc.call(value) if validate_proc

        return true if value.nil?

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
