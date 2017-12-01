describe 'IO extension' do
  describe 'command_from_args' do
    it 'returns the string when a string is passed' do
      command = IO.command_from_args "git commit -m 'A message'"
      expect(command).to eq "git commit -m 'A message'"
    end

    it 'raises when no argument passed' do
      expect do
        IO.command_from_args
      end.to raise_error ArgumentError
    end

    it 'ignores any trailing options hash' do
      command = IO.command_from_args "git commit -m 'A message'", chdir: "/tmp"
      expect(command).to eq "git commit -m 'A message'"
    end

    it 'shelljoins multiple args' do
      command = IO.command_from_args "git", "commit", "-m", "A message"
      expect(command).to eq 'git commit -m A\ message'
    end

    it 'adds an environment Hash at the beginning' do
      command = IO.command_from_args({ "PATH" => "/usr/local/bin" }, "git", "commit", "-m", "A message")
      expect(command).to eq 'PATH=/usr/local/bin git commit -m A\ message'
    end

    it 'shell-escapes environment variable values' do
      command = IO.command_from_args({ "PATH" => "/usr/my local/bin" }, "git", "commit", "-m", "A message")
      expect(command).to eq 'PATH=/usr/my\ local/bin git commit -m A\ message'
    end

    it 'recognizes an array as the only element of a command' do
      command = IO.command_from_args ["/usr/local/bin/git", "git"]
      expect(command).to eq "/usr/local/bin/git"
    end

    it 'recognizes an array as the first element of a command' do
      command = IO.command_from_args ["/usr/local/bin/git", "git"], "commit", "-m", "A message"
      expect(command).to eq '/usr/local/bin/git commit -m A\ message'
    end
  end
end
