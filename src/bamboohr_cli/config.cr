require "yaml"
require "file_utils"
require "colorize"
require "term-prompt"

module BambooHRCLI
  # Configuration structure that maps to YAML
  struct AppConfig
    include YAML::Serializable

    property company_domain : String
    property api_key : String
    property employee_id : String

    def initialize(@company_domain : String, @api_key : String, @employee_id : String)
    end

    def valid?
      !company_domain.empty? && !api_key.empty? && !employee_id.empty?
    end
  end

  module FileSystemInterface
    abstract def write(path : String | Path, content : String) : Nil
    abstract def read(path : String | Path) : String
    abstract def delete(path : String | Path) : Nil
    abstract def exists?(path : String | Path) : Bool
    abstract def chmod(path : String | Path, mode : Int | File::Permissions) : Nil
    abstract def info(path : Path | String, follow_symlinks = true) : File::Info
  end


  # XDG-compliant configuration manager
  class ConfigManager
    class LocalFileSystem
      extend FileSystemInterface

      def self.write(path : String | Path, content : String) : Nil
        File.write(path, content)
      end

      def self.read(path : String | Path) : String
        File.read(path)
      end

      def self.delete(path : String | Path) : Nil
        File.delete(path)
      end

      def self.exists?(path : String | Path) : Bool
        File.exists?(path)
      end

      def self.chmod(path : String | Path, mode : Int | File::Permissions) : Nil
        File.chmod(path, mode)
      end

      def self.info(path : Path | String, follow_symlinks = true) : File::Info
        File.info(path, follow_symlinks)
      end
    end

    APP_NAME    = "bamboohr-cli"
    CONFIG_FILE = "config.yml"

    # XDG Base Directory Specification paths
    def self.xdg_config_home : String
      ENV["XDG_CONFIG_HOME"]? || Path.home.join(".config").to_s
    end

    def self.xdg_config_dirs : Array(String)
      dirs = ENV["XDG_CONFIG_DIRS"]?.try(&.split(":")) || ["/etc/xdg"]
      dirs.map { |dir| Path[dir].expand.to_s }
    end

    def self.config_dir : String
      File.join(xdg_config_home, APP_NAME)
    end

    def self.config_file_path : String
      File.join(config_dir, CONFIG_FILE)
    end

    def self.system_config_paths : Array(String)
      xdg_config_dirs.map { |dir| File.join(dir, APP_NAME, CONFIG_FILE) }
    end

    # Load configuration from XDG-compliant locations
    def self.load_config(io : IO = STDOUT) : AppConfig?
      # Try user config first
      if LocalFileSystem.exists?(config_file_path)
        io.puts "📁 Loading configuration from #{config_file_path}".colorize(:cyan)
        return load_config_file(config_file_path)
      end

      # Try system config locations
      system_config_paths.each do |path|
        if LocalFileSystem.exists?(path)
          io.puts "📁 Loading system configuration from #{path}".colorize(:cyan)
          return load_config_file(path)
        end
      end

      # No config file found
      nil
    end

    # Load and parse a specific config file
    private def self.load_config_file(path : String) : AppConfig?
      begin
        yaml_content = LocalFileSystem.read(path)
        AppConfig.from_yaml(yaml_content)
      rescue ex : YAML::ParseException
        STDERR.puts "❌ Error parsing config file #{path}: #{ex.message}".colorize(:red)
        nil
      rescue ex : File::NotFoundError
        nil
      rescue ex
        STDERR.puts "❌ Error reading config file #{path}: #{ex.message}".colorize(:red)
        nil
      end
    end

    # Save configuration to user config directory
    def self.save_config(config : AppConfig, io : IO = STDOUT) : Bool
      begin
        # Ensure config directory exists
        FileUtils.mkdir_p(config_dir)

        # Generate YAML content with comments
        yaml_content = generate_config_yaml(config)

        # Write to file
        LocalFileSystem.write(config_file_path, yaml_content)

        # Set appropriate permissions (readable by user only)
        LocalFileSystem.chmod(config_file_path, 0o600)

        io.puts "💾 Configuration saved to #{config_file_path}".colorize(:green)
        true
      rescue ex
        STDERR.puts "❌ Error saving config file: #{ex.message}".colorize(:red)
        false
      end
    end

    # Generate YAML content with helpful comments
    private def self.generate_config_yaml(config : AppConfig) : String
      String.build do |str|
        str << "# BambooHR CLI Configuration\n"
        str << "# This file stores your BambooHR API credentials\n"
        str << "# Location: #{config_file_path}\n"
        str << "# \n"
        str << "# Your BambooHR company domain (e.g., 'mycompany' for mycompany.bamboohr.com)\n"
        str << "company_domain: #{config.company_domain.inspect}\n"
        str << "\n"
        str << "# Your BambooHR API key (generate from Settings > API Keys in BambooHR)\n"
        str << "api_key: #{config.api_key.inspect}\n"
        str << "\n"
        str << "# Your employee ID (found in your BambooHR profile URL)\n"
        str << "employee_id: #{config.employee_id.inspect}\n"
      end
    end

    # Prompt user for configuration values using term-prompt for secure input
    def self.prompt_for_config(io : IO = STDOUT) : AppConfig
      io.puts "🔧 BambooHR CLI Configuration Setup".colorize(:yellow).bold
      io.puts "No configuration file found. Let's set up your BambooHR credentials."
      io.puts

      prompt = Term::Prompt.new(output: io)

      # Regular input for company domain
      company_domain = ""
      loop do
        result = prompt.ask("Enter your BambooHR company domain (e.g., 'mycompany' for mycompany.bamboohr.com):")
        if result && !result.strip.empty?
          company_domain = result.strip
          break
        end
        io.puts "❌ Value cannot be empty. Please try again.".colorize(:red)
      end

      # Secure masked input for API key
      api_key = ""
      loop do
        result = prompt.mask("Enter your BambooHR API key (generate from Settings > API Keys in BambooHR):")
        if result && !result.strip.empty?
          api_key = result.strip
          break
        end
        io.puts "❌ Value cannot be empty. Please try again.".colorize(:red)
      end

      # Regular input for employee ID
      employee_id = ""
      loop do
        result = prompt.ask("Enter your employee ID (found in your BambooHR profile URL):")
        if result && !result.strip.empty?
          employee_id = result.strip
          break
        end
        io.puts "❌ Value cannot be empty. Please try again.".colorize(:red)
      end

      AppConfig.new(company_domain, api_key, employee_id)
    end

    # Get configuration from environment variables (fallback)
    def self.config_from_env : AppConfig?
      company = ENV["BAMBOOHR_COMPANY"]?
      api_key = ENV["BAMBOOHR_API_KEY"]?
      employee_id = ENV["BAMBOOHR_EMPLOYEE_ID"]?

      if company && api_key && employee_id
        AppConfig.new(company, api_key, employee_id)
      else
        nil
      end
    end

    # Main method to get configuration with full fallback chain
    def self.get_config(io : IO = STDOUT) : AppConfig
      # 1. Try loading from config file (XDG-compliant)
      if config = load_config(io)
        if config.valid?
          return config
        else
          io.puts "⚠️  Configuration file found but contains invalid values".colorize(:yellow)
        end
      end

      # 2. Try environment variables
      if config = config_from_env
        if config.valid?
          io.puts "📋 Using configuration from environment variables".colorize(:cyan)
          return config
        end
      end

      # 3. Prompt user and save
      config = prompt_for_config(io)

      # Ask if user wants to save the configuration
      io.puts
      io.print "💾 Save this configuration for future use? [Y/n]: "
      response = gets.try(&.strip.downcase) || "y"

      if response.empty? || response.starts_with?("y")
        save_config(config, io)
      else
        io.puts "⚠️  Configuration not saved. You'll be prompted again next time.".colorize(:yellow)
      end

      config
    end

    # Show current configuration file location and status
    def self.show_config_info(io : IO = STDOUT)
      io.puts "📁 Configuration Information".colorize(:cyan).bold
      io.puts
      io.puts "Config file path: #{config_file_path}"
      io.puts "Config directory: #{config_dir}"
      io.puts "File exists: #{LocalFileSystem.exists?(config_file_path) ? "Yes".colorize(:green) : "No".colorize(:red)}"

      if LocalFileSystem.exists?(config_file_path)
        stat = LocalFileSystem.info(config_file_path)
        io.puts "LocalFileSystem size: #{stat.size} bytes"
        io.puts "Last modified: #{stat.modification_time}"
        io.puts "Permissions: #{stat.permissions.value.to_s(8)}"
      end

      io.puts
      io.puts "System config paths:"
      system_config_paths.each do |path|
        exists = LocalFileSystem.exists?(path)
        io.puts "  #{path} #{exists ? "(exists)".colorize(:green) : "(not found)".colorize(:light_gray)}"
      end
    end

    # Remove configuration file
    def self.remove_config(io : IO = STDOUT) : Bool
      if LocalFileSystem.exists?(config_file_path)
        begin
          LocalFileSystem.delete(config_file_path)
          io.puts "🗑️  Configuration file removed: #{config_file_path}".colorize(:green)
          true
        rescue ex
          STDERR.puts "❌ Error removing config file: #{ex.message}".colorize(:red)
          false
        end
      else
        io.puts "ℹ️  No configuration file to remove".colorize(:light_gray)
        false
      end
    end
  end
end
