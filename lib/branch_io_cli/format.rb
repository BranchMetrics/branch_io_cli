require "branch_io_cli/format/highline_format"
require "branch_io_cli/format/markdown_format"
require "branch_io_cli/format/shell_format"

module BranchIOCLI
  module Format
    def render(template)
      path = File.expand_path(File.join("..", "..", "assets", "templates", "#{template}.erb"), __FILE__)
      ERB.new(File.read(path)).result binding
    end

    def option(opt)
      highlight "--#{opt.to_s.gsub(/_/, '-')}"
    end
  end
end
