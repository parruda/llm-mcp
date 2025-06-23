# GitHub Workflows Documentation

This document describes the GitHub Actions workflows configured for the llm-mcp gem.

## Workflows Overview

### CI Workflow (`ci.yml`)

**Purpose**: Runs continuous integration checks on all pushes and pull requests.

**Features**:
- Ruby version matrix testing (3.2, 3.3, 3.4)
- Automatic removal of local claude_swarm dependency
- Test execution with optional API keys
- RuboCop linting with auto-fix for Gemfile modifications
- Test artifact upload on failure
- Ubuntu 22.04 runner for better Ruby compatibility

**Required Secrets**: None (optional: OPENAI_API_KEY, GOOGLE_GENAI_API_KEY)

### Draft Release Workflow (`draft-release.yml`)

**Purpose**: Creates draft GitHub releases when version tags are pushed.

**Triggers**: Push of any tag

**Features**:
- Strict semantic version validation
- Automatic changelog extraction from CHANGELOG.md
- Fallback to auto-generated release notes if no changelog
- Temporary file cleanup
- Clear error messages

**Required Secrets**: None (uses GITHUB_TOKEN)

### Release Gem Workflow (`release-gem.yml`)

**Purpose**: Publishes the gem to RubyGems when a GitHub release is published.

**Triggers**: GitHub release publish event

**Features**:
- Version verification against gemspec
- Full test suite execution before release
- Gem content verification
- Retry logic for RubyGems publication (3 attempts)
- Post-publication verification
- Secure credential handling

**Required Secrets**:
- `RUBYGEMS_API_KEY`: API key for RubyGems publication
- `OPENAI_API_KEY`: Required for full test suite
- `GOOGLE_GENAI_API_KEY`: Required for full test suite

### Security Workflow (`security.yml`)

**Purpose**: Performs security scanning and vulnerability checks.

**Features**:
- Bundle audit for dependency vulnerabilities
- Weekly scheduled scans
- Dependency review on pull requests
- Automatic vulnerability database updates

**Required Secrets**: None

## Security Considerations

1. **Action Pinning**: All GitHub Actions are pinned to specific commit SHAs to prevent supply chain attacks.

2. **Minimal Permissions**: Each workflow uses the minimum required permissions.

3. **Secret Handling**: 
   - Credentials are stored securely in GitHub Secrets
   - RubyGems credentials are cleaned up immediately after use
   - No fallback values for sensitive data

4. **Claude Swarm Dependency**: The local claude_swarm dependency is automatically removed in CI to prevent build failures.

## Requirements

- Ruby 3.2 or newer (as specified in gemspec)
- Bundler 2.0 or newer

## Usage

### Creating a New Release

1. Update version in `lib/llm_mcp/version.rb`
2. Update CHANGELOG.md with release notes
3. Commit changes
4. Tag the release: `git tag 1.2.3`
5. Push the tag: `git push origin 1.2.3`
6. GitHub Actions will create a draft release
7. Review and publish the draft release
8. GitHub Actions will automatically publish to RubyGems

### Running CI Locally

To replicate CI checks locally:

```bash
# Remove claude_swarm dependency temporarily
sed -i.bak '/gem "claude_swarm", path:/d' Gemfile
bundle install

# Run tests
bundle exec rake test

# Run linter
bundle exec rubocop

# Run security audit
gem install bundler-audit
bundle audit check

# Restore Gemfile
mv Gemfile.bak Gemfile
bundle install
```

## Troubleshooting

- **CI Failures**: Check if API keys are needed for specific tests
- **Release Failures**: Ensure RUBYGEMS_API_KEY is configured in repository secrets
- **Version Mismatches**: Verify version in lib/llm_mcp/version.rb matches the git tag