require_relative "format/highline_format"
require_relative "format/markdown_format"
require_relative "format/shell_format"

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
