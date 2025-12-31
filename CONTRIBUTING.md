# Contributing Guidelines

Thank you for your interest in contributing to the AI Data Center MLOps Platform!

## Development Workflow

1. **Fork and Clone**
```bash
   git clone https://github.com/gh-range/aicc-mlops-platform.git
   cd aicc-mlops-platform
```

2. **Create Feature Branch**
```bash
   git checkout develop
   git checkout -b feature/your-feature-name
```

3. **Make Changes**
   - Follow existing code style
   - Add tests for new features
   - Update documentation

4. **Commit with Conventional Commits**
```
   feat: add new GPU time-slicing configuration
   fix: correct Prometheus scrape interval
   docs: update JupyterHub installation guide
   chore: upgrade Helm chart dependencies
```

5. **Push and Create Pull Request**
```bash
   git push origin feature/your-feature-name
```

## Code Standards

- **YAML**: 2-space indentation, validate with `yamllint`
- **Python**: Follow PEP 8, max line length 100
- **Shell**: Use `shellcheck` for validation
- **Docker**: Multi-stage builds, scan with Trivy

## Review Process

- All PRs require approval before merge
- CI checks must pass
- Documentation must be updated

## Questions?

Open an issue or contact the maintainer.
