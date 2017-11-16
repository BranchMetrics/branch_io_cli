require "erb"

module BranchIOCLI
  module Format
    module CommanderFormat
      include Format

      def header(text, level = 1)
        highlight text
      end

      def highlight(text)
        "<%= color('#{text}', BOLD) %>"
      end
    end
  end
end
