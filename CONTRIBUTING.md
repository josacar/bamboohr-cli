# Contributing to BambooHR CLI

Thank you for your interest in contributing to BambooHR CLI! This document provides guidelines for contributing to the project.

## 🚀 Getting Started

### Prerequisites

- Crystal >= 1.0.0
- Git
- A BambooHR account for testing (optional)

### Setting Up Development Environment

1. **Fork and clone the repository:**
   ```bash
   git clone https://github.com/josacar/bamboohr-cli.git
   cd bamboohr-cli
   ```

2. **Install dependencies:**
   ```bash
   shards install
   ```

3. **Build the project:**
   ```bash
   make build
   ```

4. **Run tests:**
   ```bash
   make test
   ```

## 🧪 Testing

### Running Tests

```bash
# Run all tests
crystal spec

# Run specific test file
crystal spec spec/bamboohr_api_spec.cr

# Run tests with verbose output
crystal spec --verbose
```

### Test Coverage

We maintain comprehensive test coverage across all modules:
- API client functionality
- Configuration management
- CLI interface
- Error handling
- XDG compliance

### Writing Tests

- Use descriptive test names
- Follow the existing test structure
- Use `IO::Memory` for testing output
- Mock external dependencies when possible
- Test both success and error cases

## 📝 Code Style

### Crystal Style Guide

Follow the [Crystal Style Guide](https://crystal-lang.org/reference/conventions/coding_style.html):

- Use 2 spaces for indentation
- Use snake_case for method and variable names
- Use PascalCase for class and module names
- Use SCREAMING_SNAKE_CASE for constants
- Prefer explicit return types for public methods

### Code Formatting

```bash
# Format code (if crystal fmt is available)
crystal tool format

# Check formatting
crystal tool format --check
```

### Documentation

- Document public methods and classes
- Use clear, concise comments
- Include examples for complex functionality
- Update README.md for new features

## 🏗️ Architecture

### Design Principles

- **Separation of concerns**: Each module has a single responsibility
- **Dependency injection**: Use IO parameters for testability
- **Error handling**: Graceful degradation and clear error messages
- **XDG compliance**: Follow Linux desktop standards
- **Security**: Secure credential storage and file permissions

## 🔧 Making Changes

### Workflow

1. **Create a feature branch:**
   ```bash
   git checkout -b feature/your-feature-name
   ```

2. **Make your changes:**
   - Write code following the style guide
   - Add tests for new functionality
   - Update documentation as needed

3. **Test your changes:**
   ```bash
   make test
   make build
   ```

4. **Commit your changes:**
   ```bash
   git add .
   git commit -m "feat: add your feature description"
   ```

5. **Push and create a pull request:**
   ```bash
   git push origin feature/your-feature-name
   ```

### Commit Messages

Follow [Conventional Commits](https://www.conventionalcommits.org/):

- `feat:` - New features
- `fix:` - Bug fixes
- `docs:` - Documentation changes
- `style:` - Code style changes
- `refactor:` - Code refactoring
- `test:` - Test additions or changes
- `chore:` - Maintenance tasks

Examples:
```
feat: add real-time session updates
fix: handle network timeouts gracefully
docs: update installation instructions
test: add configuration manager tests
```

## 🐛 Reporting Issues

### Bug Reports

When reporting bugs, please include:

- Crystal version (`crystal --version`)
- Operating system and version
- Steps to reproduce the issue
- Expected vs actual behavior
- Error messages or logs
- Configuration details (without sensitive data)

### Feature Requests

For feature requests, please describe:

- The problem you're trying to solve
- Your proposed solution
- Alternative solutions considered
- Additional context or examples

## 🔒 Security

### Reporting Security Issues

Please report security vulnerabilities privately by emailing [security@example.com] instead of creating public issues.

### Security Considerations

- Never commit API keys or credentials
- Use secure file permissions (0o600) for config files
- Validate all user input
- Handle sensitive data carefully in logs and error messages

## 📋 Pull Request Guidelines

### Before Submitting

- [ ] Tests pass (`make test`)
- [ ] Code builds without warnings (`make build`)
- [ ] Documentation updated if needed
- [ ] Commit messages follow conventional format
- [ ] No sensitive data in commits

### Pull Request Template

```markdown
## Description
Brief description of changes

## Type of Change
- [ ] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation update

## Testing
- [ ] Tests added/updated
- [ ] All tests pass
- [ ] Manual testing completed

## Checklist
- [ ] Code follows style guidelines
- [ ] Self-review completed
- [ ] Documentation updated
- [ ] No breaking changes (or clearly documented)
```

## 🤝 Community

### Getting Help

- Create an issue for bugs or questions
- Check existing issues before creating new ones
- Be respectful and constructive in discussions

### Code of Conduct

- Be welcoming and inclusive
- Respect different viewpoints and experiences
- Focus on what's best for the community
- Show empathy towards other community members

## 📚 Resources

- [Crystal Language Documentation](https://crystal-lang.org/docs/)
- [Crystal Style Guide](https://crystal-lang.org/reference/conventions/coding_style.html)
- [BambooHR API Documentation](https://documentation.bamboohr.com/)
- [XDG Base Directory Specification](https://specifications.freedesktop.org/basedir-spec/basedir-spec-latest.html)

## 🙏 Recognition

Contributors will be recognized in:
- README.md contributors section
- Release notes for significant contributions
- Project documentation

Thank you for contributing to BambooHR CLI! 🎉
