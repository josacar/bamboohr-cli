require "./bamboohr_cli/version"
require "./bamboohr_cli/config"
require "./bamboohr_cli/api"
require "./bamboohr_cli/cli"
require "colorize"
require "option_parser"

# CLI argument parsing
class CLIParser
  def self.parse(args : Array(String))
    action = :interactive

    parser = OptionParser.new do |parser|
      parser.banner = "Usage: bamboohr-cli [subcommand]"
      parser.on("--config", "Shows config") do
        action = :config_info
      end
      parser.on("--config-remove", "Removes config file") do
        action = :config_remove
      end
      parser.on("-v", "--version", "Show version") do
        action = :version
      end
      parser.on("-h", "--help", "Show this help") do
        action = :help
      end
      parser.invalid_option do |flag|
        action = :unknown
      end
    end

    parser.parse(args)

    action
  end

  def self.show_help(io : IO = STDOUT)
    io.puts "BambooHR Time Tracker CLI"
    io.puts ""
    io.puts "Usage:"
    io.puts "  bamboohr-cli                 Start interactive mode"
    io.puts "  bamboohr-cli --help, -h      Show this help message"
    io.puts "  bamboohr-cli --version, -v   Show version information"
    io.puts "  bamboohr-cli --config        Show configuration file information"
    io.puts "  bamboohr-cli --config-remove Remove saved configuration file"
    io.puts ""
    io.puts "Configuration:"
    io.puts "  The app follows XDG Base Directory Specification for config files."
    io.puts "  Config file location: #{BambooHRCLI::ConfigManager.config_file_path}"
    io.puts ""
    io.puts "  Configuration is loaded in this order:"
    io.puts "  1. User config file (#{BambooHRCLI::ConfigManager.config_file_path})"
    io.puts "  2. System config files (#{BambooHRCLI::ConfigManager.system_config_paths.join(", ")})"
    io.puts "  3. Environment variables (BAMBOOHR_COMPANY, BAMBOOHR_API_KEY, BAMBOOHR_EMPLOYEE_ID)"
    io.puts "  4. Interactive prompts (saved to user config file)"
    io.puts ""
    io.puts "Environment Variables:"
    io.puts "  BAMBOOHR_COMPANY      Your BambooHR company domain"
    io.puts "  BAMBOOHR_API_KEY      Your BambooHR API key"
    io.puts "  BAMBOOHR_EMPLOYEE_ID  Your employee ID"
    io.puts ""
    io.puts "Examples:"
    io.puts "  # First run - will prompt for configuration and save it"
    io.puts "  bamboohr-cli"
    io.puts ""
    io.puts "  # Using environment variables (bypasses config file)"
    io.puts "  export BAMBOOHR_COMPANY=mycompany"
    io.puts "  export BAMBOOHR_API_KEY=your_api_key"
    io.puts "  export BAMBOOHR_EMPLOYEE_ID=123"
    io.puts "  bamboohr-cli"
    io.puts ""
    io.puts "  # Check configuration status"
    io.puts "  bamboohr-cli --config"
  end

  def self.show_version(io : IO = STDOUT)
    io.puts "BambooHR Time Tracker CLI v#{BambooHRCLI::VERSION}"
    io.puts "Built with Crystal #{Crystal::VERSION}"
    io.puts ""
    io.puts "Configuration: XDG Base Directory Specification compliant"
    io.puts "Config file: #{BambooHRCLI::ConfigManager.config_file_path}"
  end
end

# Main execution (only run if not being required for testing)
unless PROGRAM_NAME.includes?("crystal-run-spec")
  begin
    puts "🚀 Starting BambooHR Clock CLI...".colorize(:green)

    # Parse command line arguments
    action = CLIParser.parse(ARGV)

    case action
    when :help
      CLIParser.show_help
      exit 0
    when :version
      CLIParser.show_version
      exit 0
    when :config_info
      BambooHRCLI::ConfigManager.show_config_info
      exit 0
    when :config_remove
      print "Are you sure you want to remove the configuration file? [y/N]: "
      response = gets.try(&.strip.downcase) || "n"
      if response == "y" || response == "yes"
        BambooHRCLI::ConfigManager.remove_config
      else
        puts "Configuration file not removed."
      end
      exit 0
    when :unknown
      puts "❌ Unknown command. Use --help for usage information.".colorize(:red)
      exit 1
    when :interactive
      # Continue with interactive mode
    end

    # Get configuration using XDG-compliant manager
    config = BambooHRCLI::ConfigManager.get_config

    unless config.valid?
      puts "❌ Invalid configuration. Please check your settings.".colorize(:red)
      exit 1
    end

    # Create and run CLI
    cli = BambooHRCLI::CLI.new(config.company_domain, config.api_key, config.employee_id)

    # Handle Ctrl+C gracefully
    Signal::INT.trap do
      cli.cleanup
      puts "\n👋 Goodbye!".colorize(:yellow)
      exit 0
    end

    cli.run_interactive
  rescue ex
    puts "💥 Fatal error: #{ex.message}".colorize(:red)
    exit 1
  end
end
