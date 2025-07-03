require "colorize"
require "./bamboohr_cli"

# Legacy Config struct for backward compatibility
struct Config
  property company_domain : String
  property api_key : String
  property employee_id : String

  def initialize(@company_domain : String, @api_key : String, @employee_id : String)
  end

  def self.from_app_config(app_config : BambooHRCLI::AppConfig)
    new(app_config.company_domain, app_config.api_key, app_config.employee_id)
  end

  def valid?
    !company_domain.empty? && !api_key.empty? && !employee_id.empty?
  end
end

# CLI argument parsing
class CLIParser
  def self.parse(args : Array(String))
    case args.size
    when 0
      # Interactive mode
      :interactive
    when 1
      case args[0]
      when "--help", "-h"
        :help
      when "--version", "-v"
        :version
      when "--config"
        :config_info
      when "--config-remove"
        :config_remove
      else
        :unknown
      end
    else
      :unknown
    end
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
    app_config = BambooHRCLI::ConfigManager.get_config

    unless app_config.valid?
      puts "❌ Invalid configuration. Please check your settings.".colorize(:red)
      exit 1
    end

    # Convert to legacy Config for compatibility
    config = Config.from_app_config(app_config)

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
