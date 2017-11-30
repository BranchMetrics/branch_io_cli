class Regexp
  def match_file(file)
    case file
    when File
      contents = file.read
    when String
      contents = File.read file
    else
      raise ArgumentError, "Invalid argument type: #{file.class.name}"
    end

    match contents
  end

  def match_file?(file)
    !match_file(file).nil?
  end
end
