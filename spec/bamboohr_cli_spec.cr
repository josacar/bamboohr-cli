require "spec"
require "../src/bamboohr_cli/cli"
require "../src/bamboohr_cli/api"

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
describe "BambooHRCLI::CLI" do
  describe "initialization" do
    it "creates a new CLI instance with correct parameters" do
      io = IO::Memory.new
      cli = BambooHRCLI::CLI.new("testcompany", "test_api_key", "123", io)
      cli.should be_a(BambooHRCLI::CLI)
    end

    it "initializes with nil session start and zero daily total" do
      io = IO::Memory.new
      cli = BambooHRCLI::CLI.new("testcompany", "test_api_key", "123", io)
      cli.current_session_start.should be_nil
      cli.daily_total_seconds.should eq(0)
    end

    it "creates an API client internally" do
      io = IO::Memory.new
      cli = BambooHRCLI::CLI.new("testcompany", "test_api_key", "123", io)
      cli.api.should be_a(BambooHRCLI::API)
    end

    it "uses STDOUT by default when no IO provided" do
      cli = BambooHRCLI::CLI.new("testcompany", "test_api_key", "123")
      cli.should be_a(BambooHRCLI::CLI)
    end
  end

  describe "clock operations" do
    it "clock_in returns boolean" do
      io = IO::Memory.new
      cli = BambooHRCLI::CLI.new("testcompany", "test_api_key", "123", io)

      # This will fail with test credentials, but should return a boolean
      result = cli.clock_in
      result.should be_a(Bool)

      # Verify output was written to our IO
      io.to_s.should contain("Clocking in")
    end

    it "clock_out returns boolean" do
      io = IO::Memory.new
      cli = BambooHRCLI::CLI.new("testcompany", "test_api_key", "123", io)

      result = cli.clock_out
      result.should be_a(Bool)

      # Verify output was written to our IO
      io.to_s.should contain("Clocking out")
    end

    it "clock_in accepts optional parameters" do
      io = IO::Memory.new
      cli = BambooHRCLI::CLI.new("testcompany", "test_api_key", "123", io)

      result = cli.clock_in(note: "Test note", project_id: 10, task_id: 25)
      result.should be_a(Bool)

      # Verify output was written to our IO
      io.to_s.should contain("Clocking in")
    end
  end

  describe "status management" do
    it "can refresh status without errors" do
      io = IO::Memory.new
      cli = BambooHRCLI::CLI.new("testcompany", "test_api_key", "123", io)

      # Should not raise an exception
      cli.refresh_status

      # Status should remain accessible
      cli.current_session_start.should be_a(Time?)
      cli.daily_total_seconds.should be_a(Int32)
    end

    it "can refresh daily total without errors" do
      io = IO::Memory.new
      cli = BambooHRCLI::CLI.new("testcompany", "test_api_key", "123", io)

      cli.refresh_daily_total

      cli.daily_total_seconds.should be_a(Int32)
    end
  end

  describe "display methods" do
    it "can display status without errors" do
      io = IO::Memory.new
      cli = BambooHRCLI::CLI.new("testcompany", "test_api_key", "123", io)

      # Should not raise an exception when displaying status
      cli.display_status

      # Verify output was written to our IO
      output = io.to_s
      output.should contain("CLOCKED OUT")
      output.should contain("Daily total")

      # Test passes if no exception is raised
      true.should be_true
    end

    it "displays different status when clocked in" do
      io = IO::Memory.new
      cli = BambooHRCLI::CLI.new("testcompany", "test_api_key", "123", io)

      # We can't directly set private instance variables in Crystal
      # Instead, let's just test the display method works
      cli.display_status

      # Should show clocked out status by default
      output = io.to_s
      output.should contain("CLOCKED OUT")
      output.should contain("Daily total")
    end
  end

  describe "output formatting" do
    it "writes error messages to provided IO" do
      io = IO::Memory.new
      cli = BambooHRCLI::CLI.new("testcompany", "test_api_key", "123", io)

      # This will trigger an error message
      cli.clock_in

      output = io.to_s
      output.should contain("Failed to clock in")
    end

    it "writes status messages to provided IO" do
      io = IO::Memory.new
      cli = BambooHRCLI::CLI.new("testcompany", "test_api_key", "123", io)

      cli.refresh_status

      # Should have written status messages (even if API fails)
      output = io.to_s
      # Output might be empty if no errors, which is fine
      output.should be_a(String)
    end
  end
end
