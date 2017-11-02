require "open3"

class IO
  def report_command(command)
    if self == STDOUT
      # TODO: Improve this?
      say "<%= color('$ #{command}', BOLD) %>\n\n"
    else
      write "$ #{command}\n\n"
    end

    Open3.popen2e(command) do |stdin, output, thread|
      # output is stdout and stderr merged
      while (line = output.gets)
        puts line
      end

      status = thread.value
      if status == 0
        write "Success.\n\n"
      else
        write "#{status}\n\n"
      end

      return status
    end
  end
end
