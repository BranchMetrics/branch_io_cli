module BranchIOCLI
  module Format
    module MarkdownFormat
      include Format

      def header(text, level=1)
        "#" * level + " #{text}"
      end

      def highlight(text)
        "`#{text}`"
      end

      def table_option(option)
        text = "|#{option.aliases.join(', ')}"

        text += "--"
        text += "[no-]" if option.negatable
        text += "#{option.name.to_s.gsub(/_/, '-')} "

        text += "[" if option.argument_optional
        text += option.example if option.example
        text += "]" if option.argument_optional

        text += "|#{option.description}"
        if option.default_value
          text += " (default: #{option.default_value})"
        end
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
