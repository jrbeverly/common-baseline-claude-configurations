# C# Domain Modeling

**Status:** GUIDELINES - Preferred patterns for domain logic

**Purpose:** Build rich, type-safe domain models using value objects, immutability, and explicit equality.

---

## Value Objects Over Primitives

Wrap primitives to enforce invariants and convey meaning.

```csharp
// ❌ BAD: What constraints does email have?
public void CreateUser(string email) { }

// ✅ GOOD: Email enforces constraints
public void CreateUser(Email email) { }
```

### Example Value Object

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
            return Result<Email>.Failure(new Error("EMAIL_EMPTY", "Email cannot be empty"));

        if (!email.Contains('@'))
            return Result<Email>.Failure(new Error("EMAIL_INVALID", "Email must contain @"));

        return Result<Email>.Success(new Email(email.ToLowerInvariant()));
    }

    public override string ToString() => Value;
}
```

**Benefits:**
- Type safety
- Validation in one place
- Explicit intent
- Value equality (record)

---

## Immutability

Prefer immutable records.

```csharp
// ✅ GOOD: Immutable
public record Email(string Value);
public record UserCreatedEvent(Guid UserId, Email Email, DateTime CreatedAt);

// ❌ BAD: Mutable
public class Email
{
    public string Value { get; set; }
}
```

### Updating Records

```csharp
var user = new User { Id = Guid.NewGuid(), Name = "Alice" };

// Use 'with' expression
var updated = user with { Name = "Alice Smith" };
```

**Benefits:**
- Thread safety
- Easier reasoning
- Fewer bugs

---

## Equality by Value

Records provide value equality automatically.

```csharp
var email1 = Email.Create("test@example.com").Value;
var email2 = Email.Create("test@example.com").Value;

Assert.True(email1 == email2);  // Value equality
```

Classes use reference equality by default. **Prefer records for value semantics.**

---

## Entities vs. Value Objects

**Entity:** Has identity.

```csharp
public class User
{
    public Guid Id { get; private set; }  // Identity
    public Email Email { get; private set; }
}
```

**Value Object:** No identity.

```csharp
public record Email(string Value);
public record Money(decimal Amount, string Currency);
```

**Rule:** Entity if you track it over time, Value Object if it's just a value.

---

## Rich Domain Models

Keep business logic in the domain.

```csharp
public class Loan
{
    public Guid Id { get; private set; }
    public List<LoanItem> Items { get; private set; } = new();
    public LoanStatus Status { get; private set; } = LoanStatus.Draft;

    public void AddItem(Book book, int quantity)
    {
        if (Status != LoanStatus.Draft)
            throw new InvalidOperationException("Cannot modify finalized loan");

        Items.Add(new LoanItem(book, quantity));
    }

    public void Finalize()
    {
        if (!Items.Any())
            throw new InvalidOperationException("Cannot finalize empty loan");

        Status = LoanStatus.Finalized;
    }
}
```

---

## Private Setters

Enforce invariants with private setters.

```csharp
public class User
{
    public Guid Id { get; private set; }
    public Email Email { get; private set; }

    public static User Create(Email email, string name)
    {
        return new User { Id = Guid.NewGuid(), Email = email };
    }

    public void ChangeEmail(Email newEmail)
    {
        if (newEmail == Email)
            throw new InvalidOperationException("Email is already set");

        Email = newEmail;
    }
}
```

---

## Typed IDs (TypedId Pattern)

**Standard:** Use `TypedId` sealed records to prevent ID confusion and provide compile-time type safety.

**Purpose:** Distinguish between different entity identifiers (UserId vs LibraryId vs BookId) at compile time.

---

### Base Pattern

**Location:** `src/LibraryService/Abstractions/TypedId.cs`

```csharp
[JsonConverter(typeof(TypedIdJsonConverterFactory))]
public abstract record TypedId(string Value)
{
    public override string ToString() => Value;

    public static implicit operator string(TypedId id) => id.Value;
}
```

**Key Features:**
- Abstract record wrapping a string value
- Implicit string conversion for seamless integration
- JSON serialization via `TypedIdJsonConverterFactory`
- Value-based equality (automatic from record type)

---

### Concrete TypedId Implementations

**Pattern:** Sealed record with three static factory methods

```csharp
// src/LibraryService/Abstractions/UserId.cs
public sealed record UserId(string Value) : TypedId(Value)
{
    public static UserId Empty => new(string.Empty);

    public static UserId New(IIdGenerator generator)
    {
        return new UserId(generator.NewId());
    }

    public static UserId From(string value)
    {
        return new UserId(value);
    }
}
```

**Available TypedIds:**
- `UserId` - User identifiers
- `LibraryId` - Library identifiers
- `BookId` - Book identifiers
- `LoanId` - Loan identifiers
- `LoanItemId` - Loan item identifiers (supports prefix: `li_`)
- `SessionId` - Session identifiers
- `InvitationId` - Invitation identifiers
- `TokenId` - Token identifiers

---

### Factory Methods Pattern

**Three factory methods for all TypedIds:**

```csharp
// 1. Empty - Sentinel value for empty/null state
var emptyId = UserId.Empty;

// 2. New - Create new ID with generated ULID
var newId = UserId.New(idGenerator);

// 3. From - Parse existing ID from string
var existingId = UserId.From("01HXYZ123ABC");
```

**Special Case - LoanItemId with Prefix:**

```csharp
public sealed record LoanItemId(string Value) : TypedId(Value)
{
    public static LoanItemId New(IIdGenerator generator)
    {
        return new LoanItemId(generator.NewId("li_"));  // Prefixed ULID
    }

    public static LoanItemId From(string value) => new(value);
}

// Usage
var itemId = LoanItemId.New(generator);  // "li_01HXYZ123ABC"
```

---

### JSON Serialization

**Automatic via `TypedIdJsonConverter<T>`:**

```csharp
// Serialization
var userId = UserId.New(generator);
var json = JsonSerializer.Serialize(new { userId });
// Output: {"userId": "01HXYZ123ABC"}

// Deserialization
var deserialized = JsonSerializer.Deserialize<UserId>("\"01HXYZ123ABC\"");
// Result: UserId("01HXYZ123ABC")
```

**Converter Implementation:**

```csharp
// src/LibraryService/Abstractions/TypedIdJsonConverter.cs
public sealed class TypedIdJsonConverter<T> : JsonConverter<T> where T : TypedId
{
    public override T? Read(ref Utf8JsonReader reader, Type typeToConvert, JsonSerializerOptions options)
    {
        var value = reader.GetString();
        if (value is null) return null;

        var constructor = typeToConvert.GetConstructor(new[] { typeof(string) });
        return (T?)constructor?.Invoke(new object[] { value });
    }

    public override void Write(Utf8JsonWriter writer, T value, JsonSerializerOptions options)
    {
        writer.WriteStringValue(value.Value);
    }
}
```

**Factory Pattern:**

```csharp
// src/LibraryService/Abstractions/TypedIdJsonConverterFactory.cs
public sealed class TypedIdJsonConverterFactory : JsonConverterFactory
{
    public override bool CanConvert(Type typeToConvert)
    {
        return typeToConvert.IsSubclassOf(typeof(TypedId)) || typeToConvert == typeof(TypedId);
    }

    public override JsonConverter CreateConverter(Type typeToConvert, JsonSerializerOptions options)
    {
        return (JsonConverter)Activator.CreateInstance(
            typeof(TypedIdJsonConverter<>).MakeGenericType(typeToConvert))!;
    }
}
```

---

### Usage in Domain Models

**Pattern:** Domain models store IDs as `string` properties

```csharp
// src/LibraryService/Models/User.cs
public class User
{
    public string UserId { get; set; } = string.Empty;
    public string Email { get; set; } = string.Empty;
    public string DisplayName { get; set; } = string.Empty;
}

// src/LibraryService/Models/Library.cs
public class Library
{
    public string LibraryId { get; set; } = string.Empty;
    public string Name { get; set; } = string.Empty;
    public string CreatedByUserId { get; set; } = string.Empty;
}

// src/LibraryService/Models/Book.cs
public class Book
{
    public string BookId { get; set; } = string.Empty;
    public string LibraryId { get; set; } = string.Empty;
    public string Title { get; set; } = string.Empty;
}
```

**Why strings in domain models?**
- Flexibility for persistence (DynamoDB stores strings)
- TypedIds used at service/business logic layer for type safety
- No need to serialize TypedId to database

---

### Usage in API Endpoints

**Pattern:** Route parameters and body properties use strings; create TypedIds in handlers

```csharp
// src/LibraryService/Routes/libraries/v1/CreateLibraryRoute.cs
public static class Handler
{
    public static async Task<IResult> HandleAsync(
        [FromBody] Request request,
        HttpContext httpContext,
        LibraryRepository libraryRepository,
        IIdGenerator idGenerator)
    {
        var userId = AuthContextHelpers.ExtractUserId(httpContext.User);

        // Generate new TypedId
        var libraryId = idGenerator.NewId();  // Returns string ULID

        var library = new Library
        {
            LibraryId = libraryId,  // Assign string to model
            Name = request.Name,
            CreatedByUserId = userId,
        };

        await libraryRepository.CreateAsync(library);

        return Results.Ok(new Response
        {
            LibraryId = library.LibraryId,  // String in response
            Name = library.Name,
        });
    }
}
```

**Route Parameters:**

```csharp
// String route parameters (standard)
public static async Task<IResult> HandleAsync(
    [FromRoute] string libraryId,
    [FromRoute] string bookId,
    // ... other dependencies)
{
    // Can convert to TypedId if needed for type-safe service calls
    var typedLibraryId = LibraryId.From(libraryId);
    var typedBookId = BookId.From(bookId);

    // Or use strings directly (most common pattern)
    var book = await bookRepository.GetAsync(libraryId, bookId);
}
```

---

### Type Safety Benefits

**Compile-Time Safety:**

```csharp
// ✅ GOOD: Type-safe method signature
public async Task<Book> GetBookAsync(LibraryId libraryId, BookId bookId)
{
    // Cannot pass UserId where LibraryId expected
}

// Usage
var book = await GetBookAsync(
    LibraryId.From(libraryId),
    BookId.From(bookId)
);

// ❌ BAD: Would cause compile error
var book = await GetBookAsync(
    UserId.From(userId),     // Compile error - wrong type
    BookId.From(bookId)
);
```

**Implicit String Conversion:**

```csharp
// TypedId → string conversion is automatic
var userId = UserId.New(generator);

string result = userId;  // Implicit conversion via operator
Console.WriteLine(userId);  // ToString() called automatically

// Can pass TypedId where string expected
await UpdateUserAsync(userId);  // Converts to string automatically

public async Task UpdateUserAsync(string userId) { /* ... */ }
```

**Self-Documenting Code:**

```csharp
// ❌ BAD: What is each string?
public async Task CreateBook(string id1, string id2, string id3)

// ✅ GOOD: Clear intent
public async Task CreateBook(LibraryId libraryId, BookId bookId, UserId userId)
```

---

### ID Generation (ULID)

**IIdGenerator Interface:**

```csharp
// Platform.Shared/IIdGenerator.cs
public interface IIdGenerator
{
    string NewId();
    string NewId(string prefix);
}
```

**ULID Implementation:**

```csharp
// src/LibraryService/Abstractions/UlidGenerator.cs
public sealed class UlidGenerator : IIdGenerator
{
    public string NewId()
    {
        return Ulid.NewUlid().ToString();
    }

    public string NewId(string prefix)
    {
        return $"{prefix}{Ulid.NewUlid()}";
    }
}
```

**Why ULID over UUID:**
- Lexicographically sortable (timestamp prefix)
- Faster generation
- URL-safe (no special characters)
- Supports prefixes (`li_`, `usr_`, etc.)

**Usage:**

```csharp
// Inject IIdGenerator in handlers/services
var userId = idGenerator.NewId();              // "01HXYZ123ABC"
var itemId = idGenerator.NewId("li_");         // "li_01HXYZ123ABC"
```

---

### Integration with DynamoDB

**Pattern:** Entities store strings, use TypedIds at conversion boundaries

```csharp
// src/LibraryService/Data/Entities/LibraryEntity.cs
public class LibraryEntity : IDynamoEntity
{
    public string LibraryId { get; set; } = string.Empty;  // String, not TypedId

    public string PK => DynamoKeyHelpers.LibraryPK(LibraryId);
    public string SK => DynamoKeyHelpers.MetadataSK;

    public static LibraryEntity FromDomain(Library library)
    {
        return new LibraryEntity
        {
            LibraryId = library.LibraryId,  // String-to-string mapping
            Data = JsonSerializer.Serialize(library, JsonSerializerOptionsHelper.CamelCase),
        };
    }

    public Library ToDomain()
    {
        var result = JsonSerializer.Deserialize<Library>(Data, JsonSerializerOptionsHelper.CamelCase);
        return result;
    }
}
```

**Why strings in entities?**
- DynamoDB stores attribute values as strings
- No overhead from TypedId serialization
- Simpler converter logic

---

### Composite ID Pattern

**For hierarchical entity relationships:**

```csharp
// src/LibraryService/Models/CompositeId.cs
[JsonConverter(typeof(CompositeIdJsonConverter))]
public readonly struct CompositeId : IEquatable<CompositeId>
{
    public const string Prefix = "tfk";
    public const char TypeSeparator = ':';
    public const char SegmentSeparator = '/';

    public static CompositeId ForUser(string userId) => Create(EntityType.User, userId);
    public static CompositeId ForLibrary(string libraryId) => Create(EntityType.Library, libraryId);

    public CompositeId WithBook(string bookId) => WithChild(EntityType.Book, bookId);
    public CompositeId WithLoan(string loanId) => WithChild(EntityType.Loan, loanId);

    public override string ToString()
    {
        var parts = Segments.Select(s => $"{EntityTypeHelper.ToShortString(s.Type)}{TypeSeparator}{s.Id}");
        return $"{Prefix}{TypeSeparator}{string.Join(SegmentSeparator, parts)}";
    }

    public static implicit operator string(CompositeId id) => id.ToString();
}
```

**Usage in Domain Models:**

```csharp
public class Book
{
    public string BookId { get; set; } = string.Empty;
    public string LibraryId { get; set; } = string.Empty;

    // Computed composite ID for API responses
    public CompositeId CompositeId => CompositeId.ForLibrary(LibraryId).WithBook(BookId);
}

// API Response:
// {
//   "bookId": "01HXYZ123",
//   "libraryId": "01HABC456",
//   "compositeId": "tfk:lib/01HABC456/b/01HXYZ123"
// }
```

---

### When to Use TypedId

**Use TypedId when:**
- ✅ Method signatures for service/business logic layer
- ✅ Factory methods that create entities
- ✅ Type safety is valuable (preventing ID mixup)
- ✅ Self-documenting code is a priority

**Use strings when:**
- ✅ Domain model properties (persistence layer)
- ✅ API route parameters (JSON serialization)
- ✅ DynamoDB entity properties (attribute values)
- ✅ Repository method parameters (already validated)

**Example - Service Layer:**

```csharp
// Service interface uses TypedIds for clarity
public interface IBookService
{
    Task<Book> GetBookAsync(LibraryId libraryId, BookId bookId);
    Task<Book> CreateBookAsync(LibraryId libraryId, string title, UserId createdBy);
}

// Repository uses strings (closer to database)
public class BookRepository
{
    public async Task<Book?> GetAsync(string libraryId, string bookId) { /* ... */ }
    public async Task CreateAsync(Book book) { /* ... */ }
}
```

---

### Testing with TypedIds

**Create test fixtures:**

```csharp
// Test helper
public static class TestIds
{
    public static UserId TestUser1 => UserId.From("01HTEST1USER1");
    public static UserId TestUser2 => UserId.From("01HTEST1USER2");
    public static LibraryId TestLibrary => LibraryId.From("01HTEST1LIB01");
    public static BookId TestBook => BookId.From("01HTEST1BOOK1");
}

// Usage in tests
[Fact]
public async Task CreateBook_ValidInput_ReturnsBook()
{
    // Arrange
    var libraryId = TestIds.TestLibrary;
    var bookId = TestIds.TestBook;
    var userId = TestIds.TestUser1;

    // Act
    var book = await bookService.CreateBookAsync(libraryId, "Test Book", userId);

    // Assert
    book.LibraryId.Should().Be(libraryId);  // Implicit string conversion
    book.BookId.Should().Be(bookId);
}
```

**Mock IIdGenerator:**

```csharp
// Test setup
var mockIdGenerator = new Mock<IIdGenerator>();
mockIdGenerator.Setup(g => g.NewId()).Returns("01HTEST1MOCK1");

var handler = new CreateLibraryHandler(mockIdGenerator.Object);

// Verify generated ID
var result = await handler.HandleAsync(request);
result.LibraryId.Should().Be("01HTEST1MOCK1");
```

---

### Best Practices

**DO:**
- ✅ Use factory methods (`.New()`, `.From()`, `.Empty`) for consistency
- ✅ Store strings in domain models and entities
- ✅ Use TypedIds at service/business logic boundaries
- ✅ Leverage implicit string conversion
- ✅ Use ULID for sortable, prefixable IDs

**DON'T:**
- ❌ Don't store TypedId in domain models (use strings)
- ❌ Don't serialize TypedId to DynamoDB (serialize underlying string)
- ❌ Don't use `new UserId(value)` directly (use `.From(value)` factory)
- ❌ Don't mix TypedId and Guid (choose one - ULID is preferred)
- ❌ Don't create TypedId for every primitive (only IDs need this pattern)

---

### Complete Example

**Full flow from API to Database:**

```csharp
// 1. API Endpoint - Route parameter is string
public static class GetBookRoute
{
    public static async Task<IResult> HandleAsync(
        [FromRoute] string libraryId,
        [FromRoute] string bookId,
        BookService bookService)
    {
        // 2. Convert to TypedIds for service call (type safety)
        var book = await bookService.GetBookAsync(
            LibraryId.From(libraryId),
            BookId.From(bookId)
        );

        return Results.Ok(book);
    }
}

// 3. Service Layer - TypedId parameters for clarity
public class BookService
{
    public async Task<Book> GetBookAsync(LibraryId libraryId, BookId bookId)
    {
        // 4. Implicit string conversion when calling repository
        return await _repository.GetAsync(libraryId, bookId);
    }
}

// 5. Repository - String parameters (database layer)
public class BookRepository
{
    public async Task<Book?> GetAsync(string libraryId, string bookId)
    {
        var pk = DynamoKeyHelpers.LibraryPK(libraryId);
        var sk = DynamoKeyHelpers.BookSK(bookId);

        // 6. DynamoDB Entity - String properties
        var entity = await GetItemAsync<BookEntity>(pk, sk);
        return entity?.ToDomain();
    }
}

// 7. Domain Model - String properties for persistence
public class Book
{
    public string BookId { get; set; } = string.Empty;
    public string LibraryId { get; set; } = string.Empty;
}
```

---

## Related Documentation

- **[ARCHITECTURE.md](../../ARCHITECTURE.md)** - Where domain models fit
- **[error-modeling.md](error-modeling.md)** - Result pattern for validation
- **[testing.md](testing.md)** - Testing domain models
- **[../guidelines/csharp-core.md](../guidelines/csharp-core.md)** - Core patterns
- **[../guidelines/dynamodb.md](../guidelines/dynamodb.md)** - DynamoDB entity mapping
