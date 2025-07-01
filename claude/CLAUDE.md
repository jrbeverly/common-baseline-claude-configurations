# Claude Context File

This file provides essential context for Claude Code and AI assistants working with ANY repository.

**Purpose:** Generic, reusable Claude Code guidance that teaches AI assistants how to analyze and work within repositories.

---

## Guiding Philosophy

This project is built by a solo developer optimizing for long-term operational stability, low maintenance burden, and sustained velocity over short-term convenience.

Design decisions should prioritize:

* **Risk elimination over speed shortcuts**: Prefer designs that permanently solve domains, even if they require more upfront effort.
* **Operational simplicity at scale**: Systems should trend toward no-ops, static, or managed primitives where possible, and be resilient by construction.
* **Clear architectural boundaries**: Services should do one thing well, with stable, well-designed interfaces that rarely change.
* **Compile-time and test-time correctness**: Strongly typed, deterministic, hermetic code is preferred so logic can be considered “solved” once verified.
* **Tolerance for structured over-engineering**: Microservices and modular systems are acceptable when they reduce future entanglement and maintenance risk.
* **Minimal SaaS dependency**: Prefer lightweight, self-built, policy-driven systems over third-party SaaS unless the dependency is clearly worth the long-term cost.
* **Docs-driven and spec-driven development**: Documentation, questions, and specifications are the source of truth; implementation exists to satisfy them.
* **Explicitness over implicitness**: Favor clarity, structure, and explicit decisions so the system is understandable, auditable, and maintainable by one person.

The goal is to build systems that are easy to trust, easy to operate, and hard to break—so future work is additive, not corrective.

## Technology Versions (Template Defaults)

**Note:** These are suggested default versions for repositories using this template. Actual versions are documented in repository-specific [CODEMAP.md](../CODEMAP.md).

**Backend:**
- .NET: 8.0 LTS (targeting .NET 10+ patterns where source generators are available)
- C#: 12 language features enabled

**Frontend:**
- TypeScript: 5.3+
- Vue: 3.4+ (Composition API)
- Node: 20 LTS

**Infrastructure:**
- Terraform: 1.6+
- AWS Lambda: Node 20 and .NET 8 runtimes
- DynamoDB: On-demand billing mode

**Upgrade Policy:** Adopt LTS versions. Document breaking changes in feature-specific guidelines.

---

## Essential Information

### What This File Provides

This file contains **generic, technology-agnostic guidance** for AI-assisted development:

- Best practices for working with Claude Code
- Repository organization principles (applicable to any tech stack)
- AI-first development workflow patterns
- Decision frameworks for code placement and architecture

**Repository-Specific Details:** See [CODEMAP.md](../CODEMAP.md) for THIS repository's structure, technology stack, and implementation patterns.

### Repository Organization Principles

**Service-Scoped Structure:** Repositories should organize code by service/domain, not by file type.

**Core Principle:** No source files directly under top-level directories. All code must live within a service-scoped subdirectory.

**Generic Pattern:**

```
/
├── {source-directory}/     # Backend services, APIs, business logic
│   └── {ServiceName}/      # One subdirectory per service (REQUIRED)
├── {app-directory}/        # Frontend applications, UI
│   └── {ServiceName}/      # One subdirectory per app (REQUIRED)
├── {infrastructure}/       # Infrastructure as code
│   └── {service-name}/     # One per service (REQUIRED)
├── {shared}/               # Shared libraries (used by 2+ services)
├── {tests}/                # Tests (mirrors source structure)
├── {docs}/                 # Human documentation
└── .claude/                # AI context and guidance (this directory)
```

**Why:** Service-scoped organization prevents file collisions, clarifies ownership, and scales naturally as projects grow.

**Repository-Specific Layout:** See [CODEMAP.md](../CODEMAP.md) for THIS repository's actual directory names and structure.

**Full Rules:** See [.claude/constraints/repository-structure.md](.claude/constraints/repository-structure.md)

---

## Quick Decision Guide

### "Where should this code go?"

**Decision Framework:**

```
Service-specific code? → {source-directory}/{ServiceName}/
   - Backend logic, APIs, business rules
   - Only used by one service/domain

Frontend application? → {app-directory}/{ServiceName}/
   - User interfaces, web apps
   - Service-specific frontend

Shared code (used by 2+ services)? → {shared}/{LibraryName}/
   - Cross-cutting concerns
   - Reusable utilities, patterns
   - Must be truly generic

Infrastructure? → {infrastructure}/{service-name}/{environment}/
   - Deployment configurations
   - Environment-specific settings

Tests? → {tests}/{MirrorSourcePath}/
   - Mirrors source structure
```

**Repository-Specific Paths:** See [CODEMAP.md](../CODEMAP.md) for actual directory names.

### "When should I create shared code?"

**Create shared library ONLY when:**

- ✅ Code is used by 2+ services (actual, not hypothetical)
- ✅ Logic is truly generic (not service-specific)
- ✅ Abstraction is proven (not premature)

**Keep code service-specific when:**

- ❌ Only one service uses it (even if "could be reused")
- ❌ Logic contains service-specific assumptions
- ❌ Not proven to be reusable yet

**Why:** Avoid premature abstraction. Locality beats DRY until proven otherwise.

---

## Development Principles

### 1. AI-First Development

This repository is optimized for Claude Code:

- **Context engineering** over prompt engineering
- Explicit conventions, no tribal knowledge
- Structured documentation for AI parsing
- Examples demonstrate patterns

### 2. Twelve-Factor Principles

Modern applications should follow twelve-factor principles:

- **Codebase:** One codebase tracked in version control
- **Dependencies:** Explicitly declare and isolate dependencies
- **Config:** Store configuration in environment variables
- **Backing services:** Treat backing services as attached resources
- **Build, release, run:** Strictly separate build and run stages
- **Processes:** Execute the app as one or more stateless processes
- **Port binding:** Export services via port binding
- **Concurrency:** Scale out via the process model
- **Disposability:** Maximize robustness with fast startup and graceful shutdown
- **Dev/prod parity:** Keep development, staging, and production as similar as possible
- **Logs:** Treat logs as event streams
- **Admin processes:** Run admin/management tasks as one-off processes

### 3. Explicit Over Implicit

- No magic, no hidden conventions
- Document decisions with rationale
- Predictable patterns
- AI-parseable structure

### 4. Minimal Operational Burden

- Infrastructure as code (version controlled, reproducible)
- Automated testing and deployment
- Clear, discoverable documentation
- Reproducible environments

---

## Working with Claude Code

### Multi-Session Workflow (Best Practice 2025/2026)

Run **multiple parallel sessions** for maximum productivity:

- Separate sessions for independent features
- Dedicated sessions for test writing
- Separate session for documentation updates
- Code review in isolated session

**Benefit:** Parallelization increases throughput while maintaining quality through separation of concerns.

### Context Management

**This file (.claude/CLAUDE.md) is auto-loaded** into Claude Code sessions.

**For repository-specific details:**

- **[CODEMAP.md](../CODEMAP.md)** - This repository's structure, technology stack, and patterns
- **[.claude/guidelines/](guidelines/)** - Best practices for specific technologies in use
- **[.claude/constraints/](constraints/)** - Mandatory architectural rules

**For understanding principles:**

- **[.claude/philosophy/](philosophy/)** - Operating model and mindset (e.g., solo developer constraints)
- **[.claude/rules/](rules/)** - Hard invariants that must be followed

### Strong Test Suites Enable Fast Iteration

**Workflow:**

1. Write test first (or ask Claude to)
2. Implement feature
3. Run test suite
4. Fix failures
5. Repeat

**Why:** Fast feedback loops enable Claude Code to iterate quickly with confidence.

### Verification Checklist

Before accepting AI-generated code:

- ✅ Tests pass (run the test suite)
- ✅ No security vulnerabilities (secrets exposed, injection risks, XSS)
- ✅ Follows established architecture patterns (see CODEMAP.md)
- ✅ Placed in correct directory (see Quick Decision Guide above)
- ✅ Documentation updated if introducing new patterns

---

## Anti-Patterns (What NOT to Do)

**Repository Organization:**
❌ **Don't** place source files directly in top-level directories (must be in service subdirectories)
❌ **Don't** create shared code until used by 2+ services (avoid premature abstraction)
❌ **Don't** mix concerns (keep service-specific code in service directories)

**Security:**
❌ **Don't** commit secrets to version control (use environment variables or secret management)
❌ **Don't** hardcode credentials, API keys, or passwords
❌ **Don't** expose sensitive data in logs or error messages

**Development Practices:**
❌ **Don't** skip tests when adding features (maintain test coverage)
❌ **Don't** create abstractions before proven necessary (locality beats DRY)
❌ **Don't** use implicit conventions (explicit is better than implicit)

**Repository-Specific Anti-Patterns:** See [CODEMAP.md](../CODEMAP.md) for technology-specific patterns to avoid.

---

## Navigation & References

### Quick Questions

**"Where does this code go?"** → See "Quick Decision Guide" section above

**"What technology does this repository use?"** → See [CODEMAP.md](../CODEMAP.md)

**"What are the architectural patterns?"** → See [CODEMAP.md](../CODEMAP.md) and [.claude/guidelines/](guidelines/)

**"What are the mandatory rules?"** → See [.claude/constraints/](constraints/) and [.claude/rules/](rules/)

### .claude/ Directory Structure

- **[guidelines/](guidelines/)** - Best practices for specific technologies (should follow, can deviate with justification)
- **[constraints/](constraints/)** - Mandatory architectural rules (must follow, no exceptions)
- **[preferences/](preferences/)** - Default technology choices (deviations require justification)
- **[rules/](rules/)** - Hard invariants enforced across all code (must follow)
- **[philosophy/](philosophy/)** - Operating model and mental frameworks (guides thinking)

### Repository-Specific Documentation

- **[CODEMAP.md](../CODEMAP.md)** - THIS repository's structure, technology stack, and implementation patterns
- **[docs/](../docs/)** - Additional human-facing documentation

---

## Quick Reference: Common Patterns

### Backend (C# + Minimal API)

**Core Patterns:**
- Minimal API (one endpoint per file, static classes)
- Records for DTOs (immutability by default)
- Repository pattern for data access
- Policy services for authorization

**Detailed Guidance:**
- Architecture → [csharp/minimal-api.md](csharp/minimal-api.md), [csharp/basics.md](csharp/basics.md)
- Database → [guidelines/dynamodb.md](guidelines/dynamodb.md)
- Testing → [csharp/testing.md](csharp/testing.md)

### Frontend (Vue.js + TypeScript)

**Core Patterns:**
- Composition API (not Options API)
- **TanStack Query for all server state** (queries, mutations, caching)
- Pinia for client state only (UI preferences, current selections)
- Auto-generated types from OpenAPI

**Detailed Guidance:**
- Data fetching → [guidelines/frontend.md](guidelines/frontend.md) (TanStack Query patterns)
- State management → [guidelines/frontend.md](guidelines/frontend.md#state-management-pinia)
- Component patterns → [guidelines/frontend.md](guidelines/frontend.md)
- Testing → [guidelines/frontend.md](guidelines/frontend.md#testing)

**Decision Records:** See repository's `docs/decisions/` directory for technology adoption rationale and architectural decisions

### Infrastructure (Terraform + AWS)

**Core Patterns:**
- Serverless-first (Lambda, DynamoDB, S3)
- Zero-cost-when-idle architecture
- Single-table design for DynamoDB

**Detailed Guidance:**
- Infrastructure → [guidelines/terraform.md](guidelines/terraform.md)
- Database modeling → [guidelines/dynamodb.md](guidelines/dynamodb.md)
- CI/CD → [guidelines/cicd.md](guidelines/cicd.md)

---

## Summary for Claude Code

**Generic Principles (apply to ANY repository):**

1. **Service-Scoped Organization:** No source files directly in top-level directories
2. **Avoid Premature Abstraction:** Shared code only when used by 2+ services
3. **Explicit Over Implicit:** No magic, document decisions, predictable patterns
4. **Test-Driven Development:** Write tests first, iterate with fast feedback
5. **Multi-Session Workflow:** Parallelize work across independent sessions
6. **Security First:** Never commit secrets, validate at boundaries
7. **Twelve-Factor Principles:** Config in environment, stateless processes, dev/prod parity

**Repository-Specific Details:**

- **Technology Stack:** See [CODEMAP.md](../CODEMAP.md)
- **Architecture Patterns:** See [CODEMAP.md](../CODEMAP.md) and [.claude/guidelines/](guidelines/)
- **Mandatory Rules:** See [.claude/constraints/](constraints/) and [.claude/rules/](rules/)

**Your Goal:** Generate code that follows established patterns (generic and repository-specific), is placed correctly, passes tests, and maintains security and quality standards.

---

_This file is generic and reusable across repositories. See [CODEMAP.md](../CODEMAP.md) for THIS repository's specifics._
