# C# Error Modeling

**Status:** GUIDELINES - Preferred approach for explicit error handling

**Purpose:** Use explicit error types instead of exceptions for control flow.

---

## Principle

- Use **Result pattern** for expected errors (validation, business rules)
- Use **exceptions** for unexpected errors (null reference, out of memory)
- Make errors **explicit in the type system**

---

## The Result Pattern

```csharp
public record Result<T>
{
    public T Value { get; }
    public Error Error { get; }
    public bool IsSuccess => Error is null;
    public bool IsFailure => !IsSuccess;

    private Result(T value, Error error)
    {
        Value = value;
        Error = error;
    }

    public static Result<T> Success(T value) => new(value, null);
    public static Result<T> Failure(Error error) => new(default, error);
}

public record Error(string Code, string Message);

// For structured error codes, use a prefix + numeric code
public static class ErrorCodes
{
    public const string EmailEmpty = "E100";
    public const string EmailInvalid = "E101";
    public const string UserExists = "E200";
    public const string UserNotFound = "E201";
}
```

**Error Code Format:**
- **Lightweight structure:** Prefix + number (e.g., `E100`, `E101`)
- **Purpose:** Makes errors greppable and trackable without being obsessive
- **No complex hierarchy:** Keep it simple (not `VALIDATION.EMAIL.EMPTY.001`)

**✅ Good:**
```csharp
new Error("E100", "Email cannot be empty")
new Error("E101", "Email must contain @")
new Error("E200", "User already exists")
```

**❌ Bad (too verbose):**
```csharp
new Error("VALIDATION.EMAIL.EMPTY", "Email cannot be empty")  // Too nested
new Error("EMAIL_CANNOT_BE_EMPTY", "Email cannot be empty")   // Too verbose
```

**❌ Bad (unstructured):**
```csharp
new Error("EMAIL_EMPTY", "Email cannot be empty")  // Plain string only
```

---

## Error Code Organization

**Keep it lightweight and greppable:**

```csharp
public static class ErrorCodes
{
    // Email validation: E100-E199
    public const string EmailEmpty = "E100";
    public const string EmailInvalid = "E101";
    public const string EmailTooLong = "E102";

    // User operations: E200-E299
    public const string UserExists = "E200";
    public const string UserNotFound = "E201";
    public const string UserInactive = "E202";

    // Order operations: E300-E399
    public const string OrderNotFound = "E300";
    public const string OrderCancelled = "E301";
}
```

**Ranges by domain:**
- `E100-E199` - Email/authentication
- `E200-E299` - User operations
- `E300-E399` - Order operations
- `E400-E499` - Payment operations
- `E500-E599` - Infrastructure errors

**Benefits:**
- ✅ Greppable in logs: `grep "E200" logs.txt`
- ✅ Trackable across services
- ✅ Simple to understand (no complex hierarchy)
- ✅ Easy to extend (just add new ranges)

---

## Usage in Domain

```csharp
public record Email
{
    public string Value { get; }

    private Email(string value) => Value = value;

    public static Result<Email> Create(string email)
    {
        if (string.IsNullOrWhiteSpace(email))
            return Result<Email>.Failure(new Error(ErrorCodes.EmailEmpty, "Email cannot be empty"));

        if (!email.Contains('@'))
            return Result<Email>.Failure(new Error(ErrorCodes.EmailInvalid, "Email must contain @"));

        return Result<Email>.Success(new Email(email.ToLowerInvariant()));
    }
}
```

Callers must handle both cases:

```csharp
var emailResult = Email.Create(input);

if (emailResult.IsFailure)
{
    _logger.LogWarning("Invalid email: {Error}", emailResult.Error.Message);
    return Result<User>.Failure(emailResult.Error);
}

var email = emailResult.Value;
```

---

## Usage in Application Layer

```csharp
public class CreateUserCommandHandler
{
    private readonly IUserRepository _repository;

    public async Task<Result<Guid>> HandleAsync(CreateUserCommand command)
    {
        var emailResult = Email.Create(command.Email);
        if (emailResult.IsFailure)
            return Result<Guid>.Failure(emailResult.Error);

        var existingUser = await _repository.GetByEmailAsync(emailResult.Value);
        if (existingUser is not null)
            return Result<Guid>.Failure(new Error(ErrorCodes.UserExists, "User already exists"));

        var user = User.Create(emailResult.Value, command.Name);
        await _repository.SaveAsync(user);

        return Result<Guid>.Success(user.Id);
    }
}
```

---

## Mapping to HTTP

```csharp
app.MapPost("/users", async (CreateUserCommand cmd, CreateUserCommandHandler handler) =>
{
    var result = await handler.HandleAsync(cmd);
    
    return result.IsSuccess
        ? Results.Created($"/users/{result.Value}", result.Value)
        : Results.BadRequest(new ProblemDetails
        {
            Title = result.Error.Code,
            Detail = result.Error.Message,
            Status = 400
        });
});
```

---

## Error Codes

Use constants for error codes:

```csharp
public static class ErrorCodes
{
    public const string EmailEmpty = "EMAIL_EMPTY";
    public const string EmailInvalid = "EMAIL_INVALID";
    public const string UserExists = "USER_EXISTS";
    public const string UserNotFound = "USER_NOT_FOUND";
}
```

---

## When to Use Exceptions

**Use exceptions for:**
- Programming errors (null reference, index out of range)
- Unrecoverable failures (out of memory, database unreachable)
- Framework integration (ASP.NET expects exceptions for 500 errors)

**Don't use exceptions for:**
- Validation errors (use Result)
- Business rule violations (use Result)
- Expected failures (use Result)

---

## Railway-Oriented Programming

Chain operations with extension methods:

```csharp
public static class ResultExtensions
{
    public static Result<TOut> Map<TIn, TOut>(
        this Result<TIn> result,
        Func<TIn, TOut> mapper)
    {
        return result.IsSuccess
            ? Result<TOut>.Success(mapper(result.Value))
            : Result<TOut>.Failure(result.Error);
    }

    public static Result<TOut> Bind<TIn, TOut>(
        this Result<TIn> result,
        Func<TIn, Result<TOut>> binder)
    {
        return result.IsSuccess
            ? binder(result.Value)
            : Result<TOut>.Failure(result.Error);
    }
}
```

Usage:

```csharp
var result = Email.Create(input)
    .Bind(email => User.Create(email, name))
    .Map(user => user.Id);
```

---

## Related Documentation

- **[domain-modeling.md](domain-modeling.md)** - Value objects that return Result
- **[ARCHITECTURE.md](../../ARCHITECTURE.md)** - Where to use Result
- **[testing.md](testing.md)** - Testing error cases
- **[../guidelines/csharp-core.md](../guidelines/csharp-core.md)** - Core patterns
