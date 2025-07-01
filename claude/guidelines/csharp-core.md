# C# Core Guidelines

**Status:** GUIDELINES - Preferred approaches, deviations allowed with justification

**Purpose:** Standard patterns for C# backend services and APIs.

---

## Minimal API Pattern

Static endpoint classes, one endpoint per file.

```
src/ServiceName/
├── ServiceName.Api/
│   ├── Program.cs
│   ├── Endpoints/Users/
│   │   ├── GetUserEndpoint.cs
│   │   ├── CreateUserEndpoint.cs
│   ├── Models/
│   │   ├── Requests/
│   │   └── Responses/
```

```csharp
public static class GetUserEndpoint
{
    public static void MapGetUser(this IEndpointRouteBuilder app)
    {
        app.MapGet("/users/{id:guid}", HandleAsync)
            .WithName("GetUser")
            .Produces<UserResponse>(200)
            .Produces<ProblemDetails>(404);
    }

    private static async Task<Results<Ok<UserResponse>, NotFound>> HandleAsync(
        Guid id,
        IUserService userService)
    {
        var user = await userService.GetUserAsync(id);
        return user is null
            ? TypedResults.NotFound()
            : TypedResults.Ok(new UserResponse { /* ... */ });
    }
}
```

---

## Records and Immutability

```csharp
public record User
{
    public required Guid Id { get; init; }
    public required string Email { get; init; }
    public required string Name { get; init; }
}

var updated = user with { Name = "New Name" };
```

See [.claude/csharp/domain-modeling.md](../csharp/domain-modeling.md) for details.

---

## Dependency Injection

```csharp
public interface IUserService
{
    Task<User?> GetUserAsync(Guid id);
}

public class UserService : IUserService
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
```

Register in Program.cs:

```csharp
builder.Services.AddScoped<IUserService, UserService>();
```

---

## Validation

```csharp
public class CreateUserRequestValidator : AbstractValidator<CreateUserRequest>
{
    public CreateUserRequestValidator()
    {
        RuleFor(x => x.Email).NotEmpty().EmailAddress();
        RuleFor(x => x.Name).NotEmpty().MaximumLength(100);
    }
}
```

---

## Error Handling

```csharp
if (user is null)
{
    return TypedResults.NotFound(new ProblemDetails
    {
        Title = "User not found",
        Detail = $"User with ID {id} does not exist.",
        Status = 404
    });
}
```

See [.claude/csharp/error-modeling.md](../csharp/error-modeling.md) for Result pattern.

---

## Testing

```csharp
public class UserServiceTests
{
    [Fact]
    public async Task GetUserAsync_WhenExists_ReturnsUser()
    {
        var mockRepo = new Mock<IUserRepository>();
        var expectedUser = new User { Id = Guid.NewGuid() };
        mockRepo.Setup(x => x.GetByIdAsync(It.IsAny<Guid>()))
            .ReturnsAsync(expectedUser);

        var sut = new UserService(mockRepo.Object, Mock.Of<ILogger<UserService>>());
        var result = await sut.GetUserAsync(expectedUser.Id);

        result.Should().NotBeNull();
        result.Should().BeEquivalentTo(expectedUser);
    }
}
```

See [.claude/csharp/testing.md](../csharp/testing.md) for comprehensive strategy.

---

## Related Documentation

### Core C# Topics

- **[.claude/csharp/basics.md](../csharp/basics.md)** - Modern C# patterns (2025-2026)
- **[.claude/csharp/minimal-api.md](../csharp/minimal-api.md)** - Minimal API patterns
- **[.claude/csharp/domain-modeling.md](../csharp/domain-modeling.md)** - Value objects, entities
- **[.claude/csharp/error-modeling.md](../csharp/error-modeling.md)** - Result pattern
- **[.claude/csharp/logging.md](../csharp/logging.md)** - Structured logging
- **[.claude/csharp/testing.md](../csharp/testing.md)** - Testing strategy

### Related Guidelines

- **[.claude/guidelines/dynamodb.md](dynamodb.md)** - DynamoDB and serverless patterns
