# Technology Preferences

**Status:** PREFERENCES - Deviations allowed with justification

**Purpose:** Define default technology choices to maintain consistency and leverage strengths.

---

## Philosophy

These are **guiding preferences**, not rigid rules. Deviate when:
- Specific requirements demand it
- Ecosystem fit is better
- Performance/cost considerations
- Team expertise differs

**Always document deviations** with rationale in component README.

---

## Language Preferences

### C# (.NET) - Primary Backend

**Use for:**
- Backend services and APIs
- Business logic
- AWS Lambda functions
- Background workers
- CLI tools

**Strengths:**
- Strong typing → fewer runtime errors
- Excellent AWS Lambda support (native runtime, Graviton2)
- Great tooling and IDE support
- AI-friendly code generation
- Cross-platform (.NET 8+)

**When to deviate:**
- JavaScript ecosystem required (npm packages)
- Existing Node.js codebase
- Team only knows JavaScript/TypeScript

### TypeScript - Frontend

**Use for:**
- Browser applications (Vue.js)
- Frontend logic
- Node.js scripts (when C# overkill)

**Strengths:**
- Type safety for JavaScript
- Better IDE support than plain JavaScript
- Gradual adoption possible
- AI-friendly

**When to deviate:**
- Very simple scripts (< 50 lines) → JavaScript acceptable
- Legacy JavaScript codebase

### Language Preference Order

1. **C#** - Backend, services, business logic
2. **TypeScript** - Frontend, Node.js when needed
3. **Bash** - Simple build scripts (< 50 lines, no complex logic)
4. **JavaScript** - Only when TypeScript impractical

**Avoid:** Python, Go, Rust (unless specific requirements justify)

---

## Infrastructure Preferences

### Terraform - Primary IaC

**Use for:**
- All infrastructure as code
- AWS resources
- Multi-cloud scenarios
- Internal infrastructure

**Strengths:**
- Declarative syntax
- Plan before apply
- Multi-cloud support
- Better module ecosystem than CloudFormation
- AI-friendly HCL syntax

**When to deviate:**
- Templates distributed for others to deploy → CloudFormation
- Organizational mandate
- AWS-specific features (CDK, Service Catalog, StackSets)

**Rule:** Never use CloudFormation for internal infrastructure.

### AWS - Cloud Platform

**Serverless Services (Preferred):**
- Lambda (compute)
- DynamoDB (database)
- S3 (storage)
- CloudFront (CDN)
- API Gateway (APIs)
- EventBridge (events)

**Always-On Services (Exceptions Only):**
- RDS → Only when complex relational queries required
- EC2 → Only when Lambda constraints exceeded
- Fargate → Only for long-running processes (> 15 min)

**Principle:** Zero-cost-when-idle architecture

---

## Database Preferences

### DynamoDB - Primary

**Use for:**
- Key-value access patterns
- Serverless architecture
- Pay-per-request pricing
- High scale applications

**Design Requirements:**
- Access-pattern-first design
- Key encoding with type prefixes (`USER#{id}`)
- GSI planning upfront

**When to deviate:**
- Complex relational queries (joins, aggregations)
- Existing SQL-heavy codebase
- Team only knows SQL

### RDS PostgreSQL - Exception Only

**Use when:**
- Complex transactions required
- Heavy relational data
- SQL expertise on team
- Migration from existing SQL database

**Trade-offs:**
- Always-on cost (not serverless)
- More operational overhead
- Doesn't scale to zero

---

## Frontend Preferences

### Vue.js 3 - Primary

**Use for:**
- Web applications
- Interactive UIs
- SPAs (Single Page Applications)

**Patterns:**
- **Composition API** (preferred over Options API)
- TypeScript (always)
- Pinia for state management (not Vuex)
- Vuetify for UI components

**When to deviate:**
- Existing React codebase
- Team expertise in React
- React ecosystem dependency

### Vuetify - UI Framework

**Use for:**
- Material Design components
- Consistent UI
- Rapid prototyping

**When to deviate:**
- Custom design system required
- Performance constraints
- Different design language

---

## Testing Preferences

### C# Testing

**Stack:**
- xUnit (test framework)
- FluentAssertions (assertions)
- Moq (mocking)
- Testcontainers (integration tests)

**Pattern:** Test pyramid (60% unit, 30% integration, 10% E2E)

### TypeScript/Vue Testing

**Stack:**
- Vitest (test runner)
- @vue/test-utils (component testing)
- Playwright (E2E)

**Pattern:** Component tests for UI, E2E for critical flows

---

## Architecture Preferences

### Serverless-First

**Default:** Use serverless services unless specific reason not to

**Serverless:**
- Lambda + API Gateway
- DynamoDB on-demand
- S3 + CloudFront
- EventBridge

**Not Serverless (exceptions only):**
- RDS (always-on)
- EC2 (always-on)
- ECS/Fargate (pay while running)

### Event-Driven Architecture

**Prefer:**
- EventBridge for service-to-service communication
- SQS for queues and reliability
- SNS for fan-out patterns

**Over:**
- Synchronous API calls between services
- Polling databases
- Tight coupling

### API Design

**Prefer:**
- REST with JSON
- OpenAPI/Swagger documentation
- Versioning via media types (`application/vnd.api.v2+json`)

**C# Pattern:**
- Minimal API (not controllers)
- Static endpoint classes (one per file)
- Explicit request/response DTOs

---

## Development Tools

### DevContainer - Required

**Why:**
- Consistent environment
- < 10 minute onboarding
- Works with Claude Code

**Stack:**
- VS Code + DevContainer extension
- Docker Desktop
- DevContainer features for tools

### Build Tools

**C#:**
- .NET CLI (`dotnet build`, `dotnet test`)
- MSBuild for complex scenarios

**TypeScript:**
- Vite (build tool)
- npm/pnpm (package management)

**Repository:**
- Makefile (self-documenting targets)
- Git (source control)

---

## When to Deviate

### Decision Framework

**Ask:**
1. Does this preference apply to my use case?
2. Is there a specific requirement that contradicts it?
3. What are the trade-offs?
4. Can I document the rationale?

**If yes to all → Deviate and document.**

### Documentation Template

```markdown
## Technology Choice: [Technology Name]

**Deviation from Preference:** Using [X] instead of preferred [Y]

**Rationale:**
- [Specific reason 1]
- [Specific reason 2]

**Trade-offs Accepted:**
- [Known downside 1]
- [Known downside 2]

**Mitigation:**
- [How we address the downsides]
```

**Example:**
```markdown
## Technology Choice: React

**Deviation from Preference:** Using React instead of preferred Vue.js

**Rationale:**
- Existing codebase is 100% React
- Team expertise is all in React
- Migration cost too high

**Trade-offs Accepted:**
- Larger bundle size than Vue.js
- More boilerplate than Vue.js Composition API

**Mitigation:**
- Use React Server Components for better performance
- TypeScript for type safety
```

---

## Summary Table

| Category | Preference | Alternative | Deviation Criteria |
|----------|-----------|-------------|-------------------|
| Backend | C# .NET | TypeScript/Node.js | JavaScript ecosystem needed |
| Frontend | Vue.js + TypeScript | React | Team expertise, existing codebase |
| Infrastructure | Terraform | CloudFormation | Templates distributed for others to deploy |
| Database | DynamoDB | RDS PostgreSQL | Complex relational queries |
| Compute | Lambda | Fargate | Process > 15 min, specific requirements |
| State Management | Pinia | Vuex | Legacy Vue 2 codebase |
| Testing (C#) | xUnit | NUnit, MSTest | Team preference |
| Testing (TS) | Vitest | Jest | Existing setup |

---

*These are preferences, not rules. Document deviations with rationale.*
