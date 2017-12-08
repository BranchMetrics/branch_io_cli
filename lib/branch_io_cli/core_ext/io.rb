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
  say "<%= color(%q{$ #{IO.command_from_args(*args)}}, [MAGENTA, BOLD]) %>\n\n"
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

def IO.command_from_args(*args)
  raise ArgumentError, "sh requires at least one argument" unless args.count > 0

  # Ignore any trailing options in the output
  args.pop if args.last.kind_of?(Hash)

  command = ""

  # Optional initial environment Hash
  if args.first.kind_of?(Hash)
    command = args.shift.map { |k, v| "#{k}=#{v.shellescape}" }.join(" ") + " "
  end

  # Support [ "/usr/local/bin/foo", "foo" ], "-x", ...
  if args.first.kind_of?(Array)
    command += args.shift.first.shellescape + " " + args.shelljoin
    command.chomp! " "
  elsif args.count == 1 && args.first.kind_of?(String)
    command += args.first
  else
    command += args.shelljoin
  end

  command
end
