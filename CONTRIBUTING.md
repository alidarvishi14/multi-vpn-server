# Contributing to Multi-VPN Server

First off, thank you for considering contributing to Multi-VPN Server! It's people like you that make this project better for everyone.

## Code of Conduct

By participating in this project, you are expected to uphold our Code of Conduct:
- Be respectful and inclusive
- Welcome newcomers and help them get started
- Focus on constructive criticism
- Show empathy towards other community members

## How Can I Contribute?

### Reporting Bugs

Before creating bug reports, please check existing issues to avoid duplicates. When creating a bug report, include:

- A clear and descriptive title
- Steps to reproduce the issue
- Expected behavior vs actual behavior
- System information (OS, versions)
- Relevant log files
- Screenshots if applicable

### Suggesting Enhancements

Enhancement suggestions are tracked as GitHub issues. When creating an enhancement suggestion, include:

- A clear and descriptive title
- Detailed description of the proposed enhancement
- Use cases and examples
- Possible implementation approach

### Pull Requests

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes
4. Test your changes thoroughly
5. Commit with clear messages (`git commit -m 'Add amazing feature'`)
6. Push to your branch (`git push origin feature/amazing-feature`)
7. Open a Pull Request

#### Pull Request Guidelines

- Follow the existing code style
- Update documentation as needed
- Add tests if applicable
- Keep commits focused and atomic
- Write clear commit messages
- Reference related issues

## Development Setup

1. Clone the repository:
```bash
git clone https://github.com/yourusername/multi-vpn-server.git
cd multi-vpn-server
```

2. Install development dependencies:
```bash
pip install -r requirements-dev.txt
```

3. Run tests:
```bash
./scripts/run-tests.sh
```

## Code Style

### Shell Scripts
- Use shellcheck for linting
- Follow Google Shell Style Guide
- Add error handling with `set -e`
- Use meaningful variable names

### Python
- Follow PEP 8
- Use type hints where appropriate
- Document functions with docstrings
- Keep functions focused and small

### Documentation
- Use clear, concise language
- Include examples where helpful
- Keep README updated
- Document breaking changes

## Testing

- Test your changes on Ubuntu 22.04
- Verify all services start correctly
- Test backup and restore functionality
- Check client connectivity
- Validate subscription service

## Project Structure

```
multi-vpn-server/
├── scripts/           # Installation and management scripts
├── subscription/      # Subscription service code
├── configs/          # Configuration templates
├── docs/            # Documentation
└── tests/           # Test files
```

## Commit Messages

Format:
```
<type>(<scope>): <subject>

<body>

<footer>
```

Types:
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation
- `style`: Code style changes
- `refactor`: Code refactoring
- `test`: Test additions/changes
- `chore`: Maintenance tasks

Example:
```
feat(subscription): add multi-protocol support

Added support for VMess and Trojan protocols alongside VLESS.
Updated subscription service to handle protocol selection.

Closes #123
```

## Release Process

1. Update version numbers
2. Update CHANGELOG.md
3. Create release branch
4. Run full test suite
5. Create GitHub release
6. Tag release

## Getting Help

- Check documentation first
- Search existing issues
- Join our Discord server
- Ask in discussions

## Recognition

Contributors will be recognized in:
- README.md contributors section
- Release notes
- Project website

Thank you for contributing!