require "erb"

module BranchIOCLI
  module Format
    module CommanderFormat
      include Format

      def option(opt)
        highlight "--#{opt.to_s.gsub(/_/, '-')}"
      end

      def header(text)
        highlight text
      end

      def highlight(text)
        "<%= color('#{text}', BOLD) %>"
      end
    end
  end
end
