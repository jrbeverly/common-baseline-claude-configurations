# Security Guidelines

**Status:** GUIDELINES - Preferred approaches, deviations allowed with justification

**Purpose:** Security patterns and practices for serverless applications built by a solo developer.

---

## Architectural Security First

**Principle:** Design security into the architecture rather than adding it as an afterthought.

**Why:**
- Cheaper to build secure than to retrofit security
- Reduces attack surface through design
- Serverless architectures provide built-in isolation
- AWS handles infrastructure security (shared responsibility model)

**Architectural Patterns:**

### 1. Isolation by Default

**Use AWS service boundaries for security:**

```
┌─────────────────────────────────────────┐
│ CloudFront (CDN)                        │
│ - DDoS protection (AWS Shield)          │
│ - HTTPS enforcement                     │
│ - Rate limiting                         │
└─────────────────────────────────────────┘
              ↓
┌─────────────────────────────────────────┐
│ API Gateway                             │
│ - JWT authorizer (Cognito)              │
│ - Request validation                    │
│ - Throttling per API key                │
└─────────────────────────────────────────┘
              ↓
┌─────────────────────────────────────────┐
│ Lambda (Isolated execution)             │
│ - IAM role per function                 │
│ - VPC isolation (if needed)             │
│ - No inbound connections                │
└─────────────────────────────────────────┘
              ↓
┌─────────────────────────────────────────┐
│ DynamoDB                                │
│ - IAM-only access                       │
│ - Encryption at rest (default)          │
│ - Partition key = tenant isolation      │
└─────────────────────────────────────────┘
```

**Example - API Gateway Authorizer:**

```yaml
# Terraform
resource "aws_api_gateway_authorizer" "cognito" {
  name          = "cognito-authorizer"
  rest_api_id   = aws_api_gateway_rest_api.api.id
  type          = "COGNITO_USER_POOLS"
  provider_arns = [aws_cognito_user_pool.users.arn]
}

resource "aws_api_gateway_method" "get_user" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.users.id
  http_method   = "GET"
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.cognito.id
}
```

### 2. Least Privilege IAM Roles

**Every Lambda function has its own IAM role with minimal permissions:**

```hcl
# modules/lambda-api/main.tf
resource "aws_iam_role" "lambda" {
  name = "${var.function_name}-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

# Only allow access to specific DynamoDB table
resource "aws_iam_role_policy" "dynamodb" {
  role = aws_iam_role.lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "dynamodb:GetItem",
        "dynamodb:PutItem",
        "dynamodb:Query"
      ]
      Resource = var.dynamodb_table_arn  # Specific table only
    }]
  })
}

# CloudWatch Logs (minimal)
resource "aws_iam_role_policy_attachment" "logs" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}
```

**❌ BAD: Overly broad permissions:**

```hcl
# Don't do this
resource "aws_iam_role_policy" "bad" {
  policy = jsonencode({
    Statement = [{
      Effect   = "Allow"
      Action   = "*"              # Too broad
      Resource = "*"              # Too broad
    }]
  })
}
```

### 3. Network Isolation

**Default: No VPC for Lambda (public internet access only):**

```hcl
# Lambda can access:
# ✅ DynamoDB (via IAM, no network access)
# ✅ S3 (via IAM)
# ✅ Public APIs (via internet)
# ❌ No inbound connections possible (serverless isolation)
```

**When VPC is required:**

```hcl
# Only if Lambda needs to access RDS, ElastiCache, or private resources
resource "aws_lambda_function" "api" {
  vpc_config {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = [aws_security_group.lambda.id]
  }
}

# Security group: Outbound only (no inbound)
resource "aws_security_group" "lambda" {
  name   = "${var.function_name}-sg"
  vpc_id = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # No ingress rules (Lambda doesn't accept inbound connections)
}
```

---

## Isolation Over Inline Security Logic

**Principle:** Use service boundaries and IAM for security, not code-level checks.

**Why:**
- AWS-enforced security is more reliable than application code
- Reduces attack surface (fewer lines of code to audit)
- Harder to bypass architectural security
- A solo developer doesn't need to be a security expert

**Example - Multi-Tenant Isolation:**

```typescript
// ✅ GOOD: Architectural isolation via partition keys
export async function getUserOrders(userId: string, tenantId: string) {
  const params = {
    TableName: 'app-table',
    KeyConditionExpression: 'PK = :pk AND begins_with(SK, :sk)',
    ExpressionAttributeValues: {
      ':pk': `TENANT#${tenantId}#USER#${userId}`,
      ':sk': 'ORDER#'
    }
  };

  return await dynamodb.query(params).promise();

  // No way to query other tenants - partition key enforces isolation
}

// ❌ BAD: Code-level filtering (can be bypassed)
export async function getUserOrders(userId: string, tenantId: string) {
  const params = {
    TableName: 'app-table',
    FilterExpression: 'tenantId = :tenantId',  // Filter, not isolation
    ExpressionAttributeValues: {
      ':tenantId': tenantId
    }
  };

  const result = await dynamodb.scan(params).promise();
  return result.Items.filter(item => item.userId === userId);

  // Bug or malicious code could remove filter
}
```

**Example - API Authorization:**

```csharp
// ✅ GOOD: API Gateway authorizer enforces JWT
// Lambda receives validated user claims
public static class GetUserEndpoint
{
    public static void MapGetUser(this IEndpointRouteBuilder app)
    {
        app.MapGet("/users/{id:guid}", HandleAsync)
            .RequireAuthorization();  // .NET enforces auth
    }

    private static async Task<IResult> HandleAsync(
        Guid id,
        HttpContext context,
        IUserService userService)
    {
        // User claims already validated by API Gateway + .NET
        var userId = context.User.FindFirst("sub")?.Value;

        // Only allow users to see their own data
        if (id.ToString() != userId)
            return Results.Forbid();

        var user = await userService.GetUserAsync(id);
        return user is null ? Results.NotFound() : Results.Ok(user);
    }
}

// ❌ BAD: Manual JWT validation in every endpoint
public static async Task<IResult> HandleAsync(string token)
{
    // Reinventing JWT validation (error-prone)
    var jwt = ParseJwt(token);
    if (!ValidateSignature(jwt)) return Results.Unauthorized();
    if (jwt.Expiry < DateTime.UtcNow) return Results.Unauthorized();
    // ...
}
```

---

## Deferred Hardening Model

**Principle:** Build a usable system first, harden incrementally as requirements emerge.

**Why:**
- Solo developer time is limited
- Premature security can block iteration
- Real threats emerge from real usage
- Can harden based on actual attack patterns

**Hardening Phases:**

### Phase 1: Architectural Security (Day 1)

**Must-haves for initial deployment:**

- ✅ HTTPS only (CloudFront enforces)
- ✅ IAM roles (least privilege by default)
- ✅ Secrets in Secrets Manager (never in code)
- ✅ DynamoDB partition key isolation
- ✅ API Gateway throttling (basic)
- ✅ CloudWatch logging enabled

**Terraform defaults:**

```hcl
# CloudFront: HTTPS only
resource "aws_cloudfront_distribution" "site" {
  viewer_certificate {
    cloudfront_default_certificate = false
    acm_certificate_arn            = var.acm_certificate_arn
    ssl_support_method             = "sni-only"
    minimum_protocol_version       = "TLSv1.2_2021"
  }

  default_cache_behavior {
    viewer_protocol_policy = "redirect-to-https"  # Force HTTPS
  }
}

# API Gateway: Basic throttling
resource "aws_api_gateway_method_settings" "all" {
  settings {
    throttling_burst_limit = 100   # Requests
    throttling_rate_limit  = 50    # Requests per second
  }
}
```

### Phase 2: Application Security (Month 1-3)

**Add as system matures:**

- ⚠️ Input validation (FluentValidation in C#)
- ⚠️ CORS policies (restrict origins)
- ⚠️ CSP headers (Content Security Policy)
- ⚠️ Rate limiting per user
- ⚠️ Audit logging for sensitive operations

**Example - Input Validation:**

```csharp
// Add when user input becomes a concern
public class CreateUserRequestValidator : AbstractValidator<CreateUserRequest>
{
    public CreateUserRequestValidator()
    {
        RuleFor(x => x.Email)
            .NotEmpty()
            .EmailAddress()
            .MaximumLength(254);  // RFC 5321

        RuleFor(x => x.Name)
            .NotEmpty()
            .MaximumLength(100)
            .Matches("^[a-zA-Z0-9 ]+$");  // Alphanumeric + spaces only
    }
}
```

### Phase 3: Compliance & Hardening (Month 6+)

**Add when required by users, data sensitivity, or scale:**

- 🔒 SOC 2 compliance preparation
- 🔒 Encryption in transit (TLS 1.3)
- 🔒 Encryption at rest (KMS keys)
- 🔒 Audit trail (CloudTrail)
- 🔒 Penetration testing
- 🔒 WAF rules (AWS WAF)

**Don't Over-Engineer Early:**

```markdown
❌ BAD: Day 1 requirements
- SOC 2 compliance
- Penetration testing
- Custom encryption
- Complex RBAC
- Intrusion detection

✅ GOOD: Incremental approach
Month 1: HTTPS, IAM, secrets management
Month 3: Input validation, CORS, CSP
Month 6: Audit logging, rate limiting
Year 1: Formal compliance, pen testing (if a concrete requirement emerges)
```

---

## Explicit Trust Boundaries

**Principle:** Define where you trust data and where you don't.

**Trust Boundaries:**

```
┌─────────────────────────────────────────┐
│ UNTRUSTED                               │
│ - User input (API requests)             │
│ - Third-party APIs                      │
│ - Frontend (JavaScript can be modified) │
└─────────────────────────────────────────┘
              ↓ VALIDATE HERE
┌─────────────────────────────────────────┐
│ TRUSTED                                 │
│ - API Gateway (validated requests)      │
│ - Lambda (after auth + validation)      │
│ - DynamoDB (IAM-protected)              │
│ - Internal services                     │
└─────────────────────────────────────────┘
```

**Validation at Boundaries:**

```csharp
// API Endpoint (trust boundary)
public static class CreateUserEndpoint
{
    public static void MapCreateUser(this IEndpointRouteBuilder app)
    {
        app.MapPost("/users", HandleAsync)
            .RequireAuthorization();
    }

    private static async Task<IResult> HandleAsync(
        CreateUserRequest request,
        IValidator<CreateUserRequest> validator,
        IUserService userService)
    {
        // TRUST BOUNDARY: Validate untrusted input
        var validationResult = await validator.ValidateAsync(request);
        if (!validationResult.IsValid)
        {
            return Results.BadRequest(validationResult.Errors);
        }

        // Now input is trusted, pass to domain
        var email = Email.Create(request.Email);  // Domain validation
        var user = User.Create(email, request.Name, systemClock);

        await userService.CreateUserAsync(user);

        return Results.Created($"/users/{user.Id}", user);
    }
}

// Domain Service (trusted zone)
public class UserService : IUserService
{
    public async Task CreateUserAsync(User user)
    {
        // No validation here - user is already validated
        // This is the trusted zone
        await _repository.SaveAsync(user);
    }
}
```

**Don't Trust Frontend:**

```typescript
// ❌ BAD: Frontend determines permissions
<template>
  <v-btn v-if="isAdmin" @click="deleteUser">Delete</v-btn>
</template>

// Client can modify JavaScript to show button
// Backend MUST check permissions

// ✅ GOOD: Backend enforces permissions
// Frontend can hide button for UX, but backend validates
<template>
  <v-btn v-if="canDelete" @click="deleteUser">Delete</v-btn>
</template>

// Backend
public static async Task<IResult> DeleteUser(Guid id, HttpContext context)
{
    var userId = context.User.FindFirst("sub")?.Value;

    // Always check permissions on backend
    if (!await _permissionService.CanDeleteUser(userId, id))
        return Results.Forbid();

    await _userService.DeleteAsync(id);
    return Results.NoContent();
}
```

---

## Avoid Premature Security Complexity

**Principle:** Don't add security features you don't need yet.

**Examples of Premature Security:**

### ❌ Complex RBAC (Role-Based Access Control)

**Don't build on Day 1:**

```csharp
// ❌ PREMATURE: Complex role system with 20 permissions
public enum Permission
{
    UserRead, UserWrite, UserDelete,
    OrgRead, OrgWrite, OrgDelete,
    ProjectRead, ProjectWrite, ProjectDelete,
    // ... 20 more permissions
}

public class RoleService
{
    public async Task<bool> HasPermission(string userId, Permission permission) { }
    public async Task AssignRole(string userId, string roleId) { }
    public async Task CreateCustomRole(string name, Permission[] permissions) { }
}
```

**Start simple:**

```csharp
// ✅ SIMPLE: Owner can do everything, others can read
public static async Task<IResult> DeleteUser(Guid id, HttpContext context)
{
    var requesterId = context.User.FindFirst("sub")?.Value;
    var user = await _userService.GetUserAsync(id);

    // Simple rule: Only user can delete themselves, or org owner
    if (user.Id.ToString() != requesterId && !await _libraryService.IsOwner(requesterId, user.LibraryId))
        return Results.Forbid();

    await _userService.DeleteAsync(id);
    return Results.NoContent();
}

// Add RBAC later when needed (Month 6+)
```

### ❌ Custom Encryption

**Don't build on Day 1:**

```csharp
// ❌ PREMATURE: Custom encryption for every field
public class EncryptedUser
{
    public string EncryptedEmail { get; set; }
    public string EncryptedName { get; set; }
    public string EncryptedPhone { get; set; }
}
```

**Use AWS defaults:**

```csharp
// ✅ SIMPLE: DynamoDB encryption at rest (enabled by default)
// ✅ SIMPLE: HTTPS encryption in transit (CloudFront enforces)
// ✅ SIMPLE: Secrets Manager for API keys

// Add field-level encryption later if compliance requires (Year 1+)
```

### ❌ Complex Audit Logging

**Don't build on Day 1:**

```csharp
// ❌ PREMATURE: Log every field change with before/after
public class AuditLog
{
    public string Action { get; set; }
    public string UserId { get; set; }
    public Dictionary<string, object> BeforeState { get; set; }
    public Dictionary<string, object> AfterState { get; set; }
    public DateTime Timestamp { get; set; }
}
```

**Start simple:**

```csharp
// ✅ SIMPLE: Log important actions only
_logger.LogInformation("User {UserId} deleted user {TargetUserId}", requesterId, id);

// Add detailed audit trail later when compliance requires (Year 1+)
```

---

## Harden After Correctness

**Principle:** Get the system working correctly first, then add security layers.

**Process:**

1. **Build core functionality** (Month 1)
   - Focus on business logic
   - Basic architectural security (HTTPS, IAM, secrets)
   - Make it work

2. **Add validation and error handling** (Month 2-3)
   - Input validation at API boundaries
   - Proper error responses (don't leak stack traces)
   - Rate limiting

3. **Security review** (Month 6)
   - Review code for common vulnerabilities (OWASP Top 10)
   - Add WAF rules
   - Pen testing (if budget allows)

4. **Compliance preparation** (Year 1+)
   - Formal compliance (e.g. SOC 2) only if a concrete requirement emerges
   - GDPR compliance
   - Industry-specific requirements

**Example Evolution:**

```csharp
// Month 1: Basic endpoint
app.MapPost("/users", async (CreateUserRequest req, IUserService svc) =>
{
    var user = await svc.CreateUserAsync(req);
    return Results.Created($"/users/{user.Id}", user);
});

// Month 2: Add validation
app.MapPost("/users", async (CreateUserRequest req, IValidator<CreateUserRequest> validator, IUserService svc) =>
{
    var validationResult = await validator.ValidateAsync(req);
    if (!validationResult.IsValid)
        return Results.BadRequest(validationResult.Errors);

    var user = await svc.CreateUserAsync(req);
    return Results.Created($"/users/{user.Id}", user);
});

// Month 6: Add rate limiting
app.MapPost("/users", async (HttpContext ctx, CreateUserRequest req, IValidator<CreateUserRequest> validator, IUserService svc, IRateLimiter limiter) =>
{
    // Check rate limit
    if (!await limiter.AllowRequest(ctx.User.FindFirst("sub")?.Value))
        return Results.StatusCode(429);  // Too Many Requests

    // Validate
    var validationResult = await validator.ValidateAsync(req);
    if (!validationResult.IsValid)
        return Results.BadRequest(validationResult.Errors);

    // Create
    var user = await svc.CreateUserAsync(req);
    return Results.Created($"/users/{user.Id}", user);
});
```

---

## Security Checklist (by Phase)

### Phase 1: Launch (Day 1)

**Must-Have:**
- [ ] HTTPS enforced (CloudFront)
- [ ] IAM roles with least privilege
- [ ] Secrets in AWS Secrets Manager
- [ ] API Gateway throttling enabled
- [ ] CloudWatch logging enabled
- [ ] DynamoDB encryption at rest (default)
- [ ] No hardcoded credentials in code

### Phase 2: Production (Month 1-3)

**Should-Have:**
- [ ] Input validation (FluentValidation)
- [ ] CORS policies configured
- [ ] CSP headers in responses
- [ ] Error handling doesn't leak stack traces
- [ ] Rate limiting per user
- [ ] Audit logging for sensitive operations

### Phase 3: Scale (Month 6+)

**Nice-to-Have:**
- [ ] WAF rules (SQL injection, XSS)
- [ ] Penetration testing
- [ ] Security headers (HSTS, X-Frame-Options)
- [ ] Dependency scanning (Snyk, Dependabot)
- [ ] Incident response plan

### Phase 4: Compliance (Year 1+)

**When Required:**
- [ ] SOC 2 compliance
- [ ] GDPR compliance
- [ ] PCI DSS (if handling payments)
- [ ] HIPAA (if handling health data)
- [ ] Regular security audits

---

## Common Vulnerabilities to Avoid

### 1. Injection Attacks

**DynamoDB is immune to SQL injection, but still validate:**

```csharp
// ✅ GOOD: Parameterized query (DynamoDB)
var params = new QueryRequest
{
    TableName = "app-table",
    KeyConditionExpression = "PK = :pk",
    ExpressionAttributeValues = new Dictionary<string, AttributeValue>
    {
        [":pk"] = new AttributeValue { S = $"USER#{userId}" }
    }
};

// ❌ BAD: String concatenation (if using raw SQL)
var query = $"SELECT * FROM users WHERE id = '{userId}'";  // SQL injection risk
```

### 2. XSS (Cross-Site Scripting)

**Vue.js escapes by default, but be careful:**

```vue
<!-- ✅ GOOD: Vue escapes automatically -->
<template>
  <p>{{ user.name }}</p>  <!-- Safe -->
</template>

<!-- ❌ BAD: Raw HTML -->
<template>
  <p v-html="user.bio"></p>  <!-- XSS risk if bio contains <script> -->
</template>

<!-- ✅ GOOD: Sanitize HTML -->
<script setup lang="ts">
import DOMPurify from 'dompurify'

const sanitizedBio = computed(() => DOMPurify.sanitize(user.value.bio))
</script>

<template>
  <p v-html="sanitizedBio"></p>
</template>
```

### 3. Broken Authentication

**Use AWS Cognito, don't roll your own:**

```typescript
// ✅ GOOD: Use Cognito
import { CognitoIdentityProviderClient, InitiateAuthCommand } from '@aws-sdk/client-cognito-identity-provider'

// ❌ BAD: Custom JWT implementation
function createJWT(userId: string) {
  // Don't implement your own JWT signing/validation
}
```

### 4. Sensitive Data Exposure

**Never log sensitive data:**

```csharp
// ❌ BAD: Logging passwords, tokens, credit cards
_logger.LogInformation("User login: {Email} {Password}", email, password);

// ✅ GOOD: Log user ID only
_logger.LogInformation("User {UserId} logged in", userId);
```

---

## Summary

**Security Philosophy:**

1. **Architectural Security First** - Use AWS service boundaries
2. **Isolation Over Code** - IAM, partition keys, network isolation
3. **Deferred Hardening** - Build usable first, harden incrementally
4. **Explicit Trust Boundaries** - Validate untrusted input
5. **Avoid Premature Complexity** - Don't build RBAC on Day 1
6. **Harden After Correctness** - Get it working, then secure

**Security by Phase:**

| Phase | Focus | Timeline |
|-------|-------|----------|
| **Phase 1** | Architectural (HTTPS, IAM, secrets) | Day 1 |
| **Phase 2** | Application (validation, CORS, CSP) | Month 1-3 |
| **Phase 3** | Hardening (WAF, pen testing) | Month 6+ |
| **Phase 4** | Compliance (SOC 2, GDPR) | Year 1+ |

---

*These are guidelines. Solo developer security is pragmatic, not paranoid.*
