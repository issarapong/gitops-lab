# Contributing to GitOps Lab

Thank you for your interest in contributing to the GitOps Lab! This guide will help you get started.

## 🤝 How to Contribute

### Types of Contributions Welcome

- 🐛 **Bug fixes** - Fix issues in scripts or documentation
- 📝 **Documentation improvements** - Clarify instructions, add examples
- ✨ **New features** - Add new GitOps patterns or tools
- 🧪 **Enhanced examples** - Improve existing scenarios
- 🔧 **Tool updates** - Update to newer versions of ArgoCD, Flux, etc.

## 🚀 Development Workflow

### 1. Fork and Clone

```bash
# Fork the repository on GitHub
# Clone your fork
git clone https://github.com/issarapong/gitops-lab.git
cd gitops-lab
```

### 2. Create Feature Branch

```bash
# Create descriptive branch name
git checkout -b feature/add-helm-examples
# or
git checkout -b fix/argocd-login-issue
# or  
git checkout -b docs/improve-flux-setup
```

### 3. Make Changes

- Follow existing code style and patterns
- Test your changes thoroughly
- Update documentation as needed
- Add examples where helpful

### 4. Test Your Changes

```bash
# Run the lab startup script to verify everything works
./scripts/lab-startup.sh

# Test specific components
cd 01-foundation/03-gitops-intro
kubectl apply -k clusters/dev/sample-app/

# Verify troubleshooting script
./scripts/troubleshoot.sh
```

### 5. Commit and Push

```bash
# Add your changes
git add .

# Create descriptive commit message
git commit -m "Add: Helm integration examples for ArgoCD

- Add Helm chart examples in 02-core-tools/04-argocd/helm/
- Update documentation with Helm workflow
- Include values.yaml for different environments"

# Push to your fork
git push origin feature/add-helm-examples
```

### 6. Create Pull Request

1. Go to the original repository on GitHub
2. Click "New Pull Request"
3. Select your branch
4. Fill out the PR template
5. Submit for review

## 📋 Pull Request Guidelines

### PR Title Format

Use descriptive titles with prefixes:

- `Add:` for new features
- `Fix:` for bug fixes  
- `Update:` for updates to existing features
- `Docs:` for documentation changes
- `Refactor:` for code restructuring

Examples:
- `Add: Multi-cluster ArgoCD setup with ApplicationSets`
- `Fix: Flux GitRepository authentication issue`
- `Update: ArgoCD to v2.8.4 with updated manifests`
- `Docs: Improve troubleshooting guide with common solutions`

### PR Description Template

```markdown
## Description
Brief description of changes made.

## Type of Change
- [ ] Bug fix
- [ ] New feature
- [ ] Documentation update
- [ ] Breaking change

## Testing
- [ ] Tested with lab-startup.sh
- [ ] Verified all environments (dev/staging/prod)
- [ ] Documentation updated
- [ ] Examples working

## Screenshots/Logs
Add screenshots or logs if helpful.

## Checklist
- [ ] Code follows project style
- [ ] Self-review completed
- [ ] Tests pass
- [ ] Documentation updated
```

## 🧪 Testing Guidelines

### Required Tests

Before submitting, ensure:

1. **Lab startup works**:
   ```bash
   ./scripts/lab-startup.sh
   ```

2. **All environments deploy**:
   ```bash
   kubectl apply -k 01-foundation/03-gitops-intro/clusters/dev/sample-app/
   kubectl apply -k 01-foundation/03-gitops-intro/clusters/staging/sample-app/
   kubectl apply -k 01-foundation/03-gitops-intro/clusters/prod/sample-app/
   ```

3. **ArgoCD applications work**:
   ```bash
   kubectl apply -f 02-core-tools/04-argocd/applications/
   ```

4. **Flux configurations work**:
   ```bash
   kubectl apply -f 02-core-tools/05-flux/
   ```

### Testing Different Kubernetes Platforms

Test on multiple platforms when possible:

- **Docker Desktop** (macOS/Windows primary)
- **Minikube** (cross-platform)
- **Kind** (CI/CD friendly)

## 📝 Documentation Standards

### Markdown Guidelines

- Use clear headings (H1 for main sections, H2 for subsections)
- Include code examples with language specification
- Add emoji for visual navigation (📁 for directories, 🚀 for actions)
- Use consistent formatting for commands

### Code Examples

```bash
# Always include comments explaining what commands do
kubectl apply -k clusters/dev/sample-app/  # Deploy to dev environment

# Show expected output when helpful
kubectl get pods -n dev
# Expected output:
# NAME                         READY   STATUS    RESTARTS   AGE
# sample-app-7d4b6c8f9-xyz12   1/1     Running   0          30s
```

### File Structure Documentation

When adding new directories or files, update relevant README files with structure diagrams:

```
new-feature/
├── examples/          # Working examples
├── manifests/         # Kubernetes manifests  
├── README.md         # Feature documentation
└── setup.sh          # Setup script
```

## 🚫 What Not to Include

### Avoid These Changes

- **Secrets or credentials** - Never commit real passwords, tokens, or keys
- **Personal configurations** - Don't include your personal kubeconfig or settings
- **Breaking changes** - Avoid changes that break existing functionality
- **Untested code** - All code should be tested before submission

### File Patterns to Exclude

The .gitignore already excludes these, but double-check:

```
# Don't commit these
.kube/
*.kubeconfig
secrets/
*.secret
*.key
.DS_Store
```

## 🎯 Areas Needing Contribution

### High Priority

- **Windows compatibility** - Test and improve Windows support
- **Advanced scenarios** - Multi-cluster, progressive delivery
- **Monitoring integration** - Prometheus, Grafana examples
- **Security hardening** - RBAC, policy examples

### Medium Priority  

- **Tool updates** - Keep ArgoCD, Flux versions current
- **Performance optimization** - Faster startup, resource efficiency
- **Error handling** - Better error messages and recovery

### Documentation Needs

- **Video tutorials** - Screen recordings of workflows
- **Troubleshooting** - Common issues and solutions
- **Best practices** - Production deployment guidance
- **Integration guides** - CI/CD pipeline examples

## 🏷️ Issue Labels

When creating issues, use appropriate labels:

- `bug` - Something isn't working
- `enhancement` - New feature request
- `documentation` - Documentation improvements
- `good first issue` - Good for newcomers
- `help wanted` - Extra attention needed
- `question` - General questions

## 💬 Community Guidelines

### Be Respectful

- Use welcoming and inclusive language
- Respect different viewpoints and experiences
- Accept constructive criticism gracefully
- Focus on what's best for the community

### Be Collaborative

- Help others learn GitOps concepts
- Share knowledge and resources
- Provide constructive feedback
- Celebrate contributions from others

## 📞 Getting Help

### Stuck on Something?

1. **Check existing issues** - Your question might be answered
2. **Review documentation** - Check README files thoroughly
3. **Run troubleshooting** - Use `./scripts/troubleshoot.sh`
4. **Create detailed issue** - Include error messages, environment info

### Issue Template

```markdown
**Describe the issue**
Clear description of what's not working.

**Environment**
- OS: [macOS/Linux/Windows]
- Kubernetes: [Docker Desktop/Minikube/Kind]
- Version: [output of kubectl version]

**Steps to reproduce**
1. Run command X
2. See error Y

**Expected behavior**
What should happen instead.

**Logs/Screenshots**
Include relevant output.
```

## 🎉 Recognition

Contributors will be:

- Listed in repository contributors
- Mentioned in release notes for significant contributions
- Invited to maintainer team for sustained contributions

Thank you for helping make GitOps learning better for everyone! 🚀
