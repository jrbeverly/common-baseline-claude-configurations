# C# Basics - Modern Patterns (2025-2026)

**Purpose:** Comprehensive guide to modern C# patterns for minimal API codebases.

**Target:** C# 12 / .NET 8+ with emphasis on compile-time safety, explicit code, and AI-friendly patterns.

---

## Philosophy

This repository follows modern C# development principles:

- **Compile-time over runtime** - Source generators, not reflection
- **Explicit over implicit** - No magic, everything traceable
- **Immutability by default** - Records, init properties, value equality
- **AI-first development** - Predictable patterns that AI can understand and generate
- **Minimal abstraction** - YAGNI (You Aren't Gonna Need It) until proven necessary

---

## 1. Records & Immutability

**Records are the default choice** for DTOs, value objects, and immutable data structures.

### Basic Record Syntax

```csharp
// Simple record with positional parameters
public record User(Guid Id, string Email, string Name);

// Record with explicit properties (preferred for clarity)
public record User
{
    public required Guid Id { get; init; }
    public required string Email { get; init; }
    public required string Name { get; init; }
}
```

### Benefits

- **Value equality** - Compares all properties automatically
- **Immutability** - Cannot be mutated after creation (thread-safe)
- **with expressions** - Create modified copies easily
- **Less boilerplate** - No manual Equals/GetHashCode

### Using with Expressions

```csharp
var user = new User
{
    Id = Guid.NewGuid(),
    Email = "alice@example.com",
    Name = "Alice"
};

// Create modified copy
var updated = user with { Name = "Alice Smith" };
// user.Name is still "Alice"
// updated.Name is "Alice Smith"
```

### When to Use Records vs Classes

| Use Records For | Use Classes For |
|----------------|-----------------|
| DTOs (request/response) | Entities with identity |
| Value objects (Email, Money) | Mutable state machines |
| Domain events | EF Core entities (often) |
| Immutable data | Complex lifecycle management |

**Trade-off:** Records have slight overhead for value equality on large objects with many properties. Profile before optimizing.

---

## 2. Required Properties (C# 11)

**Compile-time guarantee** that properties are initialized.

```csharp
public record CreateUserRequest
{
    public required string Email { get; init; }
    public required string Name { get; init; }
    public int Age { get; init; } = 18; // Optional with default
}

// ✅ Compiles - all required properties set
var request = new CreateUserRequest
{
    Email = "test@example.com",
    Name = "Test User"
};

// ❌ Compile error - required properties not set
var invalid = new CreateUserRequest();
```

### Benefits

- **Compiler enforces initialization** - No runtime NullReferenceException
- **Self-documenting** - Clear which properties are mandatory
- **AI-friendly** - Explicit contracts

⚠️ **Avoid:** Nullable properties when you mean "required but might be missing" - use `required` instead.

---

## 3. Primary Constructors (C# 12)

**Reduce boilerplate** for dependency injection without explicit field declarations.

```csharp
// Traditional constructor injection
public class UserService
{
    private readonly IUserRepository _repository;
    private readonly ILogger<UserService> _logger;

    public UserService(IUserRepository repository, ILogger<UserService> logger)
    {
        _repository = repository;
        _logger = logger;
    }

    public async Task<User?> GetUserAsync(Guid id)
    {
        _logger.LogInformation("Getting user {UserId}", id);
        return await _repository.GetByIdAsync(id);
    }
}

// Primary constructor (C# 12)
public class UserService(IUserRepository repository, ILogger<UserService> logger)
{
    public async Task<User?> GetUserAsync(Guid id)
    {
        logger.LogInformation("Getting user {UserId}", id);
        return await repository.GetByIdAsync(id);
    }
}
```

### When to Use

- ✅ Services with few dependencies (<5)
- ✅ Immutable classes
- ✅ When you only use parameters in methods (not need private fields)

### When NOT to Use

- ❌ Need to store parameters as private fields for later mutation
- ❌ Complex initialization logic in constructor body

---

## 4. File-Scoped Namespaces (C# 10)

**Reduce nesting** by one level.

```csharp
// Old style (extra indentation)
namespace LibraryService.Routes.Users.v1
{
    public static class UserGetRoute
    {
        // Everything indented
    }
}

// Modern file-scoped namespace
namespace LibraryService.Routes.Users.v1;

public static class UserGetRoute
{
    // No extra indentation
}
```

**Benefit:** Cleaner code, easier to read, AI-friendly.

---

## 5. Collection Expressions (C# 12)

**Unified syntax** for creating arrays, lists, and spans.

```csharp
// Traditional
var numbers = new List<int> { 1, 2, 3 };
var array = new int[] { 1, 2, 3 };

// Modern collection expressions
int[] numbers = [1, 2, 3];
List<int> list = [1, 2, 3];
Span<int> span = [1, 2, 3];

// Spread operator for combining
int[] first = [1, 2];
int[] second = [3, 4];
int[] combined = [.. first, .. second]; // [1, 2, 3, 4]
```

**Benefit:** Target-typed (compiler infers collection type), cleaner syntax.

---

## 6. Pattern Matching

### Switch Expressions

```csharp
// Traditional switch statement
string GetStatus(OrderStatus status)
{
    switch (status)
    {
        case OrderStatus.Draft:
            return "Order is being prepared";
        case OrderStatus.Submitted:
            return "Order submitted";
        case OrderStatus.Completed:
            return "Order completed";
        default:
            return "Unknown status";
    }
}

// Modern switch expression
string GetStatus(OrderStatus status) => status switch
{
    OrderStatus.Draft => "Order is being prepared",
    OrderStatus.Submitted => "Order submitted",
    OrderStatus.Completed => "Order completed",
    _ => "Unknown status"
};
```

### Property Patterns

```csharp
public record User
{
    public required Guid Id { get; init; }
    public required string Email { get; init; }
    public bool IsActive { get; init; }
}

// Pattern match on properties
string GetUserStatus(User user) => user switch
{
    { IsActive: true } => "Active user",
    { IsActive: false } => "Inactive user",
    null => "No user"
};

// Combine patterns
if (user is { IsActive: true, Email: var email })
{
    _logger.LogInformation("Active user: {Email}", email);
}
```

### List Patterns (C# 11)

```csharp
int[] numbers = [1, 2, 3, 4, 5];

var result = numbers switch
{
    [] => "Empty",
    [var first] => $"Single: {first}",
    [var first, var second] => $"Two: {first}, {second}",
    [var first, .. var rest] => $"First: {first}, Rest: {rest.Length}",
    _ => "Unknown"
};
```

---

## 7. Nullable Reference Types

**Enable in .csproj:**

```xml
<PropertyGroup>
    <Nullable>enable</Nullable>
</PropertyGroup>
```

### Explicit Null Handling

```csharp
public interface IUserService
{
    // Explicit: Can return null
    Task<User?> GetUserAsync(Guid id);

    // Explicit: Never returns null
    Task<User> CreateUserAsync(Email email, string name);
}

public class UserService(IUserRepository repository) : IUserService
{
    public async Task<User?> GetUserAsync(Guid id)
    {
        var user = await repository.GetByIdAsync(id);
        return user; // Compiler ensures null handling
    }

    public async Task<User> CreateUserAsync(Email email, string name)
    {
        var user = User.Create(email, name);
        await repository.SaveAsync(user);
        return user; // Compiler enforces non-null return
    }
}
```

### Benefits

- Compile-time null safety
- Clear API contracts (`User?` vs `User`)
- Fewer NullReferenceExceptions

⚠️ **Avoid:** Using `!` null-forgiving operator without justification - fix the underlying issue instead.

---

## 8. Value Objects & Domain Modeling

**Wrap primitives** to enforce invariants and convey meaning.

### Private Constructor + Factory Method Pattern

```csharp
public record Email
{
    public string Value { get; }

    private Email(string value)
    {
        Value = value;
    }

    public static Result<Email> Create(string email)
    {
        if (string.IsNullOrWhiteSpace(email))
            return Result<Email>.Failure(new Error("E100", "Email cannot be empty"));

        if (!email.Contains('@'))
            return Result<Email>.Failure(new Error("E101", "Email must contain @"));

        if (email.Length > 255)
            return Result<Email>.Failure(new Error("E102", "Email too long"));

        return Result<Email>.Success(new Email(email.ToLowerInvariant()));
    }

    public override string ToString() => Value;
}
```

### Strongly-Typed IDs

```csharp
// ❌ Primitive obsession - easy to mix up parameters
public void TransferBook(Guid fromLibraryId, Guid toLibraryId, Guid bookId, int durationDays) { }

// ✅ Strongly-typed IDs - compiler prevents mistakes
public record LibraryId
{
    public Guid Value { get; }

    private LibraryId(Guid value) => Value = value;

    public static LibraryId Create() => new(Guid.NewGuid());

    public static Result<LibraryId> From(Guid id)
    {
        if (id == Guid.Empty)
            return Result<LibraryId>.Failure(new Error("E200", "Library ID cannot be empty"));

        return Result<LibraryId>.Success(new LibraryId(id));
    }
}

public record BookId(Guid Value);

public void TransferBook(LibraryId fromLibrary, LibraryId toLibrary, BookId book, int durationDays)
{
    // Type-safe! Can't accidentally swap fromLibrary and book
}
```

### Money Value Object

```csharp
public record Money
{
    public decimal Amount { get; }
    public string Currency { get; }

    private Money(decimal amount, string currency)
    {
        Amount = amount;
        Currency = currency;
    }

    public static Result<Money> Create(decimal amount, string currency)
    {
        if (amount < 0)
            return Result<Money>.Failure(new Error("E300", "Amount cannot be negative"));

        if (string.IsNullOrWhiteSpace(currency) || currency.Length != 3)
            return Result<Money>.Failure(new Error("E301", "Currency must be 3-letter code"));

        return Result<Money>.Success(new Money(amount, currency.ToUpperInvariant()));
    }

    public Money Add(Money other)
    {
        if (Currency != other.Currency)
            throw new InvalidOperationException($"Cannot add {Currency} to {other.Currency}");

        return new Money(Amount + other.Amount, Currency);
    }
}
```

### When to Create Value Objects

- ✅ Domain concepts appearing 3+ times
- ✅ Validation rules needed
- ✅ Could be confused with other primitives (multiple Guid parameters)
- ✅ Semantic meaning (Email is not just a string)

⚠️ **Avoid:** Primitive obsession - using `string` for email, `Guid` for typed IDs, `decimal` for money.

---

## 9. Source Generators & Compiler Platform

**Compile-time code generation** for repetitive patterns.

### IIncrementalGenerator (Recommended Pattern)

```csharp
[Generator]
public class DynamoDbMappingGenerator : IIncrementalGenerator
{
    public void Initialize(IncrementalGeneratorInitializationContext context)
    {
        // Use ForAttributeWithMetadataName (.NET 7+) for attribute-driven generation
        var provider = context.SyntaxProvider
            .ForAttributeWithMetadataName(
                "DynamoDbEntityAttribute",
                predicate: (node, _) => node is ClassDeclarationSyntax,
                transform: (ctx, _) => GetEntityInfo(ctx))
            .Where(info => info is not null);

        context.RegisterSourceOutput(provider, GenerateMappingCode);
    }

    private static EntityInfo? GetEntityInfo(GeneratorAttributeSyntaxContext context)
    {
        // Extract entity metadata
        var classSymbol = (INamedTypeSymbol)context.TargetSymbol;
        return new EntityInfo(classSymbol.Name, classSymbol.ContainingNamespace.ToString());
    }

    private void GenerateMappingCode(SourceProductionContext context, EntityInfo? entityInfo)
    {
        if (entityInfo is null) return;

        var source = $$"""
            namespace {{entityInfo.Namespace}};

            public static class {{entityInfo.Name}}Extensions
            {
                public static Dictionary<string, AttributeValue> ToDynamoDb(this {{entityInfo.Name}} entity)
                {
                    return new Dictionary<string, AttributeValue>
                    {
                        ["PK"] = new AttributeValue { S = $"USER#{entity.Id}" },
                        ["SK"] = new AttributeValue { S = "PROFILE" },
                        ["Email"] = new AttributeValue { S = entity.Email }
                    };
                }
            }
            """;

        context.AddSource($"{entityInfo.Name}Extensions.g.cs", source);
    }
}

record EntityInfo(string Name, string Namespace);
```

### When to Use Source Generators

| Scenario | Use Source Generator | Use Explicit Code |
|----------|---------------------|-------------------|
| 10+ files with repetitive mapping | ✅ Yes | ❌ No |
| AOT scenarios (Native AOT) | ✅ Yes | ❌ No |
| Performance-critical serialization | ✅ Yes | Maybe |
| One-off mapping | ❌ No | ✅ Yes |
| Simple 1:1 property mapping | ❌ No | ✅ Yes |

### Best Practices

1. **Use IIncrementalGenerator** (not deprecated ISourceGenerator)
2. **Use ForAttributeWithMetadataName** (.NET 7+) for attribute-driven generation
3. **Filter early** in the pipeline to reduce recomputation
4. **Use value types** (records, structs) in pipeline for better caching
5. **Break into small steps** for incremental compilation benefits

⚠️ **Avoid:** Premature source generators - start with explicit code until pattern repeats 10+ times.

### Roslyn Analyzers

**Custom compile-time rules** to enforce patterns.

```csharp
[DiagnosticAnalyzer(LanguageNames.CSharp)]
public class RequireResultPatternAnalyzer : DiagnosticAnalyzer
{
    private static readonly DiagnosticDescriptor Rule = new(
        id: "APP001",
        title: "Use Result<T> instead of bool",
        messageFormat: "Method '{0}' returns bool - consider using Result<T> for explicit error handling",
        category: "Design",
        defaultSeverity: DiagnosticSeverity.Warning,
        isEnabledByDefault: true);

    public override ImmutableArray<DiagnosticDescriptor> SupportedDiagnostics =>
        ImmutableArray.Create(Rule);

    public override void Initialize(AnalysisContext context)
    {
        context.ConfigureGeneratedCodeAnalysis(GeneratedCodeAnalysisFlags.None);
        context.EnableConcurrentExecution();
        context.RegisterSyntaxNodeAction(AnalyzeMethod, SyntaxKind.MethodDeclaration);
    }

    private void AnalyzeMethod(SyntaxNodeAnalysisContext context)
    {
        var method = (MethodDeclarationSyntax)context.Node;

        // Enforce: Public methods returning bool should use Result<T>
        if (method.ReturnType.ToString() == "bool" &&
            method.Modifiers.Any(SyntaxKind.PublicKeyword))
        {
            var diagnostic = Diagnostic.Create(Rule, method.Identifier.GetLocation(), method.Identifier.Text);
            context.ReportDiagnostic(diagnostic);
        }
    }
}
```

### AOT Compatibility

**Native AOT** requires eliminating reflection:

- ✅ Source generators for serialization
- ✅ DataAnnotations with .NET 10+ (source-generated validation)
- ✅ Explicit mapping methods
- ❌ Avoid AutoMapper (uses reflection)
- ❌ Avoid FluentValidation (runtime-based)
- ❌ Avoid convention-based model binding

---

## 10. Minimal API Patterns

**Static nested classes** for explicit, testable endpoints.

### Complete Endpoint Structure

```csharp
namespace LibraryService.Routes.Users.v1;

public static class UserGetRoute
{
    public const string ResourceName = "user";
    public const int Version = 1;

    public static class Registration
    {
        public static RouteHandlerBuilder Map(RouteGroupBuilder group)
        {
            return group.MapGet("/{userId:guid}", Handler.HandleAsync)
                .WithName("GetUser")
                .WithTags("Users")
                .RequireAuthorization()
                .WithApiVersioning(ResourceName, Version)
                .ProducesVersioned<Response>(ResourceName, Version)
                .Produces(StatusCodes.Status404NotFound)
                .Produces(StatusCodes.Status401Unauthorized);
        }
    }

    public record Response
    {
        public required Guid Id { get; init; }
        public required string Email { get; init; }
        public required string Name { get; init; }
    }

    public static class Handler
    {
        public static async Task<IResult> HandleAsync(
            [FromRoute] Guid userId,
            ClaimsPrincipal user,
            IUserService userService)
        {
            var currentUserId = AuthHelpers.ExtractUserId(user);
            if (currentUserId is null)
                return TypedResults.Unauthorized();

            var result = await userService.GetUserAsync(userId);
            if (result.IsFailure)
                return TypedResults.NotFound();

            var userData = result.Value;
            return TypedResults.Ok(new Response
            {
                Id = userData.Id,
                Email = userData.Email,
                Name = userData.Name
            });
        }
    }
}
```

### POST Endpoint with Validation

```csharp
namespace LibraryService.Routes.Users.v1;

public static class UserCreateRoute
{
    public const string ResourceName = "user-create";
    public const int Version = 1;

    public static class Registration
    {
        public static RouteHandlerBuilder Map(RouteGroupBuilder group)
        {
            return group.MapPost("/", Handler.HandleAsync)
                .WithName("CreateUser")
                .WithApiVersioning(ResourceName, Version)
                .AcceptsVersioned<Request>(ResourceName, Version)
                .ProducesVersioned<Response>(ResourceName, Version)
                .Produces(StatusCodes.Status400BadRequest); // Automatic validation
        }
    }

    public record Request
    {
        [Required(ErrorMessage = "Email is required")]
        [EmailAddress(ErrorMessage = "Email must be valid")]
        public required string Email { get; init; }

        [Required(ErrorMessage = "Name is required")]
        [MaxLength(100, ErrorMessage = "Name cannot exceed 100 characters")]
        public required string Name { get; init; }
    }

    public record Response
    {
        public required Guid Id { get; init; }
    }

    public static class Handler
    {
        public static async Task<IResult> HandleAsync(
            [FromBody] Request request,
            IUserService userService)
        {
            // Validation already done by framework (.NET 10+)
            var result = await userService.CreateUserAsync(request.Email, request.Name);

            return result.IsSuccess
                ? TypedResults.Created($"/users/{result.Value}", new Response { Id = result.Value })
                : TypedResults.BadRequest(result.Error);
        }
    }
}
```

### Benefits

- ✅ **Explicit** - No magic model binding, clear parameter sources
- ✅ **Testable** - Static methods, easy to unit test
- ✅ **Versioned** - Namespace versioning (`v1`, `v2`)
- ✅ **Self-contained** - Everything for endpoint in one file
- ✅ **AI-friendly** - Predictable structure

⚠️ **Avoid:** Controllers - use Minimal API for explicit, testable handlers.

**See Also:** [minimal-api.md](minimal-api.md) for complete patterns.

---

## 11. Dependency Injection & Services

### Interface-Based Design

```csharp
public interface IUserService
{
    Task<Result<User>> GetUserAsync(Guid id);
    Task<Result<Guid>> CreateUserAsync(Email email, string name);
}

public class UserService(
    IUserRepository repository,
    ILogger<UserService> logger) : IUserService
{
    public async Task<Result<User>> GetUserAsync(Guid id)
    {
        logger.LogInformation("Getting user {UserId}", id);

        var user = await repository.GetByIdAsync(id);
        return user is not null
            ? Result<User>.Success(user)
            : Result<User>.Failure(new Error("E201", "User not found"));
    }

    public async Task<Result<Guid>> CreateUserAsync(Email email, string name)
    {
        // Check if user already exists
        var existing = await repository.GetByEmailAsync(email);
        if (existing is not null)
            return Result<Guid>.Failure(new Error("E202", "User already exists"));

        var user = User.Create(email, name);
        await repository.SaveAsync(user);

        logger.LogInformation("Created user {UserId}", user.Id);
        return Result<Guid>.Success(user.Id);
    }
}
```

### Service Registration

```csharp
// Program.cs
builder.Services.AddScoped<IUserService, UserService>();
builder.Services.AddScoped<IUserRepository, UserRepository>();
builder.Services.AddSingleton<IEmailService, EmailService>();
```

### Service Lifetimes

| Lifetime | When Created | When Disposed | Use For |
|----------|--------------|---------------|---------|
| **Scoped** | Once per request | End of request | Repositories, business services |
| **Transient** | Every time requested | When owner disposed | Lightweight stateless services |
| **Singleton** | Once per application | Application shutdown | Caches, configuration |

### Composition Over Inheritance

```csharp
// ❌ Avoid: Inheritance for shared behavior
public abstract class BaseService
{
    protected ILogger Logger { get; }
    protected BaseService(ILogger logger) => Logger = logger;
}

public class UserService : BaseService
{
    // Hidden dependency on base class
}

// ✅ Prefer: Composition via interfaces
public interface IUserService { }
public interface IAuditService { }

public class UserService(
    IUserRepository repository,
    IAuditService auditService,
    ILogger<UserService> logger) : IUserService
{
    // Explicit dependencies, easy to test
}
```

---

## 12. Error Handling

### Result Pattern

**Explicit error handling** in the type system.

```csharp
public record Result<T>
{
    public T? Value { get; }
    public Error? Error { get; }
    public bool IsSuccess => Error is null;
    public bool IsFailure => !IsSuccess;

    private Result(T? value, Error? error)
    {
        Value = value;
        Error = error;
    }

    public static Result<T> Success(T value) => new(value, null);
    public static Result<T> Failure(Error error) => new(default, error);
}

public record Error(string Code, string Message);
```

### Error Codes

```csharp
public static class ErrorCodes
{
    // E100-E199: Email/Auth
    public const string EmailEmpty = "E100";
    public const string EmailInvalid = "E101";
    public const string EmailTooLong = "E102";

    // E200-E299: User Operations
    public const string UserExists = "E200";
    public const string UserNotFound = "E201";
    public const string UserInactive = "E202";

    // E300-E399: Book Operations
    public const string BookNotFound = "E300";
    public const string BookUnavailable = "E301";
}
```

### Railway-Oriented Programming

```csharp
public static class ResultExtensions
{
    public static Result<TOut> Map<TIn, TOut>(
        this Result<TIn> result,
        Func<TIn, TOut> mapper)
    {
        return result.IsSuccess
            ? Result<TOut>.Success(mapper(result.Value!))
            : Result<TOut>.Failure(result.Error!);
    }

    public static Result<TOut> Bind<TIn, TOut>(
        this Result<TIn> result,
        Func<TIn, Result<TOut>> binder)
    {
        return result.IsSuccess
            ? binder(result.Value!)
            : Result<TOut>.Failure(result.Error!);
    }
}

// Usage
var result = Email.Create(input)
    .Bind(email => User.Create(email, name))
    .Map(user => user.Id);

if (result.IsFailure)
{
    _logger.LogWarning("User creation failed: {Error}", result.Error.Code);
    return Results.BadRequest(result.Error);
}

return Results.Created($"/users/{result.Value}", result.Value);
```

### When to Use Exceptions vs Result

| Use Exceptions For | Use Result<T> For |
|--------------------|-------------------|
| Programming errors (null reference, index out of range) | Validation failures |
| Unrecoverable failures (out of memory, DB unreachable) | Business rule violations |
| Framework boundaries (ASP.NET expects exceptions for 500) | Expected failures (user not found) |

⚠️ **Avoid:** Exceptions for control flow - use Result<T> for validation and business logic.

**See Also:** [error-modeling.md](error-modeling.md) for Result<T> pattern details.

---

## 13. Mapping Strategies

### Explicit Extension Methods

```csharp
// Domain entity
public class User
{
    public required Guid Id { get; init; }
    public required Email Email { get; init; }
    public required string Name { get; init; }
}

// DTO
public record UserDto
{
    public required Guid Id { get; init; }
    public required string Email { get; init; }
    public required string Name { get; init; }
}

// Explicit mapping
public static class UserMappingExtensions
{
    public static UserDto ToDto(this User user)
    {
        return new UserDto
        {
            Id = user.Id,
            Email = user.Email.Value, // Unwrap value object
            Name = user.Name
        };
    }

    public static User ToEntity(this UserDto dto)
    {
        var emailResult = Email.Create(dto.Email);
        if (emailResult.IsFailure)
            throw new InvalidOperationException($"Invalid email: {emailResult.Error.Message}");

        return new User
        {
            Id = dto.Id,
            Email = emailResult.Value,
            Name = dto.Name
        };
    }
}

// Usage
var userDto = user.ToDto();
var entity = dto.ToEntity();
```

### Benefits

- ✅ **Traceable** - Clear mapping logic, easy to debug
- ✅ **Performant** - No reflection overhead
- ✅ **AI-friendly** - Explicit code generation
- ✅ **Type-safe** - Compiler catches mapping errors

### When to Use Source Generators

For **10+ entities** with repetitive mapping patterns, consider source generators:

```csharp
[AutoMap(typeof(UserDto))]
public class User
{
    public Guid Id { get; set; }
    public string Email { get; set; }
}

// Source generator creates extension methods at compile-time
```

⚠️ **Avoid:** AutoMapper for simple 1:1 mappings - use explicit extension methods.

---

## 14. DataAnnotations Validation (.NET 10+)

**Source-generated validation** with zero external dependencies.

### Setup (.NET 10+)

**Project file:**
```xml
<PropertyGroup>
    <InterceptorsNamespaces>$(InterceptorsNamespaces);Microsoft.AspNetCore.Http.Validation.Generated</InterceptorsNamespaces>
</PropertyGroup>
```

**Program.cs:**
```csharp
builder.Services.AddValidation(); // Enable built-in validation
```

### Request Validation

```csharp
public record CreateUserRequest
{
    [Required(ErrorMessage = "Email is required")]
    [EmailAddress(ErrorMessage = "Email must be valid")]
    [MaxLength(255)]
    public required string Email { get; init; }

    [Required(ErrorMessage = "Name is required")]
    [MaxLength(100)]
    public required string Name { get; init; }

    [Range(18, 120, ErrorMessage = "Age must be between 18 and 120")]
    public int Age { get; init; } = 18;
}
```

### Complex Validation with IValidatableObject

```csharp
public record CreateUserRequest : IValidatableObject
{
    [Required]
    [EmailAddress]
    public required string Email { get; init; }

    [Required]
    public required string Password { get; init; }

    [Required]
    public required string ConfirmPassword { get; init; }

    public IEnumerable<ValidationResult> Validate(ValidationContext validationContext)
    {
        if (Password != ConfirmPassword)
        {
            yield return new ValidationResult(
                "Passwords do not match",
                new[] { nameof(ConfirmPassword) }
            );
        }

        if (Password.Length < 8)
        {
            yield return new ValidationResult(
                "Password must be at least 8 characters",
                new[] { nameof(Password) }
            );
        }
    }
}
```

### Benefits

- ✅ **Source-generated** - Validation code generated at compile-time
- ✅ **AOT-compatible** - No reflection
- ✅ **Zero dependencies** - Built into .NET 10+
- ✅ **Automatic** - Framework validates before handler runs
- ✅ **Standard responses** - Returns ProblemDetails (400 Bad Request)

### For .NET 8 Projects

Use **FluentValidation** (marked as legacy for .NET 10+):

```csharp
public class CreateUserRequestValidator : AbstractValidator<CreateUserRequest>
{
    public CreateUserRequestValidator()
    {
        RuleFor(x => x.Email).NotEmpty().EmailAddress();
        RuleFor(x => x.Name).NotEmpty().MaximumLength(100);
    }
}

// Register
builder.Services.AddValidatorsFromAssemblyContaining<Program>();
```

---

## 15. Decision Framework

### Records vs Classes

| Scenario | Use Record | Use Class |
|----------|-----------|-----------|
| DTOs (request/response) | ✅ Yes | ❌ No |
| Value objects (Email, Money) | ✅ Yes | ❌ No |
| Domain events | ✅ Yes | ❌ No |
| Entities with identity | Maybe | ✅ Yes |
| Mutable state machines | ❌ No | ✅ Yes |
| EF Core entities | Maybe | ✅ Yes (often) |
| Large objects (50+ properties) | Profile first | ✅ Yes |

### Value Objects vs Primitives

| Scenario | Use Value Object | Use Primitive |
|----------|-----------------|---------------|
| Domain concept (Email, Money, LibraryId) | ✅ Yes | ❌ No |
| Appears 3+ times in codebase | ✅ Yes | Maybe |
| Has validation rules | ✅ Yes | ❌ No |
| Could be confused with other types | ✅ Yes | ❌ No |
| Internal calculations only | ❌ No | ✅ Yes |
| Temporary variables | ❌ No | ✅ Yes |

### Source Generators vs Explicit Code

| Scenario | Use Source Generator | Use Explicit Code |
|----------|---------------------|-------------------|
| 10+ files with repetitive pattern | ✅ Yes | ❌ No |
| AOT scenarios | ✅ Yes | Maybe |
| Performance-critical serialization | ✅ Yes | Maybe |
| One-off mapping | ❌ No | ✅ Yes |
| Simple 1:1 property copy | ❌ No | ✅ Yes |
| Complex transformation logic | ❌ No | ✅ Yes |

⚠️ **Avoid:** Over-abstraction - IRepository<T> + BaseRepository<T> layers. Use YAGNI - add abstraction when 3+ implementations share logic.

---

## 16. Performance & Trade-offs

### Records vs Classes Performance

**Records:**
- Value equality compares **all properties**
- Slight overhead for large objects (50+ properties)
- Thread-safe immutability
- More allocations with `with` expressions

**Classes:**
- Reference equality (compares memory address)
- Faster for large mutable objects
- Manual equality implementation needed

**Guideline:** Prefer records for clarity. Profile before optimizing. Premature optimization is the root of all evil.

### Source Generators vs Reflection

**Source Generators:**
- ✅ Zero runtime overhead
- ✅ Compile-time code generation
- ✅ AOT-compatible
- ✅ Debuggable generated code

**Reflection:**
- ❌ Runtime type inspection (slow)
- ❌ Not AOT-compatible
- ❌ Hard to debug
- ❌ Startup cost

**Guideline:** Always prefer source generators for AOT scenarios. Use explicit code until pattern repeats 10+ times.

### Immutability Overhead

**Immutable records:**
- Defensive copying when needed
- More GC pressure with frequent updates
- Thread-safe by default

**Mutable classes:**
- In-place updates (faster)
- Requires synchronization for thread safety

**Guideline:** Prefer immutability for correctness. Optimize hot paths after profiling.

---

## 17. Practical Examples

### Example 1: Complete Value Object with Validation

```csharp
public record Email
{
    public string Value { get; }

    private Email(string value) => Value = value;

    public static Result<Email> Create(string email)
    {
        if (string.IsNullOrWhiteSpace(email))
            return Result<Email>.Failure(new Error("E100", "Email cannot be empty"));

        if (!email.Contains('@'))
            return Result<Email>.Failure(new Error("E101", "Email must contain @"));

        if (email.Length > 255)
            return Result<Email>.Failure(new Error("E102", "Email too long"));

        return Result<Email>.Success(new Email(email.ToLowerInvariant()));
    }

    public override string ToString() => Value;
}

// Usage in entity
public class User
{
    public required Guid Id { get; init; }
    public required Email Email { get; private set; } // Value object, not string
    public required string Name { get; init; }

    public static Result<User> Create(Email email, string name)
    {
        if (string.IsNullOrWhiteSpace(name))
            return Result<User>.Failure(new Error("E203", "Name cannot be empty"));

        return Result<User>.Success(new User
        {
            Id = Guid.NewGuid(),
            Email = email,
            Name = name
        });
    }

    public Result ChangeEmail(Email newEmail)
    {
        if (Email == newEmail)
            return Result.Failure(new Error("E204", "Email unchanged"));

        Email = newEmail;
        return Result.Success();
    }
}
```

### Example 2: Service with Result Pattern

```csharp
public interface IUserService
{
    Task<Result<User>> GetUserAsync(Guid id);
    Task<Result<Guid>> CreateUserAsync(string email, string name);
}

public class UserService(
    IUserRepository repository,
    ILogger<UserService> logger) : IUserService
{
    public async Task<Result<User>> GetUserAsync(Guid id)
    {
        logger.LogInformation("Getting user {UserId}", id);

        var user = await repository.GetByIdAsync(id);

        return user is not null
            ? Result<User>.Success(user)
            : Result<User>.Failure(new Error("E201", "User not found"));
    }

    public async Task<Result<Guid>> CreateUserAsync(string email, string name)
    {
        // Validate email
        var emailResult = Email.Create(email);
        if (emailResult.IsFailure)
            return Result<Guid>.Failure(emailResult.Error);

        // Check if user exists
        var existing = await repository.GetByEmailAsync(emailResult.Value);
        if (existing is not null)
            return Result<Guid>.Failure(new Error("E202", "User already exists"));

        // Create user
        var userResult = User.Create(emailResult.Value, name);
        if (userResult.IsFailure)
            return Result<Guid>.Failure(userResult.Error);

        // Save to repository
        await repository.SaveAsync(userResult.Value);

        logger.LogInformation("Created user {UserId}", userResult.Value.Id);
        return Result<Guid>.Success(userResult.Value.Id);
    }
}
```

### Example 3: Repository with Explicit Mapping

```csharp
public interface IUserRepository
{
    Task<User?> GetByIdAsync(Guid id);
    Task<User?> GetByEmailAsync(Email email);
    Task SaveAsync(User user);
}

public class UserRepository(IAmazonDynamoDB dynamoDb) : IUserRepository
{
    private const string TableName = "app-users";

    public async Task<User?> GetByIdAsync(Guid id)
    {
        var response = await dynamoDb.GetItemAsync(new GetItemRequest
        {
            TableName = TableName,
            Key = new Dictionary<string, AttributeValue>
            {
                ["PK"] = new AttributeValue { S = $"USER#{id}" },
                ["SK"] = new AttributeValue { S = "PROFILE" }
            }
        });

        return response.Item.Count > 0 ? MapFromDynamoDb(response.Item) : null;
    }

    public async Task<User?> GetByEmailAsync(Email email)
    {
        var response = await dynamoDb.QueryAsync(new QueryRequest
        {
            TableName = TableName,
            IndexName = "GSI1",
            KeyConditionExpression = "GSI1PK = :email",
            ExpressionAttributeValues = new Dictionary<string, AttributeValue>
            {
                [":email"] = new AttributeValue { S = $"EMAIL#{email.Value}" }
            }
        });

        return response.Items.FirstOrDefault() is { } item ? MapFromDynamoDb(item) : null;
    }

    public async Task SaveAsync(User user)
    {
        await dynamoDb.PutItemAsync(new PutItemRequest
        {
            TableName = TableName,
            Item = MapToDynamoDb(user)
        });
    }

    // Explicit mapping methods (not reflection)
    private static User MapFromDynamoDb(Dictionary<string, AttributeValue> item)
    {
        var emailResult = Email.Create(item["Email"].S);
        if (emailResult.IsFailure)
            throw new InvalidOperationException("Invalid email in database");

        return new User
        {
            Id = Guid.Parse(item["PK"].S.Replace("USER#", "")),
            Email = emailResult.Value,
            Name = item["Name"].S
        };
    }

    private static Dictionary<string, AttributeValue> MapToDynamoDb(User user)
    {
        return new Dictionary<string, AttributeValue>
        {
            ["PK"] = new AttributeValue { S = $"USER#{user.Id}" },
            ["SK"] = new AttributeValue { S = "PROFILE" },
            ["GSI1PK"] = new AttributeValue { S = $"EMAIL#{user.Email.Value}" },
            ["GSI1SK"] = new AttributeValue { S = $"USER#{user.Id}" },
            ["Email"] = new AttributeValue { S = user.Email.Value },
            ["Name"] = new AttributeValue { S = user.Name }
        };
    }
}
```

### Example 4: Complete Minimal API Endpoint

```csharp
namespace LibraryService.Routes.Users.v1;

public static class UserCreateRoute
{
    public const string ResourceName = "user-create";
    public const int Version = 1;

    public static class Registration
    {
        public static RouteHandlerBuilder Map(RouteGroupBuilder group)
        {
            return group.MapPost("/", Handler.HandleAsync)
                .WithName("CreateUser")
                .WithTags("Users")
                .WithApiVersioning(ResourceName, Version)
                .AcceptsVersioned<Request>(ResourceName, Version)
                .ProducesVersioned<Response>(ResourceName, Version)
                .Produces(StatusCodes.Status400BadRequest)
                .Produces(StatusCodes.Status409Conflict);
        }
    }

    public record Request
    {
        [Required(ErrorMessage = "Email is required")]
        [EmailAddress(ErrorMessage = "Email must be valid")]
        public required string Email { get; init; }

        [Required(ErrorMessage = "Name is required")]
        [MaxLength(100)]
        public required string Name { get; init; }
    }

    public record Response
    {
        public required Guid Id { get; init; }
        public required string Email { get; init; }
        public required string Name { get; init; }
    }

    public static class Handler
    {
        public static async Task<IResult> HandleAsync(
            [FromBody] Request request,
            IUserService userService,
            ILogger<UserCreateRoute> logger)
        {
            // Validation already done by framework (.NET 10+)
            logger.LogInformation("Creating user with email {Email}", request.Email);

            var result = await userService.CreateUserAsync(request.Email, request.Name);

            if (result.IsFailure)
            {
                logger.LogWarning("User creation failed: {Error}", result.Error.Code);

                // Map error codes to HTTP status codes
                var statusCode = result.Error.Code switch
                {
                    "E202" => StatusCodes.Status409Conflict, // User exists
                    _ => StatusCodes.Status400BadRequest
                };

                return Results.Problem(
                    detail: result.Error.Message,
                    statusCode: statusCode,
                    title: result.Error.Code);
            }

            var user = result.Value;
            logger.LogInformation("Created user {UserId}", user);

            return TypedResults.Created(
                $"/users/{user}",
                new Response
                {
                    Id = user,
                    Email = request.Email,
                    Name = request.Name
                });
        }
    }
}
```

---

## 18. Quick Reference Checklist

### ✅ Modern C# Patterns (2025-2026)

- [ ] **File-scoped namespaces** (C# 10) - Reduce nesting
- [ ] **Records for immutable data** - DTOs, value objects, domain events
- [ ] **Required properties** (C# 11) - Compile-time initialization guarantees
- [ ] **Primary constructors** (C# 12) - DI without boilerplate
- [ ] **Collection expressions** (C# 12) - `int[] nums = [1, 2, 3];`
- [ ] **Pattern matching** - Switch expressions, property patterns
- [ ] **Nullable reference types** - Explicit null handling
- [ ] **Value objects** - Wrap primitives (Email, Money, LibraryId)
- [ ] **Result<T> pattern** - Explicit error handling
- [ ] **Minimal API** - Static nested classes, explicit handlers
- [ ] **Source generators** - For 10+ repetitive patterns
- [ ] **DataAnnotations validation** (.NET 10+) - Source-generated
- [ ] **Explicit mapping** - Extension methods, no reflection
- [ ] **Interface-based DI** - Composition over inheritance

### ⚠️ Patterns to Avoid

- [ ] **Controllers** → Use Minimal API instead
- [ ] **Primitive obsession** → Use value objects
- [ ] **Exceptions for control flow** → Use Result<T>
- [ ] **Mutable classes** → Use records (when applicable)
- [ ] **AutoMapper for simple mappings** → Use explicit methods
- [ ] **FluentValidation for .NET 10+** → Use DataAnnotations
- [ ] **Reflection** → Use source generators
- [ ] **Over-abstraction** → YAGNI (IRepository<T> + BaseRepository<T>)
- [ ] **Premature source generators** → Start explicit until 10+ files

---

## 19. Related Documentation

### Within Repository

- **[minimal-api.md](minimal-api.md)** - Complete Minimal API patterns with versioning
- **[domain-modeling.md](domain-modeling.md)** - Value objects, entities, immutability
- **[error-modeling.md](error-modeling.md)** - Result<T> pattern with error codes
- **[testing.md](testing.md)** - Testing modern patterns (xUnit, FluentAssertions)
- **[CODEMAP.md](../../CODEMAP.md)** - Repository structure and conventions

### Philosophy

- **[core-principles.md](../rules/core-principles.md)** - Explicit over implicit, AI-first development
- **[solo-developer.md](../philosophy/solo-developer.md)** - Why boring, predictable systems matter

---

**This document represents modern C# development for 2025-2026.** Focus on compile-time safety, explicit code, and patterns that AI can understand and generate reliably.
