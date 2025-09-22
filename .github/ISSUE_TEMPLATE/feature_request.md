---
name: Feature Request
about: Suggest an idea for improving Reflex
title: "[FEATURE] "
labels: enhancement
assignees: ""
---

## 🚀 Feature Request

**Is your feature request related to a problem? Please describe.**
A clear and concise description of what the problem is. Ex. I'm always frustrated when [...]

**Describe the solution you'd like**
A clear and concise description of what you want to happen.

**Describe alternatives you've considered**
A clear and concise description of any alternative solutions or features you've considered.

## 📋 Feature Details

**Component (check all that apply):**

- [ ] Core Contracts (`/core`)
- [ ] TypeScript SDK (`/sdk`)
- [ ] Documentation
- [ ] Testing Infrastructure
- [ ] CI/CD Pipeline
- [ ] Other: ****\_\_\_****

**Feature Category:**

- [ ] New MEV Strategy
- [ ] Performance Improvement
- [ ] Security Enhancement
- [ ] Integration Support
- [ ] Developer Experience
- [ ] User Interface
- [ ] Documentation
- [ ] Testing

## 🎯 Use Case

**Who would benefit from this feature?**

- [ ] DEX Developers
- [ ] MEV Searchers
- [ ] Protocol Integrators
- [ ] End Users
- [ ] Liquidity Providers
- [ ] Other: ****\_\_\_****

**Describe your use case**
Provide a detailed description of how you would use this feature:

```
Example scenario:
As a DEX developer, I want to [feature] so that I can [benefit].
```

## 💡 Proposed Implementation

**High-level approach:**
Describe how you think this feature could be implemented:

**Smart Contract Changes (if applicable):**

```solidity
// Example interface or function signature
function newFeature(uint256 param) external returns (bool);
```

**SDK Changes (if applicable):**

```typescript
// Example API design
sdk.newFeature(params: FeatureParams): Promise<FeatureResult>
```

**Configuration Changes:**

- New configuration options needed
- Environment variables
- Deployment considerations

## 🔍 Technical Considerations

**Performance Impact:**

- Gas usage implications
- Execution time considerations
- Network load impact

**Security Implications:**

- New attack vectors to consider
- Access control requirements
- Audit requirements

**Compatibility:**

- Backward compatibility requirements
- Breaking changes (if any)
- Migration strategy

**Dependencies:**

- New external dependencies needed
- Version compatibility requirements

## 📊 Success Metrics

**How would we measure the success of this feature?**

- [ ] Performance improvements (specify metrics)
- [ ] User adoption rates
- [ ] Error reduction
- [ ] Gas savings
- [ ] Integration ease
- [ ] Other: ****\_\_\_****

**Specific metrics:**

- Target improvement: [e.g., 20% gas reduction]
- Success criteria: [e.g., adopted by 5+ protocols]

## 🚧 Implementation Scope

**Priority Level:**

- [ ] Critical (security or major functionality)
- [ ] High (important for upcoming milestones)
- [ ] Medium (valuable but not urgent)
- [ ] Low (nice to have)

**Estimated Complexity:**

- [ ] Small (1-2 days)
- [ ] Medium (1-2 weeks)
- [ ] Large (1+ months)
- [ ] Extra Large (requires significant planning)

**Required Skills:**

- [ ] Solidity Development
- [ ] TypeScript/JavaScript
- [ ] Gas Optimization
- [ ] Security Auditing
- [ ] Documentation
- [ ] Testing

## 🔗 References

**Related Issues:**

- Link to related feature requests or bugs
- Reference to community discussions

**External References:**

- Links to relevant documentation
- Similar implementations in other projects
- Research papers or articles

**Examples:**

- Code examples from other projects
- Mock-ups or diagrams
- User interface concepts

## ✅ Checklist

Before submitting, please confirm:

- [ ] I have searched existing issues to avoid duplicates
- [ ] I have provided a clear and descriptive title
- [ ] I have explained the problem and proposed solution
- [ ] I have considered implementation complexity
- [ ] I have thought about security implications
- [ ] I have specified the target user group
- [ ] I have provided sufficient technical details

## 🏷️ Labels

Please add relevant labels:

- **Priority**: `critical`, `high`, `medium`, `low`
- **Scope**: `core`, `sdk`, `docs`, `infrastructure`
- **Type**: `enhancement`, `new-feature`, `optimization`
- **Effort**: `small`, `medium`, `large`, `epic`

---

**Note**: Feature requests will be reviewed by the core team and prioritized based on community needs, technical feasibility, and project roadmap alignment.
