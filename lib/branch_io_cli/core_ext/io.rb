require "open3"
require "shellwords"

class IO
  # Report the command. Execute the command, capture stdout
  # and stderr and report line by line. Report the exit
  # status at the end in case of error. Returns a Process::Status
  # object.
  #
  # @param command a shell command to execute and report
  def sh(*args)
    write "$ #{command_from_args(*args)}\n\n"

    Open3.popen2e(*args) do |stdin, output, thread|
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
# @param command a shell command to execute and report
def STDOUT.sh(*args)
  # TODO: Improve this implementation?
  say "<%= color(%q{$ #{command_from_args(*args)}}, [MAGENTA, BOLD]) %>\n\n"
  # May also write to stderr
  system(*args)

  status = $?
  if status == 0
    write "Success.\n\n"
  else
    write "#{status}\n\n"
  end
  status
end

def command_from_args(*args)
  args.pop if args.last.kind_of?(Hash)
  args.shift if args.first.kind_of?(Hash)

  if args.count == 1
    command = args.first
    command = command.shelljoin if command.kind_of? Array
  else
    command = args.shelljoin
  end
  command
end
