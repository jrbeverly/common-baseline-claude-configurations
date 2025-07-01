# Core Principles (Invariant Rules)

**Status:** INVARIANT - These principles cannot be violated.

**Purpose:** Define fundamental rules that ensure repository integrity, AI-friendliness, and solo developer productivity.

---

## 1. Explicit Over Implicit

**Rule:** All conventions, patterns, and decisions must be explicit and documented.

**Why:**
- AI assistants cannot infer tribal knowledge
- New developers (or you in 6 months) need clarity
- Documentation as architecture principle

**In Practice:**
- ✅ Document technology choices with rationale
- ✅ Explicit configuration over convention
- ✅ Clear naming conventions
- ✅ Code comments explain "why", not "what"
- ❌ No magic, no hidden conventions
- ❌ No undocumented assumptions

**Example:**
```csharp
// ✅ GOOD: Explicit intent
public static class GetUserEndpoint
{
    // Uses JWT bearer token from Authorization header
    // Validates user has permission to access requested user ID
    public static void MapGetUser(this IEndpointRouteBuilder app) { /* ... */ }
}

// ❌ BAD: Implicit magic
public class UserController : BaseController { /* ... */ }
// What does BaseController do? Where is auth logic?
```

---

## 2. AI-First Development

**Rule:** Repository structure and documentation must be optimized for AI code generation.

**Why:**
- Claude Code and AI assistants are primary development tools
- AI works best with predictable patterns and explicit context
- Solo developer productivity depends on AI effectiveness

**In Practice:**
- ✅ Predictable directory structure
- ✅ Consistent naming conventions
- ✅ Machine-readable documentation
- ✅ CLAUDE.md auto-loaded for context
- ✅ Examples demonstrate patterns
- ❌ No clever abstractions that confuse AI
- ❌ No implicit dependencies

**Example:**
```
✅ GOOD: AI can infer structure
src/LibraryService/LibraryService.Api/Endpoints/Users/GetUserEndpoint.cs

❌ BAD: Unclear structure
src/Services/Library/API/Modules/User/GetEndpoint.cs
```

---

## 3. Zero-Cost-When-Idle

**Rule:** Infrastructure must cost $0 (or near-zero) when not in use.

**Why:**
- Solo developer budget constraints
- Personal projects have unpredictable, often near-zero traffic
- Pay only for actual usage

**In Practice:**
- ✅ Lambda (pay per invocation)
- ✅ DynamoDB on-demand (pay per request)
- ✅ S3 (pay per GB stored)
- ✅ CloudFront (pay per transfer)
- ❌ No always-on RDS
- ❌ No EC2 instances running 24/7
- ❌ No NAT Gateways (use VPC endpoints)

**Exception:** Only allowed when explicitly justified and documented.

**Example:**
```hcl
# ✅ GOOD: Serverless, scales to zero
resource "aws_lambda_function" "api" {
  # Pay only when invoked
}

# ❌ BAD: Always-on costs
resource "aws_db_instance" "main" {
  instance_class = "db.t3.micro"  # ~$15/month even at 0 traffic
}
```

---

## 4. Service-Scoped Structure

**Rule:** No source files directly in top-level directories (`src/`, `app/`, `env/`).

**Why:**
- Prevents merge conflicts
- Enables repository merging without collisions
- Clear service boundaries
- Scalable from 1 to N services

**In Practice:**
- ✅ `src/{ServiceName}/` for backend
- ✅ `app/{ServiceName}/` for frontend
- ✅ `env/{service-name}/` for infrastructure
- ❌ Never `src/Program.cs` (no service scope)
- ❌ Never `app/main.ts` (no service scope)

**This is non-negotiable.** See [constraints/repository-structure.md](../constraints/repository-structure.md)

---

## 5. Test-Driven Development

**Rule:** All non-trivial code must have automated tests.

**Why:**
- Strong test suites enable "flying through projects" with AI
- Catch regressions early
- Tests serve as documentation
- AI can iterate quickly with test feedback

**In Practice:**
- ✅ Test pyramid: 60% unit, 30% integration, 10% E2E
- ✅ Write tests before or immediately after implementation
- ✅ Tests mirror source structure
- ✅ Run tests in CI/CD
- ❌ No "we'll test later"
- ❌ No skipping tests for "simple" code

**Minimum:**
- Unit tests for business logic
- Integration tests for data access
- E2E tests for critical user flows

---

## 6. Documentation as Architecture

**Rule:** Architecture is defined by documentation, not just described by it.

**Why:**
- Documentation drives development
- AI assistants use documentation to make decisions
- Rationale preserved over time
- Prevents architecture decay

**In Practice:**
- ✅ Architectural decisions documented with rationale (CLOD-MD format)
- ✅ Constraints made explicit
- ✅ Examples demonstrate patterns
- ✅ Update docs in same PR as code
- ❌ No "code is self-documenting"
- ❌ No stale documentation

**CLOD-MD Format:**
```markdown
## Purpose
What problem does this solve?

## Context
Background and environment

## Approach
How it works

## Constraints
Limitations and boundaries

## Decisions
Choices made with rationale

## Examples
Concrete demonstrations

## Evolution
How to extend and modify
```

---

## 7. Dependency Direction

**Rule:** Dependencies flow one direction: specific → shared → external.

**Why:**
- Prevents circular dependencies
- Enables independent testing
- Clear mental model
- Shared code is truly reusable

**In Practice:**
```
Services (src/, app/)
    ↓ can depend on
Shared Libraries (lib/)
    ↓ can depend on
External Packages (NuGet, npm)
```

**Forbidden:**
- ❌ Shared libraries (`lib/`) depending on services (`src/`, `app/`)
- ❌ Circular dependencies between services
- ❌ Service A directly depending on Service B (use events/APIs)

**Example:**
```csharp
// ✅ GOOD: Service depends on shared library
// src/LibraryService/LibraryService.Api/Program.cs
using Common.Logging;  // lib/Common.Logging/

// ❌ BAD: Shared library depends on service
// lib/Common.Logging/Logger.cs
using LibraryService.Domain;  // WRONG! Reverse dependency
```

---

## 8. Interface-Based Design

**Rule:** Favor interfaces and composition over inheritance.

**Why:**
- Testability (easy to mock)
- Flexibility (swap implementations)
- AI-friendly (explicit contracts)
- SOLID principles

**In Practice:**
- ✅ Define interfaces for services
- ✅ Inject dependencies via constructor
- ✅ Composition over inheritance
- ❌ No deep inheritance hierarchies
- ❌ No hidden dependencies (static singletons)

**Example:**
```csharp
// ✅ GOOD: Interface-based
public interface IUserService
{
    Task<User> GetUserAsync(Guid id);
}

public class UserService : IUserService
{
    private readonly IUserRepository _repository;

    public UserService(IUserRepository repository)
    {
        _repository = repository;  // Injected dependency
    }
}

// ❌ BAD: Inheritance-based
public abstract class BaseService { /* ... */ }
public class UserService : BaseService { /* ... */ }
// Hidden dependencies, hard to test
```

---

## 9. Immutability Where Possible

**Rule:** Prefer immutable data structures (C# records, readonly properties).

**Why:**
- Thread safety
- Easier reasoning about state
- Fewer bugs from unexpected mutations
- AI-friendly (predictable behavior)

**In Practice:**
- ✅ Use C# records for DTOs and domain entities
- ✅ `init` instead of `set`
- ✅ `readonly` for collections
- ✅ `with` expressions for updates
- ❌ Avoid mutable state where possible

**Example:**
```csharp
// ✅ GOOD: Immutable record
public record User
{
    public required Guid Id { get; init; }
    public required string Email { get; init; }
    public required string Name { get; init; }
}

var updated = user with { Name = "New Name" };  // Creates new instance

// ❌ BAD: Mutable class
public class User
{
    public Guid Id { get; set; }
    public string Email { get; set; }
    public string Name { get; set; }
}

user.Name = "New Name";  // Mutates existing instance
```

---

## 10. Fail Fast with Clear Errors

**Rule:** Validate early, fail fast, provide actionable error messages.

**Why:**
- Bugs caught early are cheaper to fix
- Clear errors reduce debugging time
- AI can fix errors faster with clear messages

**In Practice:**
- ✅ Validate at boundaries (API request DTOs)
- ✅ Use FluentValidation for complex validation
- ✅ Throw exceptions with clear messages
- ✅ Return Problem Details (RFC 7807)
- ❌ No silent failures
- ❌ No generic "An error occurred"

**Example:**
```csharp
// ✅ GOOD: Early validation with clear error
public class CreateUserRequestValidator : AbstractValidator<CreateUserRequest>
{
    public CreateUserRequestValidator()
    {
        RuleFor(x => x.Email)
            .NotEmpty().WithMessage("Email is required")
            .EmailAddress().WithMessage("Email must be valid");
    }
}

// Returns: 400 Bad Request with specific field errors

// ❌ BAD: Late validation, vague error
public async Task CreateUser(CreateUserRequest request)
{
    await _db.SaveAsync(new User { Email = request.Email });
    // Fails at database with generic "constraint violation"
}
```

---

## Summary

These 10 core principles are **non-negotiable**:

1. **Explicit Over Implicit** - Document everything
2. **AI-First Development** - Optimize for AI code generation
3. **Zero-Cost-When-Idle** - Serverless by default
4. **Service-Scoped Structure** - No top-level source files
5. **Test-Driven Development** - All code has tests
6. **Documentation as Architecture** - Docs define architecture
7. **Dependency Direction** - One-way flow (specific → shared → external)
8. **Interface-Based Design** - Composition over inheritance
9. **Immutability Where Possible** - Records and readonly
10. **Fail Fast with Clear Errors** - Validate early, clear messages

**Violation of these principles indicates a fundamental problem that must be addressed.**

---

*These are invariant rules. They have no exceptions.*
