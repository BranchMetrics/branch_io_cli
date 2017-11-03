require "open3"

class IO
  # Report the command. Execute the command, capture stdout
  # and stderr and report line by line. Report the exit
  # status at the end in case of error. Returns a Process::Status
  # object.
  #
  # :command: [String] a shell command to execute and report
  def report_command(command)
    write "$ #{command}\n\n"

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

# Report the command. Execute the command. Stdout and stderr are
# not redirected. Report the exit status at the end if nonzero.
# Returns a Process::Status object.
#
# :command: [String] a shell command to execute and report
def STDOUT.report_command(command)
  # TODO: Improve this implementation?
  say "<%= color(%q{$ #{command}}, [MAGENTA, BOLD]) %>\n\n"
  # May also write to stderr
  # Could try system "#{command} 2>&1", but that might depend on the shell.
  system command

  status = $?
  if status == 0
    write "Success.\n\n"
  else
    write "#{status}\n\n"
  end
  status
end
