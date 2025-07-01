# C# Logging & Observability

**Status:** GUIDELINES - Preferred patterns for serverless logging

**Purpose:** Structured logging, correlation IDs, CloudWatch-friendly patterns.

---

## Principle

- **Structured** (queryable in CloudWatch)
- **Correlated** (track across services)
- **Leveled appropriately**
- **Serverless-friendly** (stdout → CloudWatch)

---

## Structured Logging

```csharp
// ✅ GOOD: Structured
_logger.LogInformation("Creating user with email {Email}", email);

// ❌ BAD: String interpolation
_logger.LogInformation($"Creating user with email {email}");
```

CloudWatch query:

```
fields @timestamp, Email
| filter @message like /Creating user/
| stats count() by Email
```

---

## Log Levels

| Level | When to Use |
|-------|-------------|
| **Trace** | Very detailed, high volume |
| **Debug** | Diagnostic info |
| **Information** | Normal flow |
| **Warning** | Recoverable errors |
| **Error** | Failures requiring attention |
| **Critical** | System failures |

```csharp
_logger.LogInformation("Getting user {UserId}", id);

try
{
    var user = await _repository.GetByIdAsync(id);
    if (user is null)
    {
        _logger.LogWarning("User {UserId} not found", id);
        return null;
    }
    return user;
}
catch (Exception ex)
{
    _logger.LogError(ex, "Failed to get user {UserId}", id);
    throw;
}
```

---

## Correlation IDs

```csharp
app.Use(async (context, next) =>
{
    var correlationId = context.Request.Headers["X-Correlation-ID"].FirstOrDefault()
        ?? Guid.NewGuid().ToString();
    
    context.Response.Headers.Add("X-Correlation-ID", correlationId);
    
    using (_logger.BeginScope(new Dictionary<string, object>
    {
        ["CorrelationId"] = correlationId
    }))
    {
        await next();
    }
});
```

Passing to external services:

```csharp
var correlationId = _httpContext.Response.Headers["X-Correlation-ID"].First();
request.Headers.Add("X-Correlation-ID", correlationId);
```

---

## JSON Console Logging

```csharp
builder.Services.AddLogging(logging =>
{
    logging.ClearProviders();
    logging.AddJsonConsole(options =>
    {
        options.IncludeScopes = true;
        options.TimestampFormat = "yyyy-MM-dd HH:mm:ss ";
    });
});
```

Output:

```json
{
  "LogLevel": "Information",
  "Message": "Creating user",
  "Email": "test@example.com",
  "Scopes": [{"CorrelationId": "abc-123"}]
}
```

---

## Sensitive Data

```csharp
// ❌ BAD
_logger.LogInformation("Login with password {Password}", password);

// ✅ GOOD
_logger.LogInformation("Login attempt for {Email}", email);
```

Masking:

```csharp
public static string MaskEmail(string email)
{
    var parts = email.Split('@');
    var masked = parts[0].Length > 2
        ? $"{parts[0][0]}***{parts[0][^1]}"
        : "***";
    return $"{masked}@{parts[1]}";
}
```

---

## Performance

```csharp
// ❌ BAD: Always serializes
_logger.LogDebug("Result: " + JsonSerializer.Serialize(result));

// ✅ GOOD: Only if Debug enabled
if (_logger.IsEnabled(LogLevel.Debug))
{
    _logger.LogDebug("Result: {Result}", JsonSerializer.Serialize(result));
}
```

---

## Lambda Logging

```csharp
[LambdaFunction]
public async Task<string> Handler(string input, ILambdaContext context)
{
    _logger.LogInformation("Processing {RequestId}", context.RequestId);
    return "Success";
}
```

Context includes: RequestId, FunctionName, FunctionVersion, MemoryLimitInMB.

---

## Related Documentation

- **[basics.md](basics.md)** - Modern C# patterns and dependency injection
- **[testing.md](testing.md)** - Mocking ILogger
- **[../guidelines/dynamodb.md](../guidelines/dynamodb.md)** - Serverless and DynamoDB patterns
