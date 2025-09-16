# Pull Request

## 📋 Description

**Summary**
Brief description of the changes in this PR.

**Related Issues**

- Fixes #(issue number)
- Closes #(issue number)
- Related to #(issue number)

## 🔄 Type of Change

Please check the relevant option:

- [ ] 🐛 Bug fix (non-breaking change which fixes an issue)
- [ ] ✨ New feature (non-breaking change which adds functionality)
- [ ] 💥 Breaking change (fix or feature that would cause existing functionality to not work as expected)
- [ ] 📚 Documentation update
- [ ] 🧪 Test improvements
- [ ] ♻️ Code refactoring (no functional changes)
- [ ] ⚡ Performance improvements
- [ ] 🔒 Security improvements

## 🎯 Changes Made

**Core Contracts (`/core`)**

- [ ] Modified existing contracts
- [ ] Added new contracts
- [ ] Updated interfaces
- [ ] Gas optimizations
- [ ] Security improvements

**TypeScript SDK (`/sdk`)**

- [ ] Added new SDK functions
- [ ] Modified existing APIs
- [ ] Updated type definitions
- [ ] Performance improvements
- [ ] Bug fixes

**Documentation**

- [ ] Updated README files
- [ ] Added code examples
- [ ] Updated API documentation
- [ ] Added integration guides

**Testing**

- [ ] Added unit tests
- [ ] Added integration tests
- [ ] Updated existing tests
- [ ] Improved test coverage

**Infrastructure**

- [ ] Updated CI/CD pipeline
- [ ] Modified build scripts
- [ ] Updated dependencies
- [ ] Configuration changes

## 🧪 Testing

**Test Coverage**

- [ ] All new code is covered by tests
- [ ] All existing tests pass
- [ ] Added tests for edge cases
- [ ] Manual testing completed

**Testing Details**

```bash
# Commands used for testing
forge test
npm test
```

**Test Results**

- Core Contracts: ✅ All tests pass
- SDK Tests: ✅ All tests pass
- Integration Tests: ✅ All tests pass

## 📊 Performance Impact

**Gas Usage (if applicable)**

- Before: XXX gas
- After: XXX gas
- Change: ±XXX gas (±XX%)

**Bundle Size (if applicable)**

- Before: XXX KB
- After: XXX KB
- Change: ±XXX KB

**Execution Time**

- No performance impact
- Improved performance: [details]
- Minor performance cost: [justified because]

## 🔒 Security Considerations

**Security Review**

- [ ] No new security risks introduced
- [ ] Security implications have been considered
- [ ] Access control changes reviewed
- [ ] Input validation added/updated

**Potential Risks**

- None identified
- Low risk: [description and mitigation]
- Medium risk: [description and mitigation]
- High risk: [requires additional review]

## 📖 Documentation

**Documentation Updates**

- [ ] Code comments added/updated
- [ ] README files updated
- [ ] API documentation updated
- [ ] Integration examples provided

**Breaking Changes**

- [ ] No breaking changes
- [ ] Breaking changes documented
- [ ] Migration guide provided
- [ ] Deprecated features marked

## ✅ Checklist

**Before Review**

- [ ] Code follows the project's style guidelines
- [ ] Self-review of the code completed
- [ ] Code is properly commented
- [ ] Tests added for new functionality
- [ ] All tests pass locally
- [ ] Documentation updated

**Solidity Specific (if applicable)**

- [ ] Code follows Solidity style guide
- [ ] Gas optimization considered
- [ ] Security best practices followed
- [ ] NatSpec documentation added
- [ ] Forge formatter applied (`forge fmt`)

**TypeScript Specific (if applicable)**

- [ ] TypeScript types are correct
- [ ] ESLint rules followed
- [ ] Prettier formatting applied
- [ ] JSDoc comments added
- [ ] No `any` types used (unless justified)

**Dependencies**

- [ ] No unnecessary dependencies added
- [ ] Dependency versions are pinned
- [ ] Security implications of new dependencies considered

## 🔗 Additional Context

**Screenshots**
If applicable, add screenshots to show the changes.

**Additional Notes**
Any additional information that reviewers should know.

**Deployment Considerations**

- [ ] No deployment changes needed
- [ ] Contract upgrade required
- [ ] Configuration changes needed
- [ ] Database migrations required

## 🏷️ Labels

Please add relevant labels:

- **Component**: `core`, `sdk`, `docs`, `tests`, `ci`
- **Priority**: `critical`, `high`, `medium`, `low`
- **Size**: `XS`, `S`, `M`, `L`, `XL`

---

## 📝 Reviewer Notes

**For Reviewers**
Please pay special attention to:

- Security implications
- Gas optimization
- Breaking changes
- Test coverage
- Documentation completeness

**Review Checklist for Maintainers**

- [ ] Code quality and style
- [ ] Security considerations
- [ ] Performance impact
- [ ] Test coverage
- [ ] Documentation updates
- [ ] Breaking changes documented
- [ ] CI/CD pipeline passes
