describe 'Xcodeproj extensions' do
  describe 'PBNativeTarget#expanded_build_setting' do
    let (:project) do
      double :project
    end

    let (:target) do
      expect(project).to receive(:mark_dirty!)
      t = Xcodeproj::Project::Object::PBXNativeTarget.new(project, nil)
      t.name = "MyTarget"
      t
    end

    it "expands values delimited by $()" do
      expect(target).to receive(:resolved_build_setting).with("SETTING_WITH_NESTED_VALUE", true) { { "Release" => "$(SETTING_VALUE)" } }
      expect(target).to receive(:resolved_build_setting).with("SETTING_VALUE", true) { { "Release" => "value" } }
      expect(target.expanded_build_setting("SETTING_WITH_NESTED_VALUE", "Release")).to eq "value"
    end

    it "expands values delimited by ${}" do
      expect(target).to receive(:resolved_build_setting).with("SETTING_WITH_NESTED_VALUE", true) { { "Release" => "${SETTING_VALUE}" } }
      expect(target).to receive(:resolved_build_setting).with("SETTING_VALUE", true) { { "Release" => "value" } }
      expect(target.expanded_build_setting("SETTING_WITH_NESTED_VALUE", "Release")).to eq "value"
    end

    it "expands an all-caps word as a setting" do
      expect(target).to receive(:resolved_build_setting).with("SETTING_WITH_NESTED_VALUE", true) { { "Release" => "SETTING_VALUE" } }
      expect(target).to receive(:resolved_build_setting).with("SETTING_VALUE", true) { { "Release" => "value" } }
      expect(target.expanded_build_setting("SETTING_WITH_NESTED_VALUE", "Release")).to eq "value"
    end

    it "expands the first component of a path as a setting if all-caps" do
      expect(target).to receive(:resolved_build_setting).with("SETTING_WITH_NESTED_VALUE", true) { { "Release" => "SETTING_VALUE/file.txt" } }
      expect(target).to receive(:resolved_build_setting).with("SETTING_VALUE", true) { { "Release" => "value" } }
      expect(target.expanded_build_setting("SETTING_WITH_NESTED_VALUE", "Release")).to eq "value/file.txt"
    end

    it "resolves without an xcconfig if the xcconfig is not found" do
      expect(target).to receive(:resolved_build_setting).with("SETTING_WITH_NESTED_VALUE", true).and_raise(Errno::ENOENT)
      expect(target).to receive(:resolved_build_setting).with("SETTING_WITH_NESTED_VALUE", false) { { "Release" => "$(SETTING_VALUE)" } }
      expect(target).to receive(:resolved_build_setting).with("SETTING_VALUE", true) { { "Release" => "value" } }
      expect(target.expanded_build_setting("SETTING_WITH_NESTED_VALUE", "Release")).to eq "value"
    end

    it "returns nil if the setting is not present" do
      expect(target).to receive(:resolved_build_setting).with("NONEXISTENT_SETTING", true) { { "Release" => nil } }
      expect(BranchIOCLI::Configuration::XcodeSettings).to receive(:[]).with("Release") { {} }
      expect(target.expanded_build_setting("NONEXISTENT_SETTING", "Release")).to be_nil
    end

    it "substitutes . for $(SRCROOT)" do
      expect(target).to receive(:resolved_build_setting).with("SETTING_USING_SRCROOT", true) { { "Release" => "$(SRCROOT)/some.file" } }
      expect(target.expanded_build_setting("SETTING_USING_SRCROOT", "Release")).to eq "./some.file"
    end

    it "subsitutes the target name for $(TARGET_NAME)" do
      expect(target).to receive(:resolved_build_setting).with("SETTING_USING_TARGET_NAME", true) { { "Release" => "$(TARGET_NAME)" } }
      expect(target.expanded_build_setting("SETTING_USING_TARGET_NAME", "Release")).to eq target.name
    end

    it "returns the setting when no macro present" do
      expect(target).to receive(:resolved_build_setting).with("SETTING_WITHOUT_MACRO", true) { { "Release" => "setting" } }
      expect(target.expanded_build_setting("SETTING_WITHOUT_MACRO", "Release")).to eq "setting"
    end

    it "expands multiple instances of the same macro" do
      expect(target).to receive(:resolved_build_setting).with("SETTING_WITH_NESTED_VALUE", true) { { "Release" => "$(SETTING_VALUE).$(SETTING_VALUE)" } }
      expect(target).to receive(:resolved_build_setting).with("SETTING_VALUE", true) { { "Release" => "value" } }
      expect(target.expanded_build_setting("SETTING_WITH_NESTED_VALUE", "Release")).to eq "value.value"
    end

    it "expands multiple macros in a setting" do
      expect(target).to receive(:resolved_build_setting).with("SETTING_WITH_NESTED_VALUES", true) { { "Release" => "$(SETTING_VALUE1).$(SETTING_VALUE2)" } }
      expect(target).to receive(:resolved_build_setting).with("SETTING_VALUE1", true) { { "Release" => "value1" } }
      expect(target).to receive(:resolved_build_setting).with("SETTING_VALUE2", true) { { "Release" => "value2" } }
      expect(target.expanded_build_setting("SETTING_WITH_NESTED_VALUES", "Release")).to eq "value1.value2"
    end

    it "balances delimiters" do
      expect(target).to receive(:resolved_build_setting).with("SETTING_WITH_NESTED_VALUES", true) { { "Release" => "$(SETTING_VALUE1}.${SETTING_VALUE2)" } }
      expect(target.expanded_build_setting("SETTING_WITH_NESTED_VALUES", "Release")).to eq "$(SETTING_VALUE1}.${SETTING_VALUE2)"
    end

    it "expands recursively" do
      expect(target).to receive(:resolved_build_setting).with("SETTING_WITH_NESTED_VALUES", true) { { "Release" => "$(SETTING_VALUE1)" } }
      expect(target).to receive(:resolved_build_setting).with("SETTING_VALUE1", true) { { "Release" => "$(SETTING_VALUE2)" } }
      expect(target).to receive(:resolved_build_setting).with("SETTING_VALUE2", true) { { "Release" => "value2" } }
      expect(target.expanded_build_setting("SETTING_WITH_NESTED_VALUES", "Release")).to eq "value2"
    end

    it "returns the unexpanded macro for nonexistent settings" do
      expect(target).to receive(:resolved_build_setting).with("SETTING_WITH_BOGUS_VALUE", true) { { "Release" => "$(SETTING_VALUE1).$(SETTING_VALUE2)" } }
      expect(target).to receive(:resolved_build_setting).with("SETTING_VALUE1", true) { { "Release" => nil } }
      expect(target).to receive(:resolved_build_setting).with("SETTING_VALUE2", true) { { "Release" => "value2" } }
      expect(BranchIOCLI::Configuration::XcodeSettings).to receive(:[]).with("Release") { {} }
      expect(target.expanded_build_setting("SETTING_WITH_BOGUS_VALUE", "Release")).to eq "$(SETTING_VALUE1).value2"
    end

    it "recognizes :rfc1034identifier when expanding" do
      expect(target).to receive(:resolved_build_setting).with("PRODUCT_NAME", true) { { "Release" => "My App" } }
      expect(target).to receive(:resolved_build_setting).with("PRODUCT_BUNDLE_IDENTIFIER", true) { { "Release" => "com.example.$(PRODUCT_NAME:rfc1034identifier)" } }
      expect(target.expanded_build_setting("PRODUCT_BUNDLE_IDENTIFIER", "Release")).to eq "com.example.My-App"
    end

    it "ignores any other modifier" do
      expect(target).to receive(:resolved_build_setting).with("PRODUCT_NAME", true) { { "Release" => "My App" } }
      expect(target).to receive(:resolved_build_setting).with("PRODUCT_BUNDLE_IDENTIFIER", true) { { "Release" => "com.example.$(PRODUCT_NAME:foo)" } }
      expect(target.expanded_build_setting("PRODUCT_BUNDLE_IDENTIFIER", "Release")).to eq "com.example.My App"
    end

    it "substitutes - for special characters when :rfc1034identifier is present" do
      expect(target).to receive(:resolved_build_setting).with("PRODUCT_NAME", true) { { "Release" => "My .@*&'\\\"+%_App" } }
      expect(target).to receive(:resolved_build_setting).with("PRODUCT_BUNDLE_IDENTIFIER", true) { { "Release" => "com.example.$(PRODUCT_NAME:rfc1034identifier)" } }
      expect(target.expanded_build_setting("PRODUCT_BUNDLE_IDENTIFIER", "Release")).to eq "com.example.My-----------App"
    end

    it "expands against Xcode settings when setting not found for target" do
      expect(target).to receive(:resolved_build_setting).with("PROJECT_NAME", true) { { "Release" => nil } }
      expect(BranchIOCLI::Configuration::XcodeSettings).to receive(:[]).with("Release") { { "PROJECT_NAME" => "MyProject" } }
      expect(target.expanded_build_setting("PROJECT_NAME", "Release")).to eq "MyProject"
    end
  end
end
