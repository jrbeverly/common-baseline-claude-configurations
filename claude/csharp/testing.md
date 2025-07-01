# C# Testing Strategy

**Status:** GUIDELINES - Preferred testing patterns

**Purpose:** Build confidence through focused, deterministic tests.

---

## Principles

**Confidence Over Coverage:** Business logic → 100%, API endpoints → Critical paths, Data access → Happy path + errors

**Data-Driven Over Duplication:** Use `[Theory]` and test data sources instead of repeating test logic across multiple `[Fact]` methods.

---

## Testing Stack

**xUnit**, **FluentAssertions**, **Moq**, **Testcontainers**

---

## Data-Driven Tests

**Avoid excessive individual test cases.** Use xUnit's `[Theory]` with data attributes to enumerate test inputs.

**❌ Bad (Repetitive):**
```csharp
[Fact]
public void ValidateEmail_WithEmpty_ReturnsFalse()
{
    var result = EmailValidator.Validate("");
    result.Should().BeFalse();
}

[Fact]
public void ValidateEmail_WithNull_ReturnsFalse()
{
    var result = EmailValidator.Validate(null);
    result.Should().BeFalse();
}

[Fact]
public void ValidateEmail_WithNoAtSign_ReturnsFalse()
{
    var result = EmailValidator.Validate("invalid");
    result.Should().BeFalse();
}

[Fact]
public void ValidateEmail_WithNoDomain_ReturnsFalse()
{
    var result = EmailValidator.Validate("test@");
    result.Should().BeFalse();
}
```

**✅ Good (Data-Driven):**
```csharp
[Theory]
[InlineData("")]
[InlineData(null)]
[InlineData("invalid")]
[InlineData("test@")]
[InlineData("@example.com")]
[InlineData("test@.com")]
public void ValidateEmail_WithInvalid_ReturnsFalse(string email)
{
    var result = EmailValidator.Validate(email);
    result.Should().BeFalse();
}

[Theory]
[InlineData("test@example.com")]
[InlineData("user+tag@domain.co.uk")]
[InlineData("first.last@example.com")]
public void ValidateEmail_WithValid_ReturnsTrue(string email)
{
    var result = EmailValidator.Validate(email);
    result.Should().BeTrue();
}
```

### Complex Test Data

For complex scenarios, use `[MemberData]` or `[ClassData]`:

```csharp
public static IEnumerable<object[]> InvalidUserData =>
    new List<object[]>
    {
        new object[] { "", "Test User", "Email is required" },
        new object[] { "invalid", "Test User", "Email must be valid" },
        new object[] { "test@example.com", "", "Name is required" },
        new object[] { "test@example.com", "A", "Name must be at least 2 characters" }
    };

[Theory]
[MemberData(nameof(InvalidUserData))]
public void CreateUser_WithInvalidData_ReturnsExpectedError(
    string email,
    string name,
    string expectedError)
{
    var result = User.Create(email, name);

    result.IsFailure.Should().BeTrue();
    result.Error.Message.Should().Be(expectedError);
}
```

### ClassData for Reusable Test Sets

```csharp
public class InvalidEmailTestData : IEnumerable<object[]>
{
    public IEnumerator<object[]> GetEnumerator()
    {
        yield return new object[] { "" };
        yield return new object[] { null };
        yield return new object[] { "invalid" };
        yield return new object[] { "test@" };
        yield return new object[] { "@example.com" };
    }

    IEnumerator IEnumerable.GetEnumerator() => GetEnumerator();
}

[Theory]
[ClassData(typeof(InvalidEmailTestData))]
public void ValidateEmail_WithInvalid_ReturnsFalse(string email)
{
    var result = EmailValidator.Validate(email);
    result.Should().BeFalse();
}
```

**Benefits:**
- ✅ Single source of truth for test logic
- ✅ Easy to add new test cases (just add data)
- ✅ Reduced maintenance overhead
- ✅ Clear separation of test logic from test data
- ✅ Test failures show which specific input failed

---

## Domain Tests

No mocks. Pure logic.

```csharp
[Fact]
public void Deactivate_SetsIsActiveFalse()
{
    var user = User.Create(Email.Create("test@example.com").Value, "Test");
    user.Deactivate();
    user.IsActive.Should().BeFalse();
}

[Fact]
public void Deactivate_WhenInactive_Throws()
{
    var user = User.Create(Email.Create("test@example.com").Value, "Test");
    user.Deactivate();
    user.Invoking(u => u.Deactivate()).Should().Throw<InvalidOperationException>();
}
```

```csharp
[Fact]
public void Email_Create_WithValid_ReturnsSuccess()
{
    var result = Email.Create("test@example.com");
    result.IsSuccess.Should().BeTrue();
}

[Theory]
[InlineData("")][InlineData(null)]
public void Email_Create_WithEmpty_ReturnsFailure(string email)
{
    var result = Email.Create(email);
    result.IsFailure.Should().BeTrue();
    result.Error.Code.Should().Be("EMAIL_EMPTY");
}
```

---

## Application Tests

Use fakes.

```csharp
public class FakeUserRepository : IUserRepository
{
    private readonly List<User> _users = new();
    public Task SaveAsync(User user) { _users.Add(user); return Task.CompletedTask; }
    public Task<User?> GetByIdAsync(Guid id) => Task.FromResult(_users.FirstOrDefault(u => u.Id == id));
}
```

```csharp
[Fact]
public async Task HandleAsync_WithValid_CreatesUser()
{
    var repo = new FakeUserRepository();
    var handler = new CreateUserCommandHandler(repo);
    var result = await handler.HandleAsync(new("test@example.com", "Test"));

    result.IsSuccess.Should().BeTrue();
    var user = await repo.GetByIdAsync(result.Value);
    user.Should().NotBeNull();
}

[Fact]
public async Task HandleAsync_WithInvalid_ReturnsFailure()
{
    var repo = new FakeUserRepository();
    var handler = new CreateUserCommandHandler(repo);
    var result = await handler.HandleAsync(new("invalid", "Test"));

    result.IsFailure.Should().BeTrue();
}
```

---

## Deterministic Time

```csharp
public interface IClock { DateTime UtcNow { get; } }
public class SystemClock : IClock { public DateTime UtcNow => DateTime.UtcNow; }
public class FakeClock : IClock { public DateTime UtcNow { get; set; } }
```

---

## Infrastructure Tests

```csharp
public class UserRepositoryTests : IAsyncLifetime
{
    private PostgreSqlContainer _container;
    private UserRepository _repository;

    public async Task InitializeAsync()
    {
        _container = new PostgreSqlBuilder().Build();
        await _container.StartAsync();
        var context = new ApplicationDbContext(
            new DbContextOptionsBuilder<ApplicationDbContext>()
                .UseNpgsql(_container.GetConnectionString()).Options);
        await context.Database.EnsureCreatedAsync();
        _repository = new UserRepository(context);
    }

    public async Task DisposeAsync() => await _container.DisposeAsync();

    [Fact]
    public async Task SaveAsync_PersistsUser()
    {
        var user = User.Create(Email.Create("test@example.com").Value, "Test");
        await _repository.SaveAsync(user);
        var retrieved = await _repository.GetByIdAsync(user.Id);
        retrieved.Should().NotBeNull();
    }
}
```

---

## API Tests

```csharp
public class UserEndpointsTests : IClassFixture<WebApplicationFactory<Program>>
{
    private readonly WebApplicationFactory<Program> _factory;
    public UserEndpointsTests(WebApplicationFactory<Program> factory) => _factory = factory;

    [Fact]
    public async Task CreateUser_WithValid_Returns201()
    {
        var client = _factory.CreateClient();
        var response = await client.PostAsJsonAsync("/users", new CreateUserCommand("test@example.com", "Test"));
        response.StatusCode.Should().Be(HttpStatusCode.Created);
    }
}
```

---

## Mocking ILogger

```csharp
var logger = NullLogger<UserService>.Instance;
```

---

## Related Documentation

- **[minimal-api.md](minimal-api.md)** - Testing endpoints
- **[domain-modeling.md](domain-modeling.md)** - Testable domain models
- **[error-modeling.md](error-modeling.md)** - Testing Result types
