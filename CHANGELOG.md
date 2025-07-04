# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2024-07-03

### Added
- Interactive command-line interface for BambooHR time tracking
- Real-time session timer with live updates every second
- Dynamic daily total calculation including current session
- XDG Base Directory Specification compliant configuration management
- YAML configuration files with helpful comments
- Secure credential storage with proper file permissions (0o600)
- Comprehensive CLI argument parsing (`--help`, `--version`, `--config`, `--config-remove`)
- Environment variable support for configuration
- Colorized output for better user experience
- Modular architecture with separated concerns:
  - API client (`bamboohr_api.cr`)
  - CLI interface (`bamboohr_cli.cr`) 
  - Configuration management (`config_manager.cr`)
- Comprehensive test suite with 64 test cases
- Error handling for network issues and API failures
- Background fiber-based real-time updates
- Clean inline status display without scrolling
- Graceful cleanup on exit and signal handling

### Features
- **Clock In/Out**: Interactive time tracking with BambooHR API
- **Real-time Updates**: Live session timer and daily total updates
- **Configuration Management**: XDG-compliant YAML configuration
- **Security**: Secure file permissions and credential storage
- **User Experience**: Colorized output and responsive interface
- **Cross-platform**: Works on macOS, Linux, and other Unix-like systems

### Technical Details
- Built with Crystal programming language
- Follows Crystal language conventions and style guide
- Comprehensive error handling and validation
- Memory efficient with proper resource cleanup
- Thread-safe operations using Crystal's fiber model

### Configuration
- User config: `~/.config/bamboohr-cli/config.yml`
- System config: `/etc/xdg/bamboohr-cli/config.yml`
- Environment variables: `BAMBOOHR_COMPANY`, `BAMBOOHR_API_KEY`, `BAMBOOHR_EMPLOYEE_ID`
- XDG environment variables: `XDG_CONFIG_HOME`, `XDG_CONFIG_DIRS`

### API Compatibility
- BambooHR Time Tracking API v1
- Supports clock in/out operations
- Retrieves time entries and daily totals
- Handles API errors gracefully

[1.0.0]: https://github.com/josacar/bamboohr-cli/releases/tag/v1.0.0
