module BranchIOCLI
  module Format
    module MarkdownFormat
      include Format

      def header(text, level = 1)
        "#" * level + " #{text}"
      end

      def highlight(text)
        "`#{text}`"
      end

      def italics(text)
        "_#{text}_"
      end

      def table_options
        @command.available_options.map { |o| table_option o }.join("\n")
      end

      def table_option(option)
        text = "|#{option.aliases.join(', ')}"
        text += ", " unless option.aliases.blank?

        text += "--"
        text += "[no-]" if option.negatable
        text += option.name.to_s.gsub(/_/, '-')

        if option.example
          text += " "
          text += "[" if option.argument_optional
          text += option.example
          text += "]" if option.argument_optional
        end

        text += "|#{option.description}"

        if option.type.nil?
          default_value = option.default_value ? "yes" : "no"
        else
          default_value = option.default_value
        end

        if default_value
          text += " (default: #{default_value})"
        end

        text += "|"
        text += option.env_name if option.env_name

        text += "|"
        text
      end

      def render_command(name)
        @command = Object.const_get("BranchIOCLI")
                         .const_get("Command")
                         .const_get("#{name.to_s.capitalize}Command")
        render :command
      end
    end
  end
end
