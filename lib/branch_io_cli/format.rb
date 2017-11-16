require "branch_io_cli/format/commander_format"

module BranchIOCLI
  module Format
    def render(template)
      path = File.expand_path(File.join("..", "..", "assets", "commands", "#{template}.erb"), __FILE__)
      ERB.new(File.read(path)).result binding
    end
  end
end
