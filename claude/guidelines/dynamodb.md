# DynamoDB Guidelines

**Status:** GUIDELINES - Preferred approaches, deviations allowed with justification

**Purpose:** Standard patterns for DynamoDB data modeling in serverless applications.

---

## Single-Table Design Preference

**Principle:** Use single-table design for most applications to minimize costs and maximize performance.

**Why Single-Table?**
- **Cost:** One table = one set of on-demand charges (vs multiple tables)
- **Performance:** Related data co-located, fewer round-trips
- **Serverless-friendly:** Scales automatically, no connection pooling needed
- **Simplicity:** One backup policy, one set of indexes

**When to Use Multiple Tables:**
- Completely separate domains (e.g., user management vs analytics)
- Different access patterns requiring different throughput
- Data with vastly different retention requirements

**Example Structure:**

```hcl
# Terraform
resource "aws_dynamodb_table" "main" {
  name         = "app-table-${var.environment}"
  billing_mode = "PAY_PER_REQUEST"  # On-demand pricing

  hash_key  = "PK"   # Partition Key
  range_key = "SK"   # Sort Key

  attribute {
    name = "PK"
    type = "S"
  }

  attribute {
    name = "SK"
    type = "S"
  }

  # GSI for alternate access patterns
  global_secondary_index {
    name            = "GSI1"
    hash_key        = "GSI1PK"
    range_key       = "GSI1SK"
    projection_type = "ALL"
  }

  attribute {
    name = "GSI1PK"
    type = "S"
  }

  attribute {
    name = "GSI1SK"
    type = "S"
  }

  tags = {
    Environment = var.environment
    Service     = var.service_name
  }
}
```

---

## Access-Pattern-Driven Modeling

**Principle:** Design keys and indexes based on how you'll query the data, not how you model it in your domain.

**Process:**

1. **List all access patterns** (queries your application needs)
2. **Design primary key** (PK/SK) for most common pattern
3. **Design GSIs** for alternate patterns
4. **Verify coverage** - every query has a key path

**Example Access Patterns:**

```markdown
## User Service Access Patterns

1. Get user by ID
2. Get user by email
3. List all users in a library
4. Get user's recent loans
5. List libraries for a user
```

**Key Design:**

| Access Pattern | Key Structure | Index |
|----------------|---------------|-------|
| Get user by ID | PK=`USER#{userId}`, SK=`PROFILE` | Table |
| Get user by email | GSI1PK=`EMAIL#{email}`, GSI1SK=`USER` | GSI1 |
| List users in library | PK=`LIBRARY#{libraryId}`, SK begins_with `USER#` | Table |
| Get user's loans | GSI1PK=`USER#{userId}`, GSI1SK begins_with `LOAN#` | GSI1 |
| List user's libraries | PK=`USER#{userId}`, SK begins_with `LIBRARY#` | Table |

---

## Key Encoding with Type Prefixes

**Principle:** Use explicit type prefixes in keys for clarity and to enable queries.

**Pattern:** `{TYPE}#{ID}`

**Benefits:**
- **Clarity:** Easy to identify item type from key
- **Querying:** `begins_with` filters by type
- **Uniqueness:** Prevents ID collisions across types
- **Debugging:** Keys are self-documenting

**Examples:**

```typescript
// ✅ GOOD: Type prefixes
PK: "USER#550e8400-e29b-41d4-a716-446655440000"
SK: "PROFILE#METADATA"

PK: "LIBRARY#city-central"
SK: "USER#550e8400-e29b-41d4-a716-446655440000"

PK: "USER#550e8400-e29b-41d4-a716-446655440000"
SK: "LOAN#2026-01-11#loan_12345"  // ISO date for sorting

// ❌ BAD: No type prefix
PK: "550e8400-e29b-41d4-a716-446655440000"
SK: "METADATA"  // What type of item is this?
```

**Type Prefix Conventions:**

| Entity | PK Prefix | SK Prefix | GSI1PK | GSI1SK |
|--------|-----------|-----------|--------|--------|
| User | `USER#{userId}` | `PROFILE` | `EMAIL#{email}` | `USER` |
| Library | `LIBRARY#{libraryId}` | `METADATA` | - | - |
| User in Library | `LIBRARY#{libraryId}` | `USER#{userId}` | `USER#{userId}` | `LIBRARY#{libraryId}` |
| Loan | `USER#{userId}` | `LOAN#{date}#{loanId}` | `LOAN#{loanId}` | `USER#{userId}` |
| Book | `BOOK#{bookId}` | `METADATA` | - | - |

---

## Explicit Tenant / Library / User Scoping

**Principle:** Always include tenant/library/user scope in partition keys for isolation and query efficiency.

**Why:**
- **Security:** Partition-level isolation prevents cross-tenant queries
- **Performance:** Queries scoped to partition are fast
- **Cost:** Fewer items scanned = lower RCU costs
- **Multi-tenancy:** Natural tenant isolation

**Security Note:** For multi-tenant applications, always include tenant ID in the partition key for architectural isolation. See [security.md](security.md#isolation-over-inline-security-logic) for detailed rationale on why partition-key-based isolation is more secure than code-level filtering.

**Multi-Tenant Pattern:**

```typescript
// ✅ GOOD: Tenant-scoped keys
PK: "TENANT#{tenantId}#USER#{userId}"
SK: "PROFILE"

PK: "TENANT#{tenantId}#LIBRARY#{libraryId}"
SK: "USER#{userId}"

// ❌ BAD: No tenant scoping
PK: "USER#{userId}"  // Can query across tenants accidentally
SK: "PROFILE"
```

**User-Scoped Pattern:**

```typescript
// User's items (loans, preferences, etc.)
PK: "USER#{userId}"
SK: "LOAN#{date}#{loanId}"

PK: "USER#{userId}"
SK: "PREFERENCE#{key}"

// Query: Get all loans for user
const params = {
  TableName: 'app-table',
  KeyConditionExpression: 'PK = :pk AND begins_with(SK, :sk)',
  ExpressionAttributeValues: {
    ':pk': `USER#${userId}`,
    ':sk': 'LOAN#'
  }
};
```

**Library-Scoped Pattern:**

```typescript
// Library's items (users, books, etc.)
PK: "LIBRARY#{libraryId}"
SK: "USER#{userId}"

PK: "LIBRARY#{libraryId}"
SK: "BOOK#{bookId}"

// Query: Get all users in library
const params = {
  TableName: 'app-table',
  KeyConditionExpression: 'PK = :pk AND begins_with(SK, :sk)',
  ExpressionAttributeValues: {
    ':pk': `LIBRARY#${libraryId}`,
    ':sk': 'USER#'
  }
};
```

---

## Separation of Domain and Storage Models

**Principle:** Domain models (business logic) are separate from DynamoDB item structure (persistence).

**Why:**
- **Testability:** Domain models can be tested without DynamoDB
- **Flexibility:** Change storage without changing domain
- **Clarity:** Business logic doesn't leak into persistence
- **Portability:** Easier to migrate to different storage later

**Architecture:**

```
Domain Layer (Pure Business Logic)
  ↓
  Repository Interface (IUserRepository)
  ↓
Infrastructure Layer (DynamoDB Implementation)
```

**Example - Domain Model:**

```csharp
// src/LibraryService/LibraryService.Domain/Entities/User.cs
namespace LibraryService.Domain.Entities;

public class User
{
    public Guid Id { get; private set; }
    public Email Email { get; private set; }  // Value object
    public string Name { get; private set; }
    public bool IsActive { get; private set; } = true;
    public DateTime CreatedAt { get; private set; }

    private User() { }  // For infrastructure

    public static User Create(Email email, string name, IClock clock)
    {
        return new User
        {
            Id = Guid.NewGuid(),
            Email = email,
            Name = name,
            IsActive = true,
            CreatedAt = clock.UtcNow
        };
    }

    public void Deactivate()
    {
        if (!IsActive)
            throw new InvalidOperationException("User already inactive");

        IsActive = false;
    }
}
```

**Example - Repository Interface (Domain Layer):**

```csharp
// src/LibraryService/LibraryService.Domain/Interfaces/IUserRepository.cs
namespace LibraryService.Domain.Interfaces;

public interface IUserRepository
{
    Task<User?> GetByIdAsync(Guid userId);
    Task<User?> GetByEmailAsync(Email email);
    Task<IEnumerable<User>> GetByLibraryAsync(string libraryId);
    Task SaveAsync(User user);
    Task DeleteAsync(Guid userId);
}
```

**Example - DynamoDB Item (Storage Model):**

```csharp
// src/LibraryService/LibraryService.Infrastructure/Persistence/UserItem.cs
namespace LibraryService.Infrastructure.Persistence;

public class UserItem
{
    [DynamoDBHashKey("PK")]
    public string PK { get; set; } = null!;

    [DynamoDBRangeKey("SK")]
    public string SK { get; set; } = null!;

    [DynamoDBProperty("GSI1PK")]
    public string? GSI1PK { get; set; }

    [DynamoDBProperty("GSI1SK")]
    public string? GSI1SK { get; set; }

    [DynamoDBProperty("Type")]
    public string Type { get; set; } = "USER";

    [DynamoDBProperty("UserId")]
    public string UserId { get; set; } = null!;

    [DynamoDBProperty("Email")]
    public string Email { get; set; } = null!;

    [DynamoDBProperty("Name")]
    public string Name { get; set; } = null!;

    [DynamoDBProperty("IsActive")]
    public bool IsActive { get; set; }

    [DynamoDBProperty("CreatedAt")]
    public string CreatedAt { get; set; } = null!;  // ISO 8601 string

    // Factory method: Domain → Storage
    public static UserItem FromDomain(User user, string? libraryId = null)
    {
        var pk = libraryId != null
            ? $"LIBRARY#{libraryId}"
            : $"USER#{user.Id}";

        var sk = libraryId != null
            ? $"USER#{user.Id}"
            : "PROFILE";

        return new UserItem
        {
            PK = pk,
            SK = sk,
            GSI1PK = $"EMAIL#{user.Email.Value}",
            GSI1SK = "USER",
            UserId = user.Id.ToString(),
            Email = user.Email.Value,
            Name = user.Name,
            IsActive = user.IsActive,
            CreatedAt = user.CreatedAt.ToString("O")  // ISO 8601
        };
    }

    // Mapping method: Storage → Domain
    public User ToDomain()
    {
        // Use reflection or private constructor to hydrate domain entity
        var user = (User)Activator.CreateInstance(typeof(User), nonPublic: true)!;

        typeof(User).GetProperty(nameof(User.Id))!.SetValue(user, Guid.Parse(UserId));
        typeof(User).GetProperty(nameof(User.Email))!.SetValue(user, Email.Create(Email));
        typeof(User).GetProperty(nameof(User.Name))!.SetValue(user, Name);
        typeof(User).GetProperty(nameof(User.IsActive))!.SetValue(user, IsActive);
        typeof(User).GetProperty(nameof(User.CreatedAt))!.SetValue(user, DateTime.Parse(CreatedAt));

        return user;
    }
}
```

**Example - Repository Implementation:**

```csharp
// src/LibraryService/LibraryService.Infrastructure/Persistence/DynamoDbUserRepository.cs
namespace LibraryService.Infrastructure.Persistence;

public class DynamoDbUserRepository : IUserRepository
{
    private readonly IDynamoDBContext _context;
    private readonly ILogger<DynamoDbUserRepository> _logger;

    public DynamoDbUserRepository(IDynamoDBContext context, ILogger<DynamoDbUserRepository> logger)
    {
        _context = context;
        _logger = logger;
    }

    public async Task<User?> GetByIdAsync(Guid userId)
    {
        _logger.LogInformation("Getting user {UserId}", userId);

        var item = await _context.LoadAsync<UserItem>($"USER#{userId}", "PROFILE");

        return item?.ToDomain();
    }

    public async Task<User?> GetByEmailAsync(Email email)
    {
        _logger.LogInformation("Getting user by email {Email}", email.Value);

        var queryConfig = new DynamoDBOperationConfig
        {
            IndexName = "GSI1"
        };

        var search = _context.QueryAsync<UserItem>(
            $"EMAIL#{email.Value}",
            QueryOperator.BeginsWith,
            new[] { "USER" },
            queryConfig
        );

        var items = await search.GetRemainingAsync();
        var item = items.FirstOrDefault();

        return item?.ToDomain();
    }

    public async Task<IEnumerable<User>> GetByLibraryAsync(string libraryId)
    {
        _logger.LogInformation("Getting users for library {LibraryId}", libraryId);

        var search = _context.QueryAsync<UserItem>(
            $"LIBRARY#{libraryId}",
            QueryOperator.BeginsWith,
            new[] { "USER#" }
        );

        var items = await search.GetRemainingAsync();

        return items.Select(item => item.ToDomain());
    }

    public async Task SaveAsync(User user)
    {
        _logger.LogInformation("Saving user {UserId}", user.Id);

        var item = UserItem.FromDomain(user);
        await _context.SaveAsync(item);
    }

    public async Task DeleteAsync(Guid userId)
    {
        _logger.LogInformation("Deleting user {UserId}", userId);

        await _context.DeleteAsync<UserItem>($"USER#{userId}", "PROFILE");
    }
}
```

---

## On-Demand Billing Preference

**Principle:** Use on-demand billing (PAY_PER_REQUEST) by default for serverless applications.

**Why On-Demand?**
- **Zero-cost-when-idle:** No charges when not in use
- **No capacity planning:** Auto-scales to demand
- **Cost-effective for variable traffic:** Pay only for requests
- **Simpler:** No need to monitor/adjust provisioned capacity

**When to Use Provisioned Capacity:**
- Predictable, steady traffic
- High volume (>50% utilization of provisioned capacity)
- Cost optimization for known workloads

**Terraform Configuration:**

```hcl
# modules/dynamodb-table/main.tf
resource "aws_dynamodb_table" "main" {
  name         = var.table_name
  billing_mode = "PAY_PER_REQUEST"  # On-demand default

  hash_key  = "PK"
  range_key = "SK"

  attribute {
    name = "PK"
    type = "S"
  }

  attribute {
    name = "SK"
    type = "S"
  }

  # Optional: Switch to provisioned for prod if traffic is predictable
  # billing_mode = var.environment == "prod" ? "PROVISIONED" : "PAY_PER_REQUEST"
  # read_capacity  = var.environment == "prod" ? 5 : null
  # write_capacity = var.environment == "prod" ? 5 : null
}
```

**Cost Comparison:**

| Billing Mode | Cost Model | Best For |
|--------------|------------|----------|
| **On-Demand** | $1.25 per million write requests<br>$0.25 per million read requests | Variable traffic, dev/staging, serverless apps |
| **Provisioned** | $0.00065 per WCU-hour<br>$0.00013 per RCU-hour | Predictable traffic, high volume, always-on apps |

---

## Avoid Premature Relational Databases

**Principle:** Start with DynamoDB, migrate to RDS only when relational requirements justify the cost.

**DynamoDB Advantages:**
- ✅ Serverless (zero-cost-when-idle)
- ✅ Auto-scaling
- ✅ No connection pooling
- ✅ No cold start issues
- ✅ Simple backup/restore
- ✅ Global tables for multi-region

**RDS Disadvantages:**
- ❌ Always-on cost (~$15-50/month minimum)
- ❌ Requires connection management
- ❌ Cold start delays in Lambda
- ❌ Manual scaling
- ❌ Backup/restore complexity

**When to Migrate to RDS:**
- Complex relational queries (JOINs across many tables)
- Heavy aggregations (SUM, AVG, GROUP BY)
- Full-text search requirements
- Existing SQL codebase
- Team expertise only in SQL

**Migration Strategy:**

```markdown
1. **Start with DynamoDB** for all services
2. **Identify pain points** - Complex queries, awkward access patterns
3. **Evaluate cost trade-offs** - RDS monthly cost vs DynamoDB request costs
4. **Plan migration** - Dual-write period, data migration script
5. **Migrate incrementally** - One service/table at a time
6. **Document rationale** - Why RDS was necessary
```

---

## Future Portability Considerations

**Principle:** Design storage layer for potential future migration, but don't over-engineer.

**Portability Strategies:**

1. **Repository Pattern:** Abstract storage behind interfaces (already done)
2. **Domain Models Separate:** No DynamoDB leakage into domain (already done)
3. **Avoid DynamoDB-Specific Logic in Application Layer:** Keep query complexity in infrastructure

**Example - Portable Design:**

```csharp
// ✅ GOOD: Storage-agnostic application layer
public class MemberService : IMemberService
{
    private readonly IUserRepository _repository;

    public MemberService(IUserRepository repository)
    {
        _repository = repository;  // Could be DynamoDB, SQL, MongoDB, etc.
    }

    public async Task<User?> GetUserAsync(Guid id)
    {
        return await _repository.GetByIdAsync(id);
    }
}

// ❌ BAD: DynamoDB-specific logic in application
public class MemberService
{
    private readonly IAmazonDynamoDB _dynamoDb;

    public async Task<User?> GetUserAsync(Guid id)
    {
        var request = new QueryRequest
        {
            TableName = "users",
            KeyConditionExpression = "PK = :pk",
            // DynamoDB-specific query in application layer
        };

        var response = await _dynamoDb.QueryAsync(request);
        // ...
    }
}
```

**Future Migration Options:**
- DynamoDB → PostgreSQL (relational requirements)
- DynamoDB → MongoDB (document store with richer queries)
- DynamoDB → Aurora Serverless (serverless + relational)

**Migration Ease:**
- **Easy:** Repository pattern, domain models separate
- **Medium:** Rewrite repository implementations, test thoroughly
- **Hard:** DynamoDB-specific logic in application layer

---

## Entity Converter Pattern

**Principle:** Use standardized converter pattern to transform between domain models and DynamoDB attribute maps.

**Why:**
- **Type Safety:** Compile-time checking for attribute conversions
- **Consistency:** All entities follow the same conversion pattern
- **Maintainability:** Centralized conversion logic
- **Testability:** Converters can be unit tested independently
- **AI-Friendly:** Source generator creates boilerplate automatically

### IDynamoEntity Interface

**Core Interface:** All DynamoDB entities implement `IDynamoEntity`.

**Location:** `src/Shared/Platform.DynamoDB/IDynamoEntity.cs`

**Required Fields:**

```csharp
public interface IDynamoEntity
{
    string PK { get; set; }           // Partition Key
    string SK { get; set; }           // Sort Key
    string EntityType { get; set; }   // Entity type identifier
    string? Data { get; set; }        // JSON-serialized domain model
    DateTime CreatedAt { get; set; }  // Creation timestamp
    DateTime UpdatedAt { get; set; }  // Last update timestamp
}
```

**Why These Fields:**
- `PK/SK`: Required for DynamoDB single-table design
- `EntityType`: Enables filtering by entity type in queries
- `Data`: Stores full domain model as JSON (for non-indexed properties)
- `CreatedAt/UpdatedAt`: Audit trail, useful for debugging and retention policies

**Optional Interface: ILibraryOwned**

```csharp
public interface ILibraryOwned
{
    string LibraryId { get; }
}
```

**Purpose:** Entities that belong to a library implement this for automatic library-scoping.

### Converter Pattern Structure

**Pattern:** Static class with two methods for bidirectional conversion.

**Standard Methods:**

```csharp
public static class {EntityName}Converter
{
    // Domain Model → DynamoDB Attributes
    public static Dictionary<string, AttributeValue> ToAttributes({EntityName} entity)
    {
        // Convert entity to DynamoDB attribute map
    }

    // DynamoDB Attributes → Domain Model
    public static {EntityName} FromAttributes(Dictionary<string, AttributeValue> attributes)
    {
        // Convert attribute map back to entity
    }
}
```

### Base Conversion Utilities

**Location:** `src/Shared/Platform.DynamoDB/DynamoEntityConverter.cs`

**Purpose:** Shared utilities for common conversion operations.

**ToAttributesBase Method:**

```csharp
public static class DynamoEntityConverter
{
    // Converts IDynamoEntity base fields to attributes
    public static Dictionary<string, AttributeValue> ToAttributesBase<T>(T entity)
        where T : IDynamoEntity
    {
        return new Dictionary<string, AttributeValue>
        {
            ["PK"] = new AttributeValue { S = entity.PK },
            ["SK"] = new AttributeValue { S = entity.SK },
            ["EntityType"] = new AttributeValue { S = entity.EntityType },
            ["Data"] = new AttributeValue { S = entity.Data ?? "{}" },
            ["CreatedAt"] = new AttributeValue { S = entity.CreatedAt.ToString("O") },
            ["UpdatedAt"] = new AttributeValue { S = entity.UpdatedAt.ToString("O") }
        };
    }

    // Hydrates IDynamoEntity base fields from attributes
    public static void FromAttributesBase<T>(Dictionary<string, AttributeValue> attributes, T entity)
        where T : IDynamoEntity
    {
        entity.PK = attributes["PK"].S;
        entity.SK = attributes["SK"].S;
        entity.EntityType = attributes["EntityType"].S;
        entity.Data = attributes.ContainsKey("Data") ? attributes["Data"].S : null;
        entity.CreatedAt = DateTime.Parse(attributes["CreatedAt"].S);
        entity.UpdatedAt = DateTime.Parse(attributes["UpdatedAt"].S);
    }
}
```

**AttributeHelpers Methods:**

**Location:** `src/Shared/Platform.DynamoDB/AttributeHelpers.cs`

**Purpose:** Type-safe attribute value conversion with null handling.

```csharp
public static class AttributeHelpers
{
    // Get string attribute or throw if missing
    public static string GetString(this Dictionary<string, AttributeValue> attributes, string key)
    {
        if (!attributes.TryGetValue(key, out var attr) || string.IsNullOrEmpty(attr.S))
            throw new InvalidOperationException($"Missing required attribute: {key}");
        return attr.S;
    }

    // Get nullable string attribute
    public static string? GetStringOrNull(this Dictionary<string, AttributeValue> attributes, string key)
    {
        return attributes.TryGetValue(key, out var attr) ? attr.S : null;
    }

    // Get boolean attribute with default
    public static bool GetBool(this Dictionary<string, AttributeValue> attributes, string key, bool defaultValue = false)
    {
        if (!attributes.TryGetValue(key, out var attr))
            return defaultValue;
        return attr.BOOL;
    }

    // Get DateTime attribute
    public static DateTime GetDateTime(this Dictionary<string, AttributeValue> attributes, string key)
    {
        var str = GetString(attributes, key);
        return DateTime.Parse(str);
    }

    // Get nullable DateTime attribute
    public static DateTime? GetDateTimeOrNull(this Dictionary<string, AttributeValue> attributes, string key)
    {
        var str = GetStringOrNull(attributes, key);
        return str != null ? DateTime.Parse(str) : null;
    }

    // Get integer attribute
    public static int GetInt(this Dictionary<string, AttributeValue> attributes, string key, int defaultValue = 0)
    {
        if (!attributes.TryGetValue(key, out var attr))
            return defaultValue;
        return int.Parse(attr.N);
    }
}
```

### DynamoKeyHelpers

**Location:** `src/LibraryService/Data/Helpers/DynamoKeyHelpers.cs`

**Purpose:** Centralized key prefix generation for consistent key structure.

**Standard Key Prefixes:**

```csharp
public static class DynamoKeyHelpers
{
    // Entity key generation
    public static string LibraryKey(string libraryId) => $"LIBRARY#{libraryId}";
    public static string UserKey(string userId) => $"USER#{userId}";
    public static string BookKey(string bookId) => $"BOOK#{bookId}";
    public static string LoanKey(string loanId) => $"LOAN#{loanId}";
    public static string SessionKey(string sessionId) => $"SESSION#{sessionId}";
    public static string InvitationKey(string invitationId) => $"INVITATION#{invitationId}";
    public static string TokenKey(string tokenId) => $"TOKEN#{tokenId}";
    public static string InvoiceKey(string invoiceId) => $"INVOICE#{invoiceId}";

    // Metadata sort keys
    public static string MetadataKey() => "METADATA";
    public static string ProfileKey() => "PROFILE";

    // Prefixed keys for queries
    public static string UserPrefix() => "USER#";
    public static string BookPrefix() => "BOOK#";
    public static string LoanPrefix() => "LOAN#";
}
```

**Why Centralized:**
- ✅ Single source of truth for key formats
- ✅ Prevents typos and inconsistencies
- ✅ Easy to update key structure globally
- ✅ Self-documenting (method names explain usage)

**Usage in Entities:**

```csharp
public class BookEntity : IDynamoEntity, ILibraryOwned
{
    public string PK { get; set; } = null!;
    public string SK { get; set; } = null!;
    // ... other properties

    public static BookEntity FromDomain(Book book)
    {
        return new BookEntity
        {
            PK = DynamoKeyHelpers.LibraryKey(book.LibraryId.Value),  // LIBRARY#{libraryId}
            SK = DynamoKeyHelpers.BookKey(book.Id.Value), // BOOK#{bookId}
            // ...
        };
    }
}
```

### Source Generator Pattern

**Attribute:** `[GenerateConverter]` - Marks entities for automatic converter generation.

**Location:** `src/Shared/Platform.DynamoDB/GenerateConverterAttribute.cs`

```csharp
[AttributeUsage(AttributeTargets.Class)]
public class GenerateConverterAttribute : Attribute
{
}
```

**Generator Location:** `src/Shared/Platform.DynamoDB.Generators/DynamoConverterGenerator.cs`

**What It Generates:**

```csharp
// Input: Entity with [GenerateConverter] attribute
[GenerateConverter]
public class BookEntity : IDynamoEntity
{
    public string PK { get; set; } = null!;
    public string SK { get; set; } = null!;
    public string BookId { get; set; } = null!;
    public string Title { get; set; } = null!;
    public bool IsAvailable { get; set; }
    // ... base IDynamoEntity properties
}

// Output: Generated converter class
public static class BookEntityConverter
{
    public static Dictionary<string, AttributeValue> ToAttributes(BookEntity entity)
    {
        var attributes = DynamoEntityConverter.ToAttributesBase(entity);
        attributes["BookId"] = new AttributeValue { S = entity.BookId };
        attributes["Title"] = new AttributeValue { S = entity.Title };
        attributes["IsAvailable"] = new AttributeValue { BOOL = entity.IsAvailable };
        return attributes;
    }

    public static BookEntity FromAttributes(Dictionary<string, AttributeValue> attributes)
    {
        var entity = new BookEntity();
        DynamoEntityConverter.FromAttributesBase(attributes, entity);
        entity.BookId = attributes.GetString("BookId");
        entity.Title = attributes.GetString("Title");
        entity.IsAvailable = attributes.GetBool("IsAvailable");
        return entity;
    }
}
```

**When to Use:**
- ✅ **USE** source generator for entities with many indexed properties
- ✅ **USE** when entity structure is stable
- ❌ **DON'T USE** for simple entities (only PK/SK/Data)
- ❌ **DON'T USE** if you need custom conversion logic

### Entity Pattern Examples

**Pattern 1: Simple Entity (Only JSON Data)**

**Use Case:** Entity with no indexed properties, all data in `Data` field.

**Example - Library:**

```csharp
// src/LibraryService/Data/Entities/LibraryEntity.cs
public class LibraryEntity : IDynamoEntity
{
    public string PK { get; set; } = null!;
    public string SK { get; set; } = null!;
    public string EntityType { get; set; } = "Library";
    public string? Data { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }

    // No additional properties - everything in Data field
}

// Converter (manually written)
public static class LibraryConverter
{
    public static Dictionary<string, AttributeValue> ToAttributes(LibraryEntity entity)
    {
        return DynamoEntityConverter.ToAttributesBase(entity);
    }

    public static LibraryEntity FromAttributes(Dictionary<string, AttributeValue> attributes)
    {
        var entity = new LibraryEntity();
        DynamoEntityConverter.FromAttributesBase(attributes, entity);
        return entity;
    }
}
```

**FromDomain/ToDomain Methods:**

```csharp
public class LibraryEntity : IDynamoEntity
{
    // ... properties

    public static LibraryEntity FromDomain(Library library)
    {
        return new LibraryEntity
        {
            PK = DynamoKeyHelpers.LibraryKey(library.Id.Value),
            SK = DynamoKeyHelpers.MetadataKey(),
            EntityType = "Library",
            Data = JsonSerializer.Serialize(library),  // Full domain model as JSON
            CreatedAt = library.CreatedAt,
            UpdatedAt = library.UpdatedAt
        };
    }

    public Library ToDomain()
    {
        if (string.IsNullOrEmpty(Data))
            throw new InvalidOperationException("Library data is missing");

        return JsonSerializer.Deserialize<Library>(Data)
            ?? throw new InvalidOperationException("Failed to deserialize library");
    }
}
```

**Pattern 2: Complex Entity with Indexed Properties**

**Use Case:** Entity with properties queried independently (not just full JSON).

**Example - Book:**

```csharp
// src/LibraryService/Data/Entities/BookEntity.cs
[GenerateConverter]  // Source generator creates converter
public class BookEntity : IDynamoEntity, ILibraryOwned
{
    // IDynamoEntity base fields
    public string PK { get; set; } = null!;
    public string SK { get; set; } = null!;
    public string EntityType { get; set; } = "Book";
    public string? Data { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }

    // Indexed properties (queryable independently)
    public string BookId { get; set; } = null!;
    public string Title { get; set; } = null!;
    public string LibraryId { get; set; } = null!;
    public bool IsAvailable { get; set; }
    public DateTime? PublishedAt { get; set; }

    // ILibraryOwned implementation
    string ILibraryOwned.LibraryId => LibraryId;
}

// FromDomain/ToDomain methods
public class BookEntity : IDynamoEntity, ILibraryOwned
{
    // ... properties

    public static BookEntity FromDomain(Book book)
    {
        return new BookEntity
        {
            PK = DynamoKeyHelpers.LibraryKey(book.LibraryId.Value),
            SK = DynamoKeyHelpers.BookKey(book.Id.Value),
            EntityType = "Book",
            Data = JsonSerializer.Serialize(book),  // Full model
            BookId = book.Id.Value,              // Indexed for queries
            Title = book.Title,                  // Indexed for queries
            LibraryId = book.LibraryId.Value,    // Indexed for queries
            IsAvailable = book.IsAvailable,      // Indexed for queries
            PublishedAt = book.PublishedAt,      // Indexed for queries
            CreatedAt = book.CreatedAt,
            UpdatedAt = book.UpdatedAt
        };
    }

    public Book ToDomain()
    {
        if (string.IsNullOrEmpty(Data))
            throw new InvalidOperationException("Book data is missing");

        return JsonSerializer.Deserialize<Book>(Data)
            ?? throw new InvalidOperationException("Failed to deserialize book");
    }
}
```

**Why Indexed Properties?**
- Enables queries without deserializing `Data` field
- Example: "Find all available books in library X"
- Query uses `LibraryId` and `IsAvailable` directly (no full JSON scan)

**Pattern 3: Entity with GSI Attributes**

**Use Case:** Entity queried via Global Secondary Index.

**Example - BFF Session:**

```csharp
// src/LibraryService/Data/Entities/SessionEntity.cs
[GenerateConverter]
public class BffSessionEntity : IDynamoEntity
{
    // IDynamoEntity base fields
    public string PK { get; set; } = null!;
    public string SK { get; set; } = null!;
    public string EntityType { get; set; } = "BffSession";
    public string? Data { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }

    // Indexed properties
    public string SessionId { get; set; } = null!;
    public string UserId { get; set; } = null!;
    public DateTime ExpiresAt { get; set; }

    // GSI attributes for alternate query patterns
    public string? GSI1PK { get; set; }  // User lookup: USER#{userId}
    public string? GSI1SK { get; set; }  // Sort key: SESSION#{sessionId}

    public static BffSessionEntity FromDomain(BffSession session)
    {
        return new BffSessionEntity
        {
            PK = DynamoKeyHelpers.SessionKey(session.SessionId.Value),
            SK = DynamoKeyHelpers.MetadataKey(),
            EntityType = "BffSession",
            Data = JsonSerializer.Serialize(session),
            SessionId = session.SessionId.Value,
            UserId = session.UserId.Value,
            ExpiresAt = session.ExpiresAt,
            GSI1PK = DynamoKeyHelpers.UserKey(session.UserId.Value),  // Query by user
            GSI1SK = DynamoKeyHelpers.SessionKey(session.SessionId.Value),
            CreatedAt = session.CreatedAt,
            UpdatedAt = session.UpdatedAt
        };
    }

    public BffSession ToDomain()
    {
        if (string.IsNullOrEmpty(Data))
            throw new InvalidOperationException("Session data is missing");

        return JsonSerializer.Deserialize<BffSession>(Data)
            ?? throw new InvalidOperationException("Failed to deserialize session");
    }
}
```

**Access Patterns:**
1. **Primary Table:** Get session by SessionId → PK=`SESSION#{id}`, SK=`METADATA`
2. **GSI1:** Get all sessions for user → GSI1PK=`USER#{userId}`, GSI1SK begins_with `SESSION#`

**Pattern 4: Library-Owned Entity**

**Use Case:** Entity that always belongs to a library.

**Example - Loan:**

```csharp
// src/LibraryService/Data/Entities/LoanEntity.cs
[GenerateConverter]
public class LoanEntity : IDynamoEntity, ILibraryOwned
{
    // IDynamoEntity base fields
    public string PK { get; set; } = null!;
    public string SK { get; set; } = null!;
    public string EntityType { get; set; } = "Loan";
    public string? Data { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }

    // Indexed properties
    public string LoanId { get; set; } = null!;
    public string LibraryId { get; set; } = null!;
    public string Status { get; set; } = null!;
    public DateTime LoanedAt { get; set; }

    // ILibraryOwned implementation
    string ILibraryOwned.LibraryId => LibraryId;

    public static LoanEntity FromDomain(Loan loan)
    {
        return new LoanEntity
        {
            PK = DynamoKeyHelpers.LibraryKey(loan.LibraryId.Value),
            SK = DynamoKeyHelpers.LoanKey(loan.Id.Value),
            EntityType = "Loan",
            Data = JsonSerializer.Serialize(loan),
            LoanId = loan.Id.Value,
            LibraryId = loan.LibraryId.Value,
            Status = loan.Status.ToString(),
            LoanedAt = loan.LoanedAt,
            CreatedAt = loan.CreatedAt,
            UpdatedAt = loan.UpdatedAt
        };
    }

    public Loan ToDomain()
    {
        if (string.IsNullOrEmpty(Data))
            throw new InvalidOperationException("Loan data is missing");

        return JsonSerializer.Deserialize<Loan>(Data)
            ?? throw new InvalidOperationException("Failed to deserialize loan");
    }
}
```

**Key Structure:**
- PK: `LIBRARY#{libraryId}` - Enables querying all loans for library
- SK: `LOAN#{loanId}` - Unique identifier within library scope

**Query Example:** "Get all loans for library X"
- Query: PK=`LIBRARY#{libraryId}`, SK begins_with `LOAN#`
- Result: All loans scoped to that library

### Repository Integration

**Base Repository Pattern:**

**Location:** `src/LibraryService/Data/DynamoRepository.cs`

```csharp
public abstract class DynamoRepository<T> where T : IDynamoEntity
{
    protected readonly IAmazonDynamoDB Client;
    protected readonly string TableName;
    protected readonly ILogger Logger;

    protected DynamoRepository(
        IAmazonDynamoDB client,
        string tableName,
        ILogger logger)
    {
        Client = client;
        TableName = tableName;
        Logger = logger;
    }

    // Generic Get by PK/SK
    protected async Task<T?> GetItemAsync(
        string pk,
        string sk,
        Func<Dictionary<string, AttributeValue>, T> fromAttributes)
    {
        var request = new GetItemRequest
        {
            TableName = TableName,
            Key = new Dictionary<string, AttributeValue>
            {
                ["PK"] = new AttributeValue { S = pk },
                ["SK"] = new AttributeValue { S = sk }
            }
        };

        var response = await Client.GetItemAsync(request);

        return response.Item.Count > 0
            ? fromAttributes(response.Item)
            : default;
    }

    // Generic Put item
    protected async Task PutItemAsync(
        T entity,
        Func<T, Dictionary<string, AttributeValue>> toAttributes)
    {
        var request = new PutItemRequest
        {
            TableName = TableName,
            Item = toAttributes(entity)
        };

        await Client.PutItemAsync(request);
    }

    // Generic Query
    protected async Task<List<T>> QueryAsync(
        string pk,
        string? skPrefix,
        Func<Dictionary<string, AttributeValue>, T> fromAttributes)
    {
        var keyCondition = skPrefix != null
            ? "PK = :pk AND begins_with(SK, :sk)"
            : "PK = :pk";

        var expressionValues = new Dictionary<string, AttributeValue>
        {
            [":pk"] = new AttributeValue { S = pk }
        };

        if (skPrefix != null)
            expressionValues[":sk"] = new AttributeValue { S = skPrefix };

        var request = new QueryRequest
        {
            TableName = TableName,
            KeyConditionExpression = keyCondition,
            ExpressionAttributeValues = expressionValues
        };

        var response = await Client.QueryAsync(request);

        return response.Items.Select(fromAttributes).ToList();
    }
}
```

**Concrete Repository Example:**

```csharp
// src/LibraryService/Data/Repositories/BookRepository.cs
public class BookRepository : DynamoRepository<BookEntity>
{
    public BookRepository(
        IAmazonDynamoDB client,
        string tableName,
        ILogger<BookRepository> logger)
        : base(client, tableName, logger)
    {
    }

    public async Task<BookEntity?> GetByIdAsync(string libraryId, string bookId)
    {
        var pk = DynamoKeyHelpers.LibraryKey(libraryId);
        var sk = DynamoKeyHelpers.BookKey(bookId);

        return await GetItemAsync(pk, sk, BookEntityConverter.FromAttributes);
    }

    public async Task<List<BookEntity>> GetByLibraryIdAsync(string libraryId)
    {
        var pk = DynamoKeyHelpers.LibraryKey(libraryId);
        var skPrefix = DynamoKeyHelpers.BookPrefix();

        return await QueryAsync(pk, skPrefix, BookEntityConverter.FromAttributes);
    }

    public async Task SaveAsync(BookEntity book)
    {
        await PutItemAsync(book, BookEntityConverter.ToAttributes);
    }
}
```

**Flow: Domain → Entity → DynamoDB:**

```
1. Domain Model (Book)
   ↓
2. BookEntity.FromDomain(book)  // Domain → Entity
   ↓
3. BookEntityConverter.ToAttributes(entity)  // Entity → Attributes
   ↓
4. PutItemRequest(attributes)  // Attributes → DynamoDB
```

**Flow: DynamoDB → Entity → Domain:**

```
1. GetItemResponse(attributes)  // DynamoDB → Attributes
   ↓
2. BookEntityConverter.FromAttributes(attributes)  // Attributes → Entity
   ↓
3. entity.ToDomain()  // Entity → Domain Model
   ↓
4. Domain Model (Book)
```

### Decision Framework

**When to Use Each Pattern:**

| Pattern | Use When | Example |
|---------|----------|---------|
| **Simple Entity** | No indexed properties, only query by PK/SK | Library, User Profile |
| **Complex Entity** | Properties queried independently (filters, sorts) | Book (filter by Title, IsAvailable) |
| **GSI Entity** | Alternate access patterns (query by non-key attribute) | Session (query by UserId via GSI) |
| **Library-Owned Entity** | Entity always belongs to library | Loan, Book, Invitation |

**When to Use Source Generator:**

| Scenario | Use Generator? | Why |
|----------|---------------|-----|
| **5+ indexed properties** | ✅ YES | Reduces boilerplate significantly |
| **Stable entity structure** | ✅ YES | Generator handles property changes |
| **Custom conversion logic** | ❌ NO | Write converter manually |
| **Simple entity (no indexed props)** | ❌ NO | Manual converter is 5 lines |
| **Complex computed keys** | ❌ NO | Need custom logic in FromDomain |

### Testing Pattern

**Test Converters Independently:**

```csharp
// test/LibraryService.Tests/Data/BookEntityConverterTests.cs
public class BookEntityConverterTests
{
    [Fact]
    public void ToAttributes_SerializesCorrectly()
    {
        // Arrange
        var book = CreateTestBook();
        var entity = BookEntity.FromDomain(book);

        // Act
        var attributes = BookEntityConverter.ToAttributes(entity);

        // Assert
        attributes["PK"].S.Should().Be("LIBRARY#test-library");
        attributes["SK"].S.Should().Be("BOOK#test-book");
        attributes["BookId"].S.Should().Be("test-book");
        attributes["Title"].S.Should().Be("Test Book");
        attributes["IsAvailable"].BOOL.Should().BeTrue();
        attributes["EntityType"].S.Should().Be("Book");
    }

    [Fact]
    public void FromAttributes_DeserializesCorrectly()
    {
        // Arrange
        var attributes = new Dictionary<string, AttributeValue>
        {
            ["PK"] = new AttributeValue { S = "LIBRARY#test-library" },
            ["SK"] = new AttributeValue { S = "BOOK#test-book" },
            ["BookId"] = new AttributeValue { S = "test-book" },
            ["Title"] = new AttributeValue { S = "Test Book" },
            ["IsAvailable"] = new AttributeValue { BOOL = true },
            ["EntityType"] = new AttributeValue { S = "Book" },
            ["Data"] = new AttributeValue { S = JsonSerializer.Serialize(CreateTestBook()) },
            ["CreatedAt"] = new AttributeValue { S = DateTime.UtcNow.ToString("O") },
            ["UpdatedAt"] = new AttributeValue { S = DateTime.UtcNow.ToString("O") }
        };

        // Act
        var entity = BookEntityConverter.FromAttributes(attributes);

        // Assert
        entity.PK.Should().Be("LIBRARY#test-library");
        entity.SK.Should().Be("BOOK#test-book");
        entity.BookId.Should().Be("test-book");
        entity.Title.Should().Be("Test Book");
        entity.IsAvailable.Should().BeTrue();
    }

    [Fact]
    public void RoundTrip_PreservesData()
    {
        // Arrange
        var book = CreateTestBook();
        var entity = BookEntity.FromDomain(book);

        // Act
        var attributes = BookEntityConverter.ToAttributes(entity);
        var roundTripEntity = BookEntityConverter.FromAttributes(attributes);
        var roundTripBook = roundTripEntity.ToDomain();

        // Assert
        roundTripBook.Should().BeEquivalentTo(book);
    }

    private Book CreateTestBook()
    {
        return new Book
        {
            Id = BookId.From("test-book"),
            LibraryId = LibraryId.From("test-library"),
            Title = "Test Book",
            IsAvailable = true,
            CreatedAt = DateTime.UtcNow,
            UpdatedAt = DateTime.UtcNow
        };
    }
}
```

### Complete Example

**Full Flow: API → Service → Repository → DynamoDB**

**1. API Endpoint:**

```csharp
// src/LibraryService/LibraryService.Api/Endpoints/Books/GetBookEndpoint.cs
public static class GetBookEndpoint
{
    public static void MapGetBook(this IEndpointRouteBuilder app)
    {
        app.MapGet("/api/books/{bookId}", async (
            string bookId,
            IBookService bookService,
            HttpContext context) =>
        {
            var libraryId = context.GetLibraryId();  // From middleware

            var book = await bookService.GetBookAsync(
                LibraryId.From(libraryId),
                BookId.From(bookId));

            return book != null
                ? Results.Ok(book)
                : Results.NotFound();
        })
        .RequireAuthorization();
    }
}
```

**2. Service Layer:**

```csharp
// src/LibraryService/LibraryService.Domain/Services/BookService.cs
public class BookService : IBookService
{
    private readonly IBookRepository _repository;

    public BookService(IBookRepository repository)
    {
        _repository = repository;
    }

    public async Task<Book?> GetBookAsync(LibraryId libraryId, BookId bookId)
    {
        var entity = await _repository.GetByIdAsync(libraryId.Value, bookId.Value);
        return entity?.ToDomain();  // Entity → Domain
    }

    public async Task SaveBookAsync(Book book)
    {
        var entity = BookEntity.FromDomain(book);  // Domain → Entity
        await _repository.SaveAsync(entity);
    }
}
```

**3. Repository Layer:**

```csharp
// src/LibraryService/Data/Repositories/BookRepository.cs
public class BookRepository : DynamoRepository<BookEntity>, IBookRepository
{
    public BookRepository(
        IAmazonDynamoDB client,
        IConfiguration config,
        ILogger<BookRepository> logger)
        : base(client, config["DynamoDb:TableName"]!, logger)
    {
    }

    public async Task<BookEntity?> GetByIdAsync(string libraryId, string bookId)
    {
        var pk = DynamoKeyHelpers.LibraryKey(libraryId);
        var sk = DynamoKeyHelpers.BookKey(bookId);

        return await GetItemAsync(pk, sk, BookEntityConverter.FromAttributes);
        // ↑ Converter: Attributes → Entity
    }

    public async Task SaveAsync(BookEntity book)
    {
        await PutItemAsync(book, BookEntityConverter.ToAttributes);
        // ↑ Converter: Entity → Attributes
    }
}
```

**4. DynamoDB Storage:**

```json
// DynamoDB Item Structure
{
  "PK": { "S": "LIBRARY#city-central" },
  "SK": { "S": "BOOK#book_abc123" },
  "EntityType": { "S": "Book" },
  "Data": { "S": "{\"Id\":\"book_abc123\",\"Title\":\"The Great Book\",\"LibraryId\":\"city-central\",\"IsAvailable\":true,\"CreatedAt\":\"2026-01-13T10:00:00Z\",\"UpdatedAt\":\"2026-01-13T10:00:00Z\"}" },
  "BookId": { "S": "book_abc123" },
  "Title": { "S": "The Great Book" },
  "LibraryId": { "S": "city-central" },
  "IsAvailable": { "BOOL": true },
  "CreatedAt": { "S": "2026-01-13T10:00:00Z" },
  "UpdatedAt": { "S": "2026-01-13T10:00:00Z" }
}
```

### Best Practices

**Entity Design:**
- ✅ Implement `IDynamoEntity` for all entities
- ✅ Use `ILibraryOwned` for library-scoped entities
- ✅ Store full domain model in `Data` field (JSON)
- ✅ Add indexed properties only for queryable fields
- ✅ Use `DynamoKeyHelpers` for consistent key generation

**Converter Implementation:**
- ✅ Use source generator (`[GenerateConverter]`) for entities with 5+ indexed properties
- ✅ Write manual converters for simple entities (only base fields)
- ✅ Use `DynamoEntityConverter.ToAttributesBase()` for base field conversion
- ✅ Use `AttributeHelpers` extension methods for type-safe attribute access
- ✅ Always handle null values gracefully

**FromDomain/ToDomain Methods:**
- ✅ `FromDomain`: Domain model → Entity (for persistence)
- ✅ `ToDomain`: Entity → Domain model (for retrieval)
- ✅ Serialize full domain model to `Data` field
- ✅ Populate indexed properties separately (for queries)
- ✅ Use consistent timestamp handling (ISO 8601 format)

**Repository Integration:**
- ✅ Extend `DynamoRepository<T>` base class
- ✅ Pass converters as function parameters to generic methods
- ✅ Use `DynamoKeyHelpers` methods for key construction
- ✅ Return entities from repository, convert to domain in service layer

**Testing:**
- ✅ Test converters independently (unit tests)
- ✅ Test round-trip conversion (ToAttributes → FromAttributes)
- ✅ Test FromDomain/ToDomain methods
- ✅ Mock repositories in service tests (use test entities)

**Anti-Patterns:**
- ❌ Don't bypass converters (use raw AttributeValue dictionaries directly)
- ❌ Don't duplicate conversion logic (centralize in converters)
- ❌ Don't hardcode key prefixes (use DynamoKeyHelpers)
- ❌ Don't forget to update `UpdatedAt` timestamp on mutations
- ❌ Don't store sensitive data unencrypted in `Data` field

---

## Best Practices Summary

**Key Design:**
- ✅ Use type prefixes (`USER#`, `LIBRARY#`, `BOOK#`, `LOAN#`)
- ✅ Design keys for access patterns, not domain models
- ✅ Include tenant/library/user scoping in partition keys
- ✅ Use GSIs for alternate access patterns

**Architecture:**
- ✅ Domain models separate from storage models
- ✅ Repository pattern for abstraction
- ✅ Mapping functions (FromDomain, ToDomain)
- ✅ No DynamoDB logic in application layer

**Cost Optimization:**
- ✅ On-demand billing by default
- ✅ Single-table design when possible
- ✅ Avoid RDS unless relational queries required
- ✅ Use sparse indexes (only index attributes you query)

**Portability:**
- ✅ Storage abstracted behind interfaces
- ✅ Infrastructure layer isolated
- ✅ Domain models framework-agnostic
- ✅ Easy to swap implementations

---
