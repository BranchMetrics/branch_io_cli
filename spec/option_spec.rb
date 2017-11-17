describe BranchIOCLI::Configuration::Option do
  describe 'initialization' do
    OPTION_CLASS = BranchIOCLI::Configuration::Option

    it 'raises if both :validate_proc and :valid_values are passed' do
      expect do
        OPTION_CLASS.new valid_values_proc: ->() {}, validate_proc: ->(x) {}
      end.to raise_error ArgumentError
    end

    it 'sets negatable to true by default if type is nil' do
      option = OPTION_CLASS.new({})
      expect(option.negatable).to be true
    end

    it 'sets argument_optional to false if type is non-nil and negatable is false' do
      option = OPTION_CLASS.new type: String
      expect(option.argument_optional).to be false
    end

    it 'sets argument_optional to true if negatable is true' do
      option = OPTION_CLASS.new negatable: true
      expect(option.argument_optional).to be true
    end

    it 'sets confirm_symbol to name by default' do
      option = OPTION_CLASS.new name: :foo
      expect(option.confirm_symbol).to eq :foo
    end

    it 'sets aliases to an Array if a scalar is passed' do
      option = OPTION_CLASS.new aliases: "-x"
      expect(option.aliases).to eq %w(-x)
    end

    it 'accepts an Array for aliases' do
      option = OPTION_CLASS.new aliases: %w(-x)
      expect(option.aliases).to eq %w(-x)
    end

    it 'uses name to set env_name by default' do
      option = OPTION_CLASS.new name: :foo
      expect(option.env_name).to eq "BRANCH_FOO"
    end
  end

  describe '#valid_values' do
    it 'calls the valid_values_proc if present' do
      option = OPTION_CLASS.new valid_values_proc: ->() { %w(a b c) }
      expect(option.valid_values).to eq %w(a b c)
    end

    it 'returns nil for valid_values if valid_values_proc is nil' do
      option = OPTION_CLASS.new({})
      expect(option.valid_values).to be_nil
    end
  end

  describe '#ui_type' do
    it 'returns "Comma-separated list" for Array type' do
      option = OPTION_CLASS.new type: Array
      expect(option.ui_type).to eq "Comma-separated list"
    end

    it 'returns "Boolean" for nil type' do
      option = OPTION_CLASS.new({})
      expect(option.ui_type).to eq "Boolean"
    end

    it 'returns the name of the type for any other type' do
      option = OPTION_CLASS.new type: String
      expect(option.ui_type).to eq "String"
    end
  end

  describe '#env_value' do
    it 'returns the value of the named env. var. if set' do
      option = OPTION_CLASS.new env_name: "USER"
      expect(option.env_value).to eq ENV["USER"]
    end

    it 'returns nil if env_name is falsy' do
      option = OPTION_CLASS.new env_name: false
      expect(option.env_value).to be_nil
    end
  end

  describe '#convert' do
    it 'calls a convert_proc if present' do
      option = OPTION_CLASS.new convert_proc: ->(value) { value * 3 }
      expect(option.convert("*")).to eq "***"
    end

    it 'splits a string using commas if the type is Array' do
      option = OPTION_CLASS.new type: Array
      expect(option.convert("a,b")).to eq %w(a b)
    end

    it 'recognizes yes/no true/false for Boolean types' do
      option = OPTION_CLASS.new({})
      expect(option.convert("Yes")).to be true
      expect(option.convert("TRUE")).to be true
      expect(option.convert("yes")).to be true

      expect(option.convert("no")).to be false
      expect(option.convert("False")).to be false
      expect(option.convert("NO")).to be false
    end

    it 'strips strings' do
      option = OPTION_CLASS.new type: String
      expect(option.convert(" abc  ")).to eq "abc"
    end
  end

  describe '#valid?' do
    it 'returns the result of a validate_proc if present' do
      expected = false
      option = OPTION_CLASS.new validate_proc: ->(value) { expected }
      expect(option.valid?(:foo)).to eq expected
    end

    it 'checks #valid_values if non-nil' do
      option = OPTION_CLASS.new valid_values_proc: ->() { %w(a b) }
      expect(option.valid?("a")).to be true
      expect(option.valid?("b")).to be true
      expect(option.valid?("c")).to be false
    end

    it 'checks all values of an Array argument' do
      option = OPTION_CLASS.new type: Array, valid_values_proc: ->() { %w(a b) }
      expect(option.valid?(%w(a))).to be true
      expect(option.valid?(%w(a b))).to be true
      expect(option.valid?(%w(a b c))).to be false
    end

    it 'checks type conformance if type is non-nil' do
      option = OPTION_CLASS.new type: Array
      expect(option.valid?("a")).to be false
      expect(option.valid?(%w(a))).to be true
    end

    it 'checks for Boolean values if type is nil' do
      option = OPTION_CLASS.new({})
      expect(option.valid?(true)).to be true
      expect(option.valid?(false)).to be true
      expect(option.valid?("foo")).to be false
    end
  end
end
