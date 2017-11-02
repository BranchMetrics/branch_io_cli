require "open3"

class IO
  def report_command(command)
    if self == STDOUT
      # TODO: Improve this.
      say "<%= color('$ #{command}', BOLD) %>\n\n"
    else
      write "$ #{command}\n\n"
    end

    Open3.popen2e(command) do |stdin, output, thread|
      write output.read
    end
    write "\n\n"

    status = $?.exitstatus
    write "#{command} returned #{status}." unless status == 0
  end
end
