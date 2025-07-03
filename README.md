# BambooHR Time Tracker CLI

[![Crystal CI](https://github.com/josacar/bamboohr-cli/workflows/CI/badge.svg)](https://github.com/josacar/bamboohr-cli/actions)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Crystal Version](https://img.shields.io/badge/crystal-%3E%3D1.0.0-blue.svg)](https://crystal-lang.org)

A modern, interactive command-line interface for BambooHR time tracking, built with Crystal. Features real-time session updates, XDG-compliant configuration management, and secure credential storage.

## ✨ Features

- 🕐 **Interactive clock in/out functionality**
- ⏱️ **Real-time display of current session duration** (updates every second when clocked in)
- 📊 **Live daily total time tracking** (includes current session + completed sessions)
- 🎨 **Colorized output** for better visibility
- 🔄 **Automatic status updates** with periodic API refresh
- 🛡️ **Error handling and network resilience**
- 📁 **XDG-compliant configuration management** with YAML files
- 🔐 **Secure credential storage** with proper file permissions

## 🚀 Quick Start

### Prerequisites

- Crystal programming language (>= 1.0.0)
- BambooHR account with API access
- BambooHR API key

### Installation

#### From Source

```bash
git clone https://github.com/josacar/bamboohr-cli.git
cd bamboohr-cli
make build
sudo make install  # Optional: install to system PATH
```

#### Using Shards

```bash
# Add to your shard.yml
dependencies:
  bamboohr-cli:
    github: josacar/bamboohr-cli
    version: ~> 1.0.0
```

### First Run

```bash
# First run will prompt for configuration
bamboohr-cli

# Output:
🔧 BambooHR CLI Configuration Setup
No configuration file found. Let's set up your BambooHR credentials.

Enter your BambooHR company domain: mycompany
Enter your BambooHR API key: ******
Enter your employee ID: 123

💾 Save this configuration for future use? [Y/n]: y
💾 Configuration saved to ~/.config/bamboohr-cli/config.yml
```

## 📖 Usage

### Interactive Mode

```bash
bamboohr-cli
```

### Example Output

```
🎯 BambooHR Time Tracker
Company: mycompany
Employee ID: 12345
──────────────────────────────────────────────────

🟢 CLOCKED IN | Current session: 2h 15m 30s | Daily total: 6h 45m 30s
Press ENTER to clock out (Ctrl+C to exit):
```

**Real-time updates when clocked in:**
- Current session time updates every second
- Daily total includes current session + previous sessions
- Live display without interrupting user interaction

### Command Line Options

```bash
bamboohr-cli --help          # Show help information
bamboohr-cli --version       # Show version information
bamboohr-cli --config        # Show configuration file information
bamboohr-cli --config-remove # Remove saved configuration file
```

## ⚙️ Configuration

### Configuration File Locations

The CLI follows the [XDG Base Directory Specification](https://specifications.freedesktop.org/basedir-spec/basedir-spec-latest.html):

- **User config**: `~/.config/bamboohr-cli/config.yml`
- **System config**: `/etc/xdg/bamboohr-cli/config.yml`

### Configuration Priority

1. User configuration file
2. System configuration file
3. Environment variables
4. Interactive prompts (saved to user config)

### Environment Variables

```bash
export BAMBOOHR_COMPANY="your_company_domain"
export BAMBOOHR_API_KEY="your_api_key"
export BAMBOOHR_EMPLOYEE_ID="your_employee_id"
```

### Configuration File Format

```yaml
# BambooHR CLI Configuration
# Your BambooHR company domain (e.g., 'mycompany' for mycompany.bamboohr.com)
company_domain: "mycompany"

# Your BambooHR API key (generate from Settings > API Keys in BambooHR)
api_key: "your_api_key_here"

# Your employee ID (found in your BambooHR profile URL)
employee_id: "123"
```

## 🏗️ Development

### Building from Source

```bash
# Clone the repository
git clone https://github.com/josacar/bamboohr-cli.git
cd bamboohr-cli

# Install dependencies (none required - uses Crystal stdlib only)
shards install

# Build the application
make build

# Run tests
make test

# Build optimized release version
make release
```

### Running Tests

```bash
# Run all tests
crystal spec

# Run specific test file
crystal spec spec/bamboohr_api_spec.cr

# Run tests with verbose output
crystal spec --verbose
```

## 🔧 API Integration

### BambooHR API Endpoints Used

- `POST /api/v1/time_tracking/employees/{employeeId}/clock_in` - Clock in
- `POST /api/v1/time_tracking/employees/{employeeId}/clock_out` - Clock out  
- `GET /api/v1/time_tracking/timesheet_entries` - Get time entries

### Getting Your BambooHR Credentials

1. **Company Domain**: Your BambooHR subdomain (e.g., if your URL is `mycompany.bamboohr.com`, use `mycompany`)
2. **API Key**: Generate from Settings > API Keys in your BambooHR admin panel
3. **Employee ID**: Found in your BambooHR profile URL or employee directory

## 🛡️ Security

- **Secure file permissions**: Configuration files created with `0o600` (owner-readable only)
- **No credential exposure**: API keys stored in user's private directory
- **Input validation**: All user input validated and sanitized
- **Error handling**: Sensitive information not exposed in error messages

## 🐛 Troubleshooting

### Common Issues

1. **"Invalid API key"**: Verify your API key is correct and has proper permissions
2. **"Employee not found"**: Check your employee ID is correct
3. **"Network error"**: Check internet connection and BambooHR service status
4. **"Permission denied"**: Ensure your API key has time tracking permissions

### Debug Information

```bash
# Show configuration information
bamboohr-cli --config

# Check file permissions
ls -la ~/.config/bamboohr-cli/

# Verify configuration file content
cat ~/.config/bamboohr-cli/config.yml
```

## 🤝 Contributing

We welcome contributions! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

### Quick Contribution Guide

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes and add tests
4. Ensure tests pass (`make test`)
5. Commit your changes (`git commit -m 'feat: add amazing feature'`)
6. Push to the branch (`git push origin feature/amazing-feature`)
7. Open a Pull Request

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- [Crystal Language](https://crystal-lang.org/) for the excellent programming language
- [BambooHR](https://www.bamboohr.com/) for providing the time tracking API
- [XDG Base Directory Specification](https://specifications.freedesktop.org/basedir-spec/basedir-spec-latest.html) for configuration standards

## 📊 Project Stats

- **Language**: Crystal
- **License**: MIT
- **Platforms**: macOS, Linux, Unix-like systems

## 🔗 Links

- [Repository](https://github.com/josacar/bamboohr-cli)
- [Issues](https://github.com/josacar/bamboohr-cli/issues)
- [Releases](https://github.com/josacar/bamboohr-cli/releases)
- [Contributing Guidelines](CONTRIBUTING.md)
- [Changelog](CHANGELOG.md)

---

**Made with ❤️ and Crystal**
