# Security Guidelines

This document outlines security best practices for contributing to LanguageSuggestion.

## 🔐 API Keys and Secrets

### ⚠️ NEVER Commit API Keys

**CRITICAL**: Never commit API keys, tokens, passwords, or any sensitive credentials to the repository.

### How API Keys Are Stored

- API keys are stored securely in the macOS Keychain using Keychain Services
- Keys are encrypted and protected by the system
- Each user must enter their own API keys through the Settings UI

### What to Do If You Accidentally Commit a Key

If you accidentally commit an API key or secret:

1. **Immediately revoke the key** from your API provider (OpenAI/OpenRouter)
2. Generate a new key
3. Remove the key from git history:
   ```bash
   git filter-branch --force --index-filter \
     "git rm --cached --ignore-unmatch path/to/file" \
     --prune-empty --tag-name-filter cat -- --all
   ```
4. Force push (if already pushed):
   ```bash
   git push origin --force --all
   ```
5. Update your local settings with the new key

## 🛡️ Security Best Practices

### For Contributors

1. **Never hardcode credentials** in source code
2. **Use environment variables** for local development (if needed)
3. **Review your commits** before pushing:
   ```bash
   git diff HEAD~1
   ```
4. **Use `.gitignore`** to exclude sensitive files
5. **Don't share API keys** in issues, pull requests, or discussions

### For Users

1. **Keep your API keys private** - don't share them
2. **Rotate keys regularly** for better security
3. **Use separate keys** for development and production
4. **Monitor API usage** to detect unauthorized access
5. **Revoke keys immediately** if compromised

## 🔍 Security Checklist Before Committing

Before committing code, verify:

- [ ] No API keys or tokens in code
- [ ] No hardcoded passwords or credentials
- [ ] No sensitive data in comments
- [ ] `.gitignore` properly configured
- [ ] No secrets in commit messages
- [ ] Build artifacts excluded from commits

## 📝 File Patterns to Never Commit

The following file patterns are automatically ignored:

- `*.key`, `*.pem`, `*.p12` - Certificate files
- `.env`, `.env.local` - Environment files
- `secrets.json`, `config.json` - Configuration files with secrets
- `*.secret`, `*.credentials` - Secret files
- `build/` - Build artifacts
- `xcuserdata/` - User-specific Xcode data

## 🔄 Keychain Migration

If you're upgrading from an older version that used UserDefaults:

1. Your existing keys will be automatically migrated to Keychain
2. Old UserDefaults entries will be cleaned up
3. No action required from you

## 🐛 Reporting Security Issues

If you discover a security vulnerability:

1. **DO NOT** open a public issue
2. Email the maintainer directly (if contact info available)
3. Provide details about the vulnerability
4. Allow time for a fix before public disclosure

## ✅ Security Features

- **Keychain Storage**: API keys stored in macOS Keychain (encrypted)
- **Secure Input**: API key fields use `SecureField` (masked input)
- **No Network Logging**: API keys are never logged or printed
- **HTTPS Only**: All API calls use HTTPS
- **No Key Transmission**: Keys are only sent in secure HTTP headers

## 📚 Additional Resources

- [OpenAI API Security Best Practices](https://platform.openai.com/docs/guides/safety-best-practices)
- [OpenRouter Security](https://openrouter.ai/docs)
- [macOS Keychain Services](https://developer.apple.com/documentation/security/keychain_services)

---

**Remember**: Security is everyone's responsibility. When in doubt, ask before committing sensitive data.

