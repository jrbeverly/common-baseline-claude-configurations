# Minimal API Pattern

**Principle:** Static endpoint classes with versioned namespaces, nested organization, explicit handlers.

**Status:** GUIDELINE - Preferred pattern for C# APIs

---

## Core Pattern

**One file per endpoint** with static nested classes for organization:

- `Registration` - Route mapping and OpenAPI configuration
- `Examples` - OpenAPI example JSON
- `Request` / `Response` - Record types with DataAnnotations validation (.NET 10+)
- `Handler` - Actual endpoint logic

---

## File Structure

```
src/{ServiceName}/
├── {ServiceName}.Api/
│   ├── Program.cs
│   ├── Routes/
│   │   ├── Versioning/        # API versioning infrastructure
│   │   ├── Loans/
│   │   │   ├── v1/
│   │   │   │   ├── LoanCreateRoute.cs
│   │   │   │   ├── LoanGetRoute.cs
│   │   │   └── v2/
│   │   │       └── LoanCreateRoute.cs
│   │   ├── Users/
│   │   │   └── v1/
│   │   │       ├── UserGetRoute.cs
│   │   │       ├── UserCreateRoute.cs
│   │   │       └── UserUpdateRoute.cs
```

**Pattern:** Versioned namespaces (`Routes.{Resource}.v1`), one file per endpoint.

---

## Complete Example

```csharp
// src/{ServiceName}/{ServiceName}.Api/Routes/Loans/v1/LoanCreateRoute.cs
using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using LibraryService.Routes.Versioning;
using LibraryService.Utilities.Helpers;

namespace LibraryService.Routes.Loans.v1;

public static class LoanCreateRoute
{
    public const string ResourceName = "loan-create";
    public const int Version = 1;
    public static readonly string MediaType = ApiVersionConstants.GetMediaType(ResourceName, Version);

    public static class Registration
    {
        public static RouteHandlerBuilder Map(RouteGroupBuilder group)
        {
            return group.MapPost("/create", Handler.HandleAsync)
                .WithName("CreateLoan")
                .WithTags("Loans")
                .RequireAuthorization()
                .WithOpenApi(operation =>
                {
                    operation.Summary = "Create book loan";
                    operation.Description =
                        "Creates a new book loan for a library patron. The library is specified in the URL path. Requires authentication. Returns loan details including due date.";
                    operation.OperationId = "CreateLoan";

                    if (operation.RequestBody?.Content?.ContainsKey("application/json") == true)
                        operation.RequestBody.Content["application/json"].Example =
                            new OpenApiString(Examples.RequestExample);
                    if (operation.Responses?["200"]?.Content?.ContainsKey("application/json") == true)
                        operation.Responses["200"].Content["application/json"].Example =
                            new OpenApiString(Examples.ResponseExample);

                    return operation;
                })
                .WithApiVersioning(ResourceName, Version)
                .AcceptsVersioned<Request>(ResourceName, Version)
                .ProducesVersioned<Response>(ResourceName, Version)
                .Produces(StatusCodes.Status400BadRequest) // Automatic validation with DataAnnotations (.NET 10+)
                .Produces(StatusCodes.Status401Unauthorized)
                .Produces(StatusCodes.Status500InternalServerError);
        }
    }

    public static class Examples
    {
        public const string RequestExample = """
                                             {
                                               "bookId": "book_ABC123",
                                               "durationDays": 14
                                             }
                                             """;

        public const string ResponseExample = """
                                              {
                                                "loanId": "loan_XYZ789",
                                                "bookId": "book_ABC123",
                                                "dueDate": "2026-01-27T23:59:59Z",
                                                "status": "active"
                                              }
                                              """;
    }

    public record Request : IValidatableObject
    {
        [Required(ErrorMessage = "Book ID is required")]
        [RegularExpression(@"^book_[a-zA-Z0-9]+$", ErrorMessage = "Book ID must be a valid book identifier (e.g., book_ABC123)")]
        public string BookId { get; init; } = string.Empty;

        [Range(1, 90, ErrorMessage = "Duration must be between 1 and 90 days")]
        public int DurationDays { get; init; } = 14;

        public IEnumerable<ValidationResult> Validate(ValidationContext validationContext)
        {
            // Additional custom validation logic can go here if needed
            yield break;
        }
    }

    public record Response
    {
        public string LoanId { get; init; } = string.Empty;
        public string BookId { get; init; } = string.Empty;
        public DateTime DueDate { get; init; }
        public string Status { get; init; } = string.Empty;
    }

    public static class Handler
    {
        public static async Task<IResult> HandleAsync(
            [FromRoute] string libraryId,
            [FromBody] Request request,
            ClaimsPrincipal user,
            ILoanService loanService,
            IConfiguration configuration,
            IAuthorizationService authService)
        {
            var userId = AuthContextHelpers.ExtractUserId(user);
            if (string.IsNullOrEmpty(userId)) return Results.Unauthorized();

            var authResult = await authService.AuthorizeAsync(user, libraryId, "LibraryMemberPolicy");
            if (!authResult.Succeeded) return Results.Forbid();

            try
            {
                var createRequest = new LoanCreateRequest
                {
                    BookId = request.BookId,
                    PatronId = userId,
                    LibraryId = libraryId,
                    DurationDays = request.DurationDays,
                    LoanDate = DateTime.UtcNow
                };

                var loan = await loanService.CreateLoanAsync(createRequest);

                return Results.Ok(new Response
                {
                    LoanId = loan.LoanId,
                    BookId = loan.BookId,
                    DueDate = loan.DueDate,
                    Status = loan.Status
                });
            }
            catch (Exception ex)
            {
                return Results.Problem(
                    ex.Message,
                    statusCode: StatusCodes.Status500InternalServerError,
                    title: "Loan Creation Error"
                );
            }
        }
    }
}
```

---

## Key Elements

### 1. Versioned Namespace

```csharp
namespace LibraryService.Routes.Loans.v1;
```

- Namespace includes version (`v1`, `v2`, etc.)
- Allows multiple versions to coexist
- Clear version evolution path

### 2. Resource Constants

```csharp
public const string ResourceName = "loan-create";
public const int Version = 1;
public static readonly string MediaType = ApiVersionConstants.GetMediaType(ResourceName, Version);
```

- `ResourceName` identifies the API resource
- `Version` explicit version number
- `MediaType` for content negotiation

### 3. Registration with Rich Configuration

```csharp
public static class Registration
{
    public static RouteHandlerBuilder Map(RouteGroupBuilder group)
    {
        return group.MapPost("/create", Handler.HandleAsync)
            .WithName("CreateLoan")
            .WithTags("Loans")
            .RequireAuthorization()
            .WithOpenApi(operation => { /* ... */ })
            .WithApiVersioning(ResourceName, Version)
            .AcceptsVersioned<Request>(ResourceName, Version)
            .WithValidation<Request>()
            .ProducesVersioned<Response>(ResourceName, Version)
            .Produces(StatusCodes.Status400BadRequest)
            .Produces(StatusCodes.Status401Unauthorized)
            .Produces(StatusCodes.Status500InternalServerError);
    }
}
```

**Configuration includes:**
- Route mapping (`MapPost`, `MapGet`, etc.)
- OpenAPI documentation inline
- API versioning integration
- Request validation
- Explicit status codes
- Authorization requirements

### 4. OpenAPI Examples

```csharp
public static class Examples
{
    public const string RequestExample = """
                                         {
                                           "bookId": "book_ABC123",
                                           "durationDays": 14
                                         }
                                         """;

    public const string ResponseExample = """
                                          {
                                            "loanId": "loan_XYZ789",
                                            "bookId": "book_ABC123",
                                            "dueDate": "2026-01-27T23:59:59Z",
                                            "status": "active"
                                          }
                                          """;
}
```

- Raw string literals for JSON examples
- Used in OpenAPI documentation
- Helps API consumers understand format

### 5. Request/Response Records with Validation

```csharp
public record Request : IValidatableObject
{
    [Required(ErrorMessage = "Book ID is required")]
    [RegularExpression(@"^book_[a-zA-Z0-9]+$", ErrorMessage = "Book ID must be a valid book identifier")]
    public string BookId { get; init; } = string.Empty;

    [Range(1, 90, ErrorMessage = "Duration must be between 1 and 90 days")]
    public int DurationDays { get; init; } = 14;

    public IEnumerable<ValidationResult> Validate(ValidationContext validationContext)
    {
        // Additional custom validation logic if needed
        yield break;
    }
}

public record Response
{
    public string LoanId { get; init; } = string.Empty;
    public string BookId { get; init; } = string.Empty;
    public DateTime DueDate { get; init; }
    public string Status { get; init; } = string.Empty;
}
```

- Records for immutability
- DataAnnotations for validation (.NET 10+ automatic validation)
- IValidatableObject for complex cross-property validation
- Source-generator friendly (AOT compatible)
- `init` accessors
- Default values where appropriate
- Nested within endpoint class

### 7. Handler with Explicit Dependencies

```csharp
public static class Handler
{
    public static async Task<IResult> HandleAsync(
        [FromRoute] string libraryId,
        [FromBody] Request request,
        ClaimsPrincipal user,
        ILoanService loanService,
        IConfiguration configuration,
        IAuthorizationService authService)
    {
        // Authorization
        var userId = AuthContextHelpers.ExtractUserId(user);
        if (string.IsNullOrEmpty(userId)) return Results.Unauthorized();

        var authResult = await authService.AuthorizeAsync(user, libraryId, "LibraryMemberPolicy");
        if (!authResult.Succeeded) return Results.Forbid();

        try
        {
            // Business logic
            var createRequest = new LoanCreateRequest { /* ... */ };
            var loan = await loanService.CreateLoanAsync(createRequest);

            return Results.Ok(new Response { LoanId = loan.LoanId, BookId = loan.BookId, DueDate = loan.DueDate, Status = loan.Status });
        }
        catch (Exception ex)
        {
            return Results.Problem(
                ex.Message,
                statusCode: StatusCodes.Status500InternalServerError,
                title: "Loan Creation Error"
            );
        }
    }
}
```

**Handler pattern:**
- Explicit parameter binding (`[FromRoute]`, `[FromBody]`)
- Authorization checks first
- Service dependencies injected directly
- Try/catch for error handling
- Returns `IResult` (typed results preferred)

---

## GET Example

```csharp
namespace LibraryService.Routes.Users.v1;

public static class UserGetRoute
{
    public const string ResourceName = "user";
    public const int Version = 1;
    public static readonly string MediaType = ApiVersionConstants.GetMediaType(ResourceName, Version);

    public static class Registration
    {
        public static RouteHandlerBuilder Map(RouteGroupBuilder group)
        {
            return group.MapGet("/{userId:guid}", Handler.HandleAsync)
                .WithName("GetUser")
                .WithTags("Users")
                .RequireAuthorization()
                .WithOpenApi(operation =>
                {
                    operation.Summary = "Get user by ID";
                    operation.Description = "Retrieves a user by their unique identifier.";
                    operation.OperationId = "GetUser";
                    return operation;
                })
                .WithApiVersioning(ResourceName, Version)
                .ProducesVersioned<Response>(ResourceName, Version)
                .Produces(StatusCodes.Status404NotFound)
                .Produces(StatusCodes.Status401Unauthorized);
        }
    }

    public record Response
    {
        public Guid Id { get; init; }
        public string Email { get; init; } = string.Empty;
        public string Name { get; init; } = string.Empty;
    }

    public static class Handler
    {
        public static async Task<IResult> HandleAsync(
            [FromRoute] Guid userId,
            ClaimsPrincipal user,
            IUserService userService)
        {
            var currentUserId = AuthContextHelpers.ExtractUserId(user);
            if (string.IsNullOrEmpty(currentUserId)) return Results.Unauthorized();

            var userData = await userService.GetUserAsync(userId);
            if (userData == null) return Results.NotFound();

            return Results.Ok(new Response
            {
                Id = userData.Id,
                Email = userData.Email,
                Name = userData.Name
            });
        }
    }
}
```

**GET specifics:**
- No request body (only route parameters)
- No validator needed (simple route constraint)
- Returns 404 for not found

---

## PUT Example

```csharp
namespace LibraryService.Routes.Users.v1;

public static class UserUpdateRoute
{
    public const string ResourceName = "user-update";
    public const int Version = 1;

    public static class Registration
    {
        public static RouteHandlerBuilder Map(RouteGroupBuilder group)
        {
            return group.MapPut("/{userId:guid}", Handler.HandleAsync)
                .WithName("UpdateUser")
                .WithTags("Users")
                .RequireAuthorization()
                .WithApiVersioning(ResourceName, Version)
                .AcceptsVersioned<Request>(ResourceName, Version)
                .WithValidation<Request>()
                .ProducesVersioned<Response>(ResourceName, Version)
                .Produces(StatusCodes.Status404NotFound);
        }
    }

    public record Request
    {
        [Required(ErrorMessage = "Name is required")]
        [MaxLength(100, ErrorMessage = "Name cannot exceed 100 characters")]
        public string Name { get; init; } = string.Empty;

        [Required(ErrorMessage = "Email is required")]
        [EmailAddress(ErrorMessage = "Email must be valid")]
        public string Email { get; init; } = string.Empty;
    }

    public record Response
    {
        public Guid Id { get; init; }
        public string Email { get; init; } = string.Empty;
        public string Name { get; init; } = string.Empty;
    }

    public static class Handler
    {
        public static async Task<IResult> HandleAsync(
            [FromRoute] Guid userId,
            [FromBody] Request request,
            ClaimsPrincipal user,
            IUserService userService)
        {
            var currentUserId = AuthContextHelpers.ExtractUserId(user);
            if (string.IsNullOrEmpty(currentUserId)) return Results.Unauthorized();

            var updated = await userService.UpdateUserAsync(userId, request.Name, request.Email);
            if (updated == null) return Results.NotFound();

            return Results.Ok(new Response
            {
                Id = updated.Id,
                Email = updated.Email,
                Name = updated.Name
            });
        }
    }
}
```

---

## DELETE Example

```csharp
namespace LibraryService.Routes.Users.v1;

public static class UserDeleteRoute
{
    public const string ResourceName = "user-delete";
    public const int Version = 1;

    public static class Registration
    {
        public static RouteHandlerBuilder Map(RouteGroupBuilder group)
        {
            return group.MapDelete("/{userId:guid}", Handler.HandleAsync)
                .WithName("DeleteUser")
                .WithTags("Users")
                .RequireAuthorization()
                .WithApiVersioning(ResourceName, Version)
                .Produces(StatusCodes.Status204NoContent)
                .Produces(StatusCodes.Status404NotFound);
        }
    }

    public static class Handler
    {
        public static async Task<IResult> HandleAsync(
            [FromRoute] Guid userId,
            ClaimsPrincipal user,
            IUserService userService)
        {
            var currentUserId = AuthContextHelpers.ExtractUserId(user);
            if (string.IsNullOrEmpty(currentUserId)) return Results.Unauthorized();

            var deleted = await userService.DeleteUserAsync(userId);
            if (!deleted) return Results.NotFound();

            return Results.NoContent();
        }
    }
}
```

**DELETE specifics:**
- No request body
- No response body (204 No Content)
- Returns 404 if resource doesn't exist

---

## Wiring Endpoints in Program.cs

```csharp
// src/{ServiceName}/{ServiceName}.Api/Program.cs
var builder = WebApplication.CreateBuilder(args);

// Services
builder.Services.AddScoped<IUserService, UserService>();
builder.Services.AddScoped<ILoanService, LoanService>();

// Validation
// Enable built-in validation for .NET 10+
builder.Services.AddValidation();

// OpenAPI
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();

var app = builder.Build();

// Map versioned route groups
var v1 = app.MapGroup("/api/v1");

// Loan routes
var loanGroup = v1.MapGroup("/loans");
LoanCreateRoute.Registration.Map(loanGroup);

// User routes
var userGroup = v1.MapGroup("/users");
UserGetRoute.Registration.Map(userGroup);
UserUpdateRoute.Registration.Map(userGroup);
UserDeleteRoute.Registration.Map(userGroup);

app.Run();
```

---

## Why This Pattern?

**Benefits:**
- ✅ **Versioned:** Clear version evolution with namespace versioning
- ✅ **Self-Contained:** Each endpoint file contains everything related to that endpoint
- ✅ **OpenAPI-First:** Documentation inline with route configuration
- ✅ **Validated:** DataAnnotations with automatic validation (.NET 10+), source-generator friendly
- ✅ **Testable:** Static methods are easy to test, clear dependencies
- ✅ **AI-Friendly:** Predictable structure, easy to generate
- ✅ **No Magic:** Explicit configuration, no hidden behavior
- ✅ **Discoverable:** Everything for an endpoint in one place
- ✅ **AOT Compatible:** Source-generator friendly validation, no reflection

**vs Traditional Controllers:**
- No base classes
- No attribute routing (explicit `MapGet`/`MapPost`)
- No model binding magic (explicit parameters)
- No action filters (middleware or explicit logic)
- OpenAPI configuration colocated with route

---

## Anti-Patterns

**❌ Don't use controllers:**
```csharp
// BAD: Controller with action methods
[ApiController]
[Route("api/[controller]")]
public class UsersController : ControllerBase
{
    [HttpGet("{id}")]
    public async Task<IActionResult> Get(Guid id) { /* ... */ }
}
```

**❌ Don't put multiple endpoints in one file:**
```csharp
// BAD: Multiple endpoints in UserRoutes.cs
public static class UserRoutes
{
    public static void MapUserRoutes(this IEndpointRouteBuilder app)
    {
        app.MapGet("/users/{id}", GetUser);
        app.MapPost("/users", CreateUser);  // Too many in one file
        app.MapPut("/users/{id}", UpdateUser);
    }
}
```

**❌ Don't use lambda handlers:**
```csharp
// BAD: Logic inline in Program.cs
app.MapGet("/users/{id:guid}", async (Guid id, IUserService svc) =>
{
    var user = await svc.GetUserAsync(id);
    return user is null ? Results.NotFound() : Results.Ok(user);
});
```

**❌ Don't skip versioning:**
```csharp
// BAD: No versioning in namespace or route
namespace LibraryService.Routes.Users;  // Missing version
```

---

## Validation Setup (.NET 10+)

### Project Configuration

Add to your `.csproj` file:

```xml
<PropertyGroup>
  <InterceptorsNamespaces>$(InterceptorsNamespaces);Microsoft.AspNetCore.Http.Validation.Generated</InterceptorsNamespaces>
</PropertyGroup>
```

### Program.cs Setup

```csharp
var builder = WebApplication.CreateBuilder(args);

// Enable built-in validation
builder.Services.AddValidation();

var app = builder.Build();
```

### Validation Behavior

- **Automatic**: Validation runs automatically for all request models with DataAnnotations
- **Response**: Returns `400 Bad Request` with `ProblemDetails` containing validation errors
- **Opt-out**: Use `.DisableValidation()` on specific endpoints if needed
- **Source Generated**: Validation logic is generated at compile-time (AOT compatible)

### Legacy (.NET 8)

For .NET 8 projects, use FluentValidation:

```csharp
builder.Services.AddValidatorsFromAssemblyContaining<Program>();
```

And add `.WithValidation<Request>()` to route registration.

---

## Policy Services Pattern

**Purpose:** Centralized authorization and validation logic that can be reused across multiple endpoints.

**Design Principle:** Policies validate and authorize, they don't mutate state. All validation failures throw domain exceptions.

---

### Policy Service Structure

**Pattern:** One policy service per domain entity

**Interface Location:** `src/{ServiceName}/Policies/I{Entity}Policy.cs`

**Implementation Location:** `src/{ServiceName}/Policies/{Entity}Policy.cs`

```csharp
// src/LibraryService/Policies/IBookPolicy.cs
public interface IBookPolicy
{
    Task<Book> RequireBookExistsAsync(string libraryId, string bookId);
    void RequireBookBelongsToLibrary(Book book, string libraryId);
    void RequireBookIsAvailable(Book book);
}

// src/LibraryService/Policies/BookPolicy.cs
public class BookPolicy : IBookPolicy
{
    private readonly BookRepository _bookRepository;

    public BookPolicy(BookRepository bookRepository)
    {
        _bookRepository = bookRepository;
    }

    public async Task<Book> RequireBookExistsAsync(string libraryId, string bookId)
    {
        var book = await _bookRepository.GetLibraryBookAsync(libraryId, bookId);
        if (book == null)
            throw new NotFoundException("Book", bookId);
        return book;
    }

    public void RequireBookBelongsToLibrary(Book book, string libraryId)
    {
        if (book.LibraryId != libraryId)
            throw new ForbiddenException("Book does not belong to this library");
    }

    public void RequireBookIsAvailable(Book book)
    {
        if (book.Status != "available")
            throw new BadRequestException($"Book '{book.BookId}' is not available for loan");
    }
}
```

---

### Method Naming Convention

**Pattern:** All policy methods start with "Require" (verb-first imperative)

**Return Types:**
- `Task<TEntity>` - Fetch entity and validate it exists
- `void` - Synchronous validation check (no data access)
- `Task` - Async validation check without return value

**Parameter Patterns:**

| Operation | Method Signature | Example |
|-----------|------------------|---------|
| **Entity retrieval** | `Task<T> Require{Entity}ExistsAsync(string libraryId, string entityId)` | `RequireBookExistsAsync(libraryId, bookId)` |
| **Ownership validation** | `void Require{Entity}BelongsToLibrary(T entity, string libraryId)` | `RequireBookBelongsToLibrary(book, libraryId)` |
| **State validation** | `void Require{Entity}{State}(T entity)` | `RequireInvitationIsPending(invitation)` |
| **User permission** | `void RequireUser{Permission}(TContext context, params string[] roles)` | `RequireUserHasRole(membership, "Admin", "Owner")` |
| **Complex validation** | `Task Require{Condition}Async(params...)` | `RequireUserCanLeaveLibraryAsync(userId, libraryId)` |

---

### Common Policy Types

**IAuthContextPolicy** - Extract and validate authentication claims

```csharp
public interface IAuthContextPolicy
{
    string RequireUserId(ClaimsPrincipal user);
    (string UserId, string Email) RequireUserIdAndEmail(ClaimsPrincipal user);
}

public class AuthContextPolicy : IAuthContextPolicy
{
    public string RequireUserId(ClaimsPrincipal user)
    {
        var userId = user.FindFirst(ClaimTypes.NameIdentifier)?.Value;
        if (string.IsNullOrEmpty(userId))
            throw new UnauthorizedException("User ID not found in token");
        return userId;
    }

    public (string UserId, string Email) RequireUserIdAndEmail(ClaimsPrincipal user)
    {
        var userId = RequireUserId(user);
        var email = user.FindFirst(ClaimTypes.Email)?.Value;
        if (string.IsNullOrEmpty(email))
            throw new UnauthorizedException("Email not found in token");
        return (userId, email);
    }
}
```

**ILibraryPolicy** - Library access and membership validation

```csharp
public interface ILibraryPolicy
{
    Task<Library> RequireLibraryExistsAsync(string libraryId);
    Task<Membership> RequireActiveMembershipAsync(string userId, string libraryId);
    void RequireUserHasRole(Membership membership, params string[] allowedRoles);
    void RequireUserIsOwnerOrAdmin(Membership membership);
}

public class LibraryPolicy : ILibraryPolicy
{
    private readonly LibraryRepository _libraryRepository;
    private readonly MembershipRepository _membershipRepository;

    public LibraryPolicy(
        LibraryRepository libraryRepository,
        MembershipRepository membershipRepository)
    {
        _libraryRepository = libraryRepository;
        _membershipRepository = membershipRepository;
    }

    public async Task<Library> RequireLibraryExistsAsync(string libraryId)
    {
        var library = await _libraryRepository.GetAsync(libraryId);
        if (library == null)
            throw new NotFoundException("Library", libraryId);
        return library;
    }

    public async Task<Membership> RequireActiveMembershipAsync(string userId, string libraryId)
    {
        var membership = await _membershipRepository.GetByUserAndLibraryAsync(userId, libraryId);
        if (membership == null)
            throw new ForbiddenException("User is not a member of this library");
        if (membership.Status != MembershipStatus.Active)
            throw new ForbiddenException("User membership is not active");
        return membership;
    }

    public void RequireUserHasRole(Membership membership, params string[] allowedRoles)
    {
        if (!allowedRoles.Contains(membership.Role))
            throw new ForbiddenException($"User must have one of these roles: {string.Join(", ", allowedRoles)}");
    }

    public void RequireUserIsOwnerOrAdmin(Membership membership)
    {
        RequireUserHasRole(membership, "Owner", "Admin");
    }
}
```

**Entity-Specific Policies** - Domain entity validation

```csharp
public interface ILoanPolicy
{
    Task<Loan> RequireLoanExistsAsync(string libraryId, string loanId);
    void RequireLoanBelongsToLibrary(Loan loan, string libraryId);
}

public interface IInvitationPolicy
{
    Task<LibraryInvitation> RequireInvitationByTokenAsync(string tokenHash);
    void RequireInvitationIsPending(LibraryInvitation invitation);
    void RequireInvitationNotExpired(LibraryInvitation invitation);
    Task RequireUserNotAlreadyMemberAsync(string userId, string libraryId);
}
```

---

### Domain Exceptions

**Base Class:** `DomainException` (abstract)

```csharp
public abstract class DomainException : Exception
{
    public int StatusCode { get; }
    public string Title { get; }

    protected DomainException(int statusCode, string title, string message)
        : base(message)
    {
        StatusCode = statusCode;
        Title = title;
    }
}
```

**Concrete Exception Types:**

```csharp
// 404 Not Found
public class NotFoundException : DomainException
{
    public NotFoundException(string entityType, string id)
        : base(404, "Not Found", $"{entityType} with ID '{id}' was not found")
    {
    }

    public NotFoundException(string message)
        : base(404, "Not Found", message)
    {
    }
}

// 403 Forbidden
public class ForbiddenException : DomainException
{
    public ForbiddenException(string message)
        : base(403, "Forbidden", message)
    {
    }
}

// 400 Bad Request
public class BadRequestException : DomainException
{
    public BadRequestException(string message)
        : base(400, "Bad Request", message)
    {
    }
}

// 401 Unauthorized
public class UnauthorizedException : DomainException
{
    public UnauthorizedException(string message)
        : base(401, "Unauthorized", message)
    {
    }
}
```

**Exception Middleware:** `DomainExceptionMiddleware` catches all `DomainException` types and converts to RFC 7807 Problem Details

```csharp
public class DomainExceptionMiddleware
{
    public async Task InvokeAsync(HttpContext context, RequestDelegate next)
    {
        try
        {
            await next(context);
        }
        catch (DomainException ex)
        {
            context.Response.StatusCode = ex.StatusCode;
            await context.Response.WriteAsJsonAsync(new ProblemDetails
            {
                Status = ex.StatusCode,
                Title = ex.Title,
                Detail = ex.Message
            });
        }
    }
}
```

---

### Usage in Endpoints

**Injection Pattern:** Inject policy services alongside repositories

```csharp
public static class Handler
{
    public static async Task<IResult> HandleAsync(
        [FromRoute] string libraryId,
        [FromRoute] string bookId,
        HttpContext httpContext,
        // Policy services
        IAuthContextPolicy authPolicy,
        ILibraryPolicy libraryPolicy,
        IBookPolicy bookPolicy,
        // Repositories for business logic
        BookRepository bookRepository)
    {
        // Authorization checks (in order)
        var userId = authPolicy.RequireUserId(httpContext.User);
        await libraryPolicy.RequireActiveMembershipAsync(userId, libraryId);
        var book = await bookPolicy.RequireBookExistsAsync(libraryId, bookId);
        bookPolicy.RequireBookBelongsToLibrary(book, libraryId);

        // Business logic
        book.Status = "withdrawn";
        await bookRepository.UpdateAsync(book);

        return Results.Ok(new Response { BookId = book.BookId });
    }
}
```

**Call Order Pattern (Authorization Hierarchy):**

1. **Extract Auth Context** - `authPolicy.RequireUserId(httpContext.User)`
2. **Verify Library Membership** - `libraryPolicy.RequireActiveMembershipAsync(userId, libraryId)`
3. **Verify Entity Exists** - `xxxPolicy.RequireEntityExistsAsync(libraryId, entityId)`
4. **Verify Ownership** - `xxxPolicy.RequireEntityBelongsToLibrary(entity, libraryId)`
5. **Verify State/Constraints** - `xxxPolicy.RequireEntityInValidState(entity)`
6. **Execute Business Logic** - Mutate state, call repositories

**Why This Order:**
- Fail fast on cheapest checks first (auth context extraction)
- Verify user has access to library before checking entity existence (security)
- Validate entity exists before checking ownership (performance)
- All authorization before business logic (separation of concerns)

---

### Registration in DI Container

**Extension Method Pattern:**

```csharp
// src/LibraryService/Policies/PolicyServiceExtensions.cs
public static class PolicyServiceExtensions
{
    public static IServiceCollection AddPolicies(this IServiceCollection services)
    {
        services.AddSingleton<IAuthContextPolicy, AuthContextPolicy>();
        services.AddSingleton<ILibraryPolicy, LibraryPolicy>();
        services.AddSingleton<IBookPolicy, BookPolicy>();
        services.AddSingleton<ILoanPolicy, LoanPolicy>();
        services.AddSingleton<IInvitationPolicy, InvitationPolicy>();

        return services;
    }
}
```

**Registration in Program.cs:**

```csharp
builder.Services.AddPolicies();
```

**Lifecycle:** All policies are registered as **Singleton**
- Policies are stateless and only depend on repositories
- Thread-safe because they don't maintain state between calls
- Singleton is safe and performant for stateless services

---

### Complete Example

**Full endpoint with policy service usage:**

```csharp
// src/LibraryService/Routes/Books/v1/BookWithdrawRoute.cs
public static class BookWithdrawRoute
{
    public const string ResourceName = "book-withdraw";
    public const int Version = 1;

    public static class Registration
    {
        public static RouteHandlerBuilder Map(RouteGroupBuilder group)
        {
            return group.MapPost("/{libraryId}/books/{bookId}/withdraw", Handler.HandleAsync)
                .WithName("WithdrawBook")
                .WithTags("Books")
                .RequireAuthorization()
                .WithOpenApi(operation =>
                {
                    operation.Summary = "Withdraw a book from circulation";
                    operation.Description = "Withdraws a book from library circulation. Requires admin or owner role.";
                    return operation;
                })
                .ProducesVersioned<Response>(ResourceName, Version)
                .Produces(StatusCodes.Status400BadRequest)
                .Produces(StatusCodes.Status401Unauthorized)
                .Produces(StatusCodes.Status403Forbidden)
                .Produces(StatusCodes.Status404NotFound);
        }
    }

    public record Response(string BookId, string Status);

    public static class Handler
    {
        public static async Task<IResult> HandleAsync(
            [FromRoute] string libraryId,
            [FromRoute] string bookId,
            HttpContext httpContext,
            IAuthContextPolicy authPolicy,
            ILibraryPolicy libraryPolicy,
            IBookPolicy bookPolicy,
            BookRepository bookRepository)
        {
            // Step 1: Extract user ID from claims
            var userId = authPolicy.RequireUserId(httpContext.User);

            // Step 2: Verify user is active member of library
            var membership = await libraryPolicy.RequireActiveMembershipAsync(userId, libraryId);

            // Step 3: Verify user has permission (Owner or Admin only)
            libraryPolicy.RequireUserIsOwnerOrAdmin(membership);

            // Step 4: Verify book exists
            var book = await bookPolicy.RequireBookExistsAsync(libraryId, bookId);

            // Step 5: Verify book belongs to this library (defense in depth)
            bookPolicy.RequireBookBelongsToLibrary(book, libraryId);

            // Step 6: Business logic - withdraw the book
            if (book.Status == "withdrawn")
                throw new BadRequestException("Book is already withdrawn");

            book.Status = "withdrawn";
            book.WithdrawnAt = DateTime.UtcNow;
            book.WithdrawnBy = userId;
            await bookRepository.UpdateAsync(book);

            // Step 7: Return response
            return Results.Ok(new Response(book.BookId, book.Status));
        }
    }
}
```

**No Error Handling in Handler:**
- Policies throw domain exceptions (`NotFoundException`, `ForbiddenException`, etc.)
- Global middleware (`DomainExceptionMiddleware`) catches and converts to HTTP responses
- Handlers don't need try-catch blocks
- Automatic conversion to RFC 7807 Problem Details

---

### Testing Pattern

**Mock Policy Services:**

```csharp
public class BookWithdrawTests
{
    [Fact]
    public async Task HandleAsync_ValidRequest_WithdrawsBook()
    {
        // Arrange
        var mockAuthPolicy = new Mock<IAuthContextPolicy>();
        mockAuthPolicy.Setup(p => p.RequireUserId(It.IsAny<ClaimsPrincipal>()))
                     .Returns("user-123");

        var mockLibraryPolicy = new Mock<ILibraryPolicy>();
        mockLibraryPolicy.Setup(p => p.RequireActiveMembershipAsync("user-123", "lib-123"))
                    .ReturnsAsync(new Membership { Role = "Owner" });

        var mockBookPolicy = new Mock<IBookPolicy>();
        mockBookPolicy.Setup(p => p.RequireBookExistsAsync("lib-123", "book-123"))
                        .ReturnsAsync(new Book { BookId = "book-123", Status = "available" });

        var mockRepo = new Mock<BookRepository>();

        // Act
        var result = await Handler.HandleAsync(
            "lib-123",
            "book-123",
            CreateHttpContext(),
            mockAuthPolicy.Object,
            mockLibraryPolicy.Object,
            mockBookPolicy.Object,
            mockRepo.Object);

        // Assert
        mockRepo.Verify(r => r.UpdateAsync(It.Is<Book>(b => b.Status == "withdrawn")), Times.Once);
    }

    [Fact]
    public async Task HandleAsync_BookNotFound_ThrowsNotFoundException()
    {
        // Arrange
        var mockBookPolicy = new Mock<IBookPolicy>();
        mockBookPolicy.Setup(p => p.RequireBookExistsAsync(It.IsAny<string>(), It.IsAny<string>()))
                        .ThrowsAsync(new NotFoundException("Book", "book-999"));

        // Act & Assert
        var exception = await Assert.ThrowsAsync<NotFoundException>(
            () => Handler.HandleAsync(..., mockBookPolicy.Object, ...));

        Assert.Equal(404, exception.StatusCode);
        Assert.Contains("book-999", exception.Message);
    }
}
```

---

### When to Create Policy Services

**Create a policy service when:**
- ✅ Authorization logic is reused across multiple endpoints
- ✅ Validation logic is complex (multiple conditions)
- ✅ You need to fetch data to validate (repository access)
- ✅ Error messages should be consistent across endpoints

**Don't create a policy service when:**
- ❌ Validation is endpoint-specific (only used once)
- ❌ Simple null check or basic validation (use inline check)
- ❌ No data access required (use `[Authorize]` attribute instead)

**Example - When NOT to use policy:**

```csharp
// ❌ BAD: Overkill for simple validation
public interface IEmailPolicy
{
    void RequireEmailNotEmpty(string email);
}

// ✅ GOOD: Inline validation for simple case
public static async Task<IResult> HandleAsync(
    [FromBody] Request request)
{
    if (string.IsNullOrEmpty(request.Email))
        throw new BadRequestException("Email is required");

    // Business logic...
}
```

---

### Best Practices

**DO:**
- ✅ Use consistent "Require" verb prefix for all methods
- ✅ Return validated entities from `RequireXxxExistsAsync` methods
- ✅ Throw specific domain exceptions (`NotFoundException`, `ForbiddenException`)
- ✅ Keep policies stateless (no instance fields except injected dependencies)
- ✅ Follow authorization hierarchy (auth context → library membership → entity existence → ownership)
- ✅ Register as Singleton (policies should be stateless)
- ✅ Include entity type and ID in error messages

**DON'T:**
- ❌ Don't mutate state in policies (no business logic, only validation)
- ❌ Don't return `bool` (throw exceptions instead, fail-fast pattern)
- ❌ Don't catch exceptions in policies (let them bubble up to middleware)
- ❌ Don't inject services beyond repositories (keep policies simple)
- ❌ Don't mix authorization and business logic in the same method
- ❌ Don't use generic exception messages (be specific about what failed)

---

### Benefits

**Code Reusability:**
- Authorization logic defined once, used everywhere
- No duplicate permission checks across endpoints
- Easy to update authorization rules globally

**Readability:**
- Endpoint code reads like business rules
- Clear separation between authorization and business logic
- Self-documenting method names (`RequireUserIsOwnerOrAdmin`)

**Testability:**
- Easy to unit test policies in isolation
- Easy to mock policies in endpoint tests
- Explicit dependencies via constructor injection

**Consistency:**
- All endpoints apply same validation logic
- Consistent error messages for same failure scenarios
- Centralized exception handling via middleware

**Maintainability:**
- Change authorization in one place
- Add new validation rules without touching endpoints
- Type-safe refactoring (compiler catches breaking changes)

---

## Related Documentation

- **[basics.md](basics.md)** - Records, dependency injection, validation
- **[testing.md](testing.md)** - How to test endpoints
- **[CODEMAP.md](../../CODEMAP.md)** - Repository-specific API conventions
