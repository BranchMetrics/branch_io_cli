describe BranchIOCLI::Configuration::OptionWrapper do
  WRAPPER_CLASS = BranchIOCLI::Configuration::OptionWrapper
  let (:options) do
    [
      BranchIOCLI::Configuration::Option.new(name: :foo, default_value: "bar")
    ]
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
end
