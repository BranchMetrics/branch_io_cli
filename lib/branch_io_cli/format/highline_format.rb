require "erb"

module BranchIOCLI
  module Format
    module HighlineFormat
      include Format

      def header(text, level = 1)
        highlight text
      end

      def highlight(text)
        "<%= color('#{text}', BOLD) %>"
      end

      def italics(text)
        highlight text
      end
    end
  end
end
