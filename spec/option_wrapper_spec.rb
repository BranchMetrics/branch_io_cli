describe BranchIOCLI::Configuration::OptionWrapper do
  WRAPPER_CLASS = BranchIOCLI::Configuration::OptionWrapper
  let (:options) do
    [
      BranchIOCLI::Configuration::Option.new(
        name: :foo,
        default_value: "bar",
        env_name: "FOO",
        type: String
      )
    ]
  end

  before :each do
    ENV["FOO"] = nil
  end

  it 'returns the value of any valid key in a hash supplied to the initializer as a method' do
    wrapper = WRAPPER_CLASS.new({ foo: "bar" }, options)

    expect(wrapper.foo).to eq "bar"
    expect do
      wrapper.bar
    end.to raise_error NoMethodError
  end

  it 'adds defaults if add_defaults is true' do
    wrapper = WRAPPER_CLASS.new({}, options)
    expect(wrapper.foo).to eq "bar"
  end

  it 'consults any env_value before default_value' do
    ENV["FOO"] = "y"
    wrapper = WRAPPER_CLASS.new({}, options)
    expect(wrapper.foo).to eq "y"
  end

  it 'does not consult the environment or default_value if add_defaults is false' do
    ENV["FOO"] = "y"
    wrapper = WRAPPER_CLASS.new({}, options, false)
    expect(wrapper.foo).to be_nil
  end
end
