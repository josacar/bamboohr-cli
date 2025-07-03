require "spec"
require "../src/main"

describe "Config" do
  describe "initialization" do
    it "creates a config with all parameters" do
      config = Config.new("testcompany", "testkey", "123")

      config.company_domain.should eq("testcompany")
      config.api_key.should eq("testkey")
      config.employee_id.should eq("123")
    end
  end

  describe "validation" do
    it "validates complete configuration" do
      config = Config.new("testcompany", "testkey", "123")
      config.valid?.should be_true
    end

    it "invalidates empty company domain" do
      config = Config.new("", "testkey", "123")
      config.valid?.should be_false
    end

    it "invalidates empty API key" do
      config = Config.new("testcompany", "", "123")
      config.valid?.should be_false
    end

    it "invalidates empty employee ID" do
      config = Config.new("testcompany", "testkey", "")
      config.valid?.should be_false
    end
  end

  describe "from_app_config" do
    it "converts from AppConfig correctly" do
      app_config = BambooHRCLI::AppConfig.new("testcompany", "testkey", "123")
      config = Config.from_app_config(app_config)

      config.company_domain.should eq("testcompany")
      config.api_key.should eq("testkey")
      config.employee_id.should eq("123")
    end
  end
end

describe "CLIParser" do
  describe "parse" do
    it "returns :interactive for no arguments" do
      result = CLIParser.parse([] of String)
      result.should eq(:interactive)
    end

    it "returns :help for --help" do
      result = CLIParser.parse(["--help"])
      result.should eq(:help)
    end

    it "returns :help for -h" do
      result = CLIParser.parse(["-h"])
      result.should eq(:help)
    end

    it "returns :version for --version" do
      result = CLIParser.parse(["--version"])
      result.should eq(:version)
    end

    it "returns :version for -v" do
      result = CLIParser.parse(["-v"])
      result.should eq(:version)
    end

    it "returns :config_info for --config" do
      result = CLIParser.parse(["--config"])
      result.should eq(:config_info)
    end

    it "returns :config_remove for --config-remove" do
      result = CLIParser.parse(["--config-remove"])
      result.should eq(:config_remove)
    end

    it "returns :unknown for unrecognized single argument" do
      result = CLIParser.parse(["--invalid"])
      result.should eq(:unknown)
    end

    it "returns :unknown for multiple arguments" do
      result = CLIParser.parse(["arg1", "arg2"])
      result.should eq(:unknown)
    end
  end

  describe "show_help" do
    it "displays help without errors" do
      io = IO::Memory.new

      # Should not raise an exception
      CLIParser.show_help(io)

      # Verify help content was written
      output = io.to_s
      output.should contain("BambooHR Time Tracker CLI")
      output.should contain("Usage:")
      output.should contain("--help")
      output.should contain("--config")
      output.should contain("Configuration:")
      output.should contain("XDG Base Directory Specification")
      output.should contain("Environment Variables:")

      # Test passes if no exception is raised
      true.should be_true
    end
  end

  describe "show_version" do
    it "displays version without errors" do
      io = IO::Memory.new

      # Should not raise an exception
      CLIParser.show_version(io)

      # Verify version content was written
      output = io.to_s
      output.should contain("BambooHR Time Tracker CLI v1.0.0")
      output.should contain("Built with Crystal")
      output.should contain("XDG Base Directory Specification")
      output.should contain("Config file:")

      # Test passes if no exception is raised
      true.should be_true
    end
  end
end
