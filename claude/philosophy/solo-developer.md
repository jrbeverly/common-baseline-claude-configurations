# Solo Developer Operating Model

**Status:** PHILOSOPHY - Operating principles and mindset

**Purpose:** Define the constraints, expectations, and design philosophy for development by a single developer.

---

## Core Philosophy

This repository and its patterns are optimized for a **solo developer**: one person building and running systems without an infrastructure or operations team behind them.

**Key Constraint:** All systems must be sustainable for one person to build, operate, and maintain over years, with long pauses between work sessions.

---

## Single-Developer Constraints

### No On-Call Expectations

**Principle:** Systems must not require immediate human intervention.

**Design Implications:**
- **Prefer asynchronous operations** - Don't build systems that break if you're unavailable for hours/days
- **Graceful degradation** - Failures should self-heal or wait, not cascade
- **Alerting philosophy** - Alerts are informational, not urgent (no 3am pages)
- **Scheduled maintenance windows** - Updates happen on your schedule, not crisis-driven

**Example Architecture:**
```
✅ GOOD: S3 + CloudFront + Lambda
   - No servers to crash at 2am
   - AWS handles availability
   - Failures retry automatically

❌ BAD: Self-hosted server requiring manual restarts
   - If it goes down at night, it stays down until you notice
   - Requires immediate attention
```

**Anti-Patterns:**
- Systems with manual restart procedures
- Databases without automatic backups/failover  
- Critical batch jobs without retry logic
- Real-time monitoring that demands immediate action

**Acceptable:**
- Delayed processing (queues, eventual consistency)
- Automated incident response
- Self-healing systems
- Degraded service over outage

### Minimal Operational Burden

**Principle:** Operations must be simple enough to understand and execute months after initial setup.

**Design Implications:**
- **Infrastructure as code** - Every change must be reproducible
- **Automation over documentation** - Scripts execute, docs go stale
- **Serverless-first** - No servers to patch, update, monitor
- **Managed services** - Let AWS handle undifferentiated heavy lifting
- **Boring technology** - Proven patterns over novel approaches

**Operational Complexity Budget:**

| Activity | Acceptable Frequency | Example |
|----------|---------------------|---------|
| Deploy application code | Daily | `terraform apply`, `git push` triggers deploy |
| Review logs/metrics | Weekly | CloudWatch dashboards, anomaly alerts |
| Update dependencies | Monthly | Dependabot PRs, automated security patches |
| Infrastructure changes | Quarterly | New features, cost optimization |
| Major refactoring | Annually | Technology upgrades, architectural shifts |

**Anti-Patterns:**
- Daily manual database maintenance
- Frequent server patching/rebooting
- Complex multi-step deployment processes
- Systems requiring constant tuning

**Acceptable:**
- Weekly review of automated health checks
- Monthly dependency updates (automated PRs)
- Quarterly infrastructure cost review
- Annual architectural assessment

### Systems Must Be Understandable Months Later

**Principle:** You should be able to return to code/infrastructure after 6-12 months and understand what's happening without extensive re-learning.

**Design Implications:**
- **Self-documenting code** - Clear names, obvious structure
- **Explicit > Clever** - Predictable patterns over optimization
- **Documentation as architecture** - Decisions documented with rationale
- **Minimal abstractions** - Only abstract when pattern repeats 3+ times
- **Linear flow** - Avoid deep call stacks, complex state machines

**Example - Self-Documenting:**
```csharp
// ✅ GOOD: Clear, obvious
public static class GetUserEndpoint
{
    public static void MapGetUser(this IEndpointRouteBuilder app)
    {
        app.MapGet("/users/{id}", HandleAsync);
    }
    
    private static async Task<Results<Ok<UserResponse>, NotFound>> HandleAsync(
        Guid id, IUserService userService)
    {
        var user = await userService.GetUserAsync(id);
        return user is null ? TypedResults.NotFound() : TypedResults.Ok(...);
    }
}

// ❌ BAD: Clever, hard to remember
public class UserModule : BaseModule<UserEntity>
{
    protected override void Configure() => 
        Get<GetCommand>().RequiresAuth().CachesFor(60);
}
```

**Documentation Requirements:**
- Every non-obvious decision has a comment explaining "why"
- Architecture decisions recorded in docs/architecture.md or CODEMAP.md
- .claude/guidelines/ capture high-level patterns
- README in each directory explains purpose

---

## Incremental Hardening Mindset

### Build Usable Systems First

**Principle:** Get to working software fast, then harden over time.

**Stages:**

**1. Make it Work (Days 1-30)**
- Minimal viable feature
- No auth (start with open APIs)
- No scaling (design for 10 users)
- Manual deployment OK
- Inline secrets acceptable (environment variables)

**2. Make it Reliable (Months 1-3)**
- Add authentication
- Add basic error handling
- Automated deployments
- Secrets in AWS Secrets Manager
- Basic monitoring (CloudWatch)

**3. Make it Scalable (Months 3-6)**
- Handle 100-1000 users
- Optimize costs
- Improve performance
- Add comprehensive tests
- CI/CD pipeline

**4. Make it Robust (Months 6-12)**
- Handle 1000+ users
- Advanced monitoring
- Disaster recovery
- Security hardening
- Compliance if needed

**Anti-Pattern:** Trying to build stage 4 on day 1.

### Harden, Optimize, and Refine Over Time

**Principle:** Each iteration adds one layer of robustness, not all at once.

**Iteration Examples:**

**Iteration 1: Basic API**
```csharp
app.MapGet("/users/{id}", async (Guid id, IUserService svc) => 
    await svc.GetUserAsync(id));
```

**Iteration 2: Add Error Handling**
```csharp
app.MapGet("/users/{id}", async (Guid id, IUserService svc) =>
{
    var user = await svc.GetUserAsync(id);
    return user is null ? Results.NotFound() : Results.Ok(user);
});
```

**Iteration 3: Add Auth + Logging**
```csharp
app.MapGet("/users/{id}", async (Guid id, IUserService svc, ILogger log) =>
{
    log.LogInformation("Getting user {Id}", id);
    var user = await svc.GetUserAsync(id);
    return user is null ? Results.NotFound() : Results.Ok(user);
}).RequireAuthorization();
```

**Each step is deployable and delivers value.**

### Avoid "Perfect on Day One" Pressure

**Anti-Patterns:**
- ❌ Complex authentication before any features work
- ❌ Advanced caching before traffic exists
- ❌ Premature microservices (start with modular monolith)
- ❌ Over-engineered abstractions
- ❌ Comprehensive monitoring before basic functionality

**Acceptable Trade-Offs Early On:**
- Start with AWS console manual setup (codify later with Terraform)
- Inline configuration (extract to environment variables later)
- Single-region deployment (add multi-region when needed)
- Basic tests (expand coverage as features stabilize)

---

## Robustness as an Outcome, Not a Starting State

### Predictability Over Cleverness

**Principle:** Boring, obvious code is better than clever, optimized code.

**Why:**
- You'll forget clever optimizations in 6 months
- Predictable code is debuggable at 2am
- AI assistants understand obvious patterns better
- Simple patterns compose reliably

**Examples:**

**✅ Predictable:**
```csharp
if (user is null) return Results.NotFound();
if (!user.IsActive) return Results.Forbidden();
return Results.Ok(user);
```

**❌ Clever:**
```csharp
return user switch
{
    null => Results.NotFound(),
    { IsActive: false } => Results.Forbidden(),
    _ => Results.Ok(user)
};
```

*(Switch is fine for true branching logic, overkill for sequential checks)*

### Boring Systems That Age Well

**Prefer:**
- **REST over GraphQL** - Simpler, more tooling
- **PostgreSQL/DynamoDB over custom data stores** - Well-understood
- **Lambda over Kubernetes** - Less operational complexity
- **Terraform over custom provisioning** - Industry standard
- **Composition API over Options API** - Modern Vue.js standard

**Avoid:**
- Novel frameworks/libraries with < 1000 GitHub stars
- Bleeding-edge technology without LTS
- Custom solutions when managed services exist
- Frameworks that require constant re-learning

**Technology Selection Criteria:**
1. Will this exist in 5 years?
2. Can I find help/docs easily?
3. Can I replace it incrementally if needed?
4. Does it reduce operational burden?

---

## Cost as a First-Class Constraint

### Zero-Cost-When-Idle Preference

**Principle:** Infrastructure should cost $0 (or near-zero) when not in use.

**Architecture:**
- **Lambda** - Pay per invocation ($0 at 0 requests)
- **DynamoDB on-demand** - Pay per request ($0.25/million reads)
- **S3** - Pay per GB stored ($0.023/GB/month)
- **CloudFront** - Pay per transfer ($0.085/GB)

**Avoid:**
- **RDS** - ~$15-50/month even at 0 traffic
- **EC2** - ~$5-100/month running 24/7
- **NAT Gateway** - ~$30/month + transfer
- **Provisioned DynamoDB** - Fixed hourly cost

**Cost Monitoring:**
- Set AWS budget alerts ($10, $50, $100 thresholds)
- Review costs monthly (first Friday of month)
- Optimize when monthly cost > $50

### Fixed Monthly Costs Avoided by Default

**Acceptable Fixed Costs:**
- Domain names (~$12/year)
- Route53 hosted zones ($0.50/month per zone)
- Terraform state S3 buckets (~$0.023/month)
- Minimal CloudWatch logs retention (~$0.50/month)

**Avoid Unless Justified:**
- RDS instances
- Always-on EC2/Fargate
- Reserved capacity (unless sustained usage proven)
- Third-party SaaS with monthly minimums

### Pay-Per-Use Preferred

**Decision Framework:**

| Service Need | Pay-Per-Use Option | Always-On Alternative | Choose Pay-Per-Use When |
|--------------|-------------------|----------------------|------------------------|
| Compute | Lambda | EC2/Fargate | < 1M requests/month |
| Database | DynamoDB on-demand | RDS | < 10GB data, simple queries |
| Storage | S3 | EBS volumes | Any file storage need |
| CDN | CloudFront | Self-hosted | Any static asset delivery |
| Queue | SQS | Self-hosted RabbitMQ | Any async processing |

---

## Pause-and-Resume Friendly Design

### Long Gaps Between Work Sessions Expected

**Principle:** You may not touch this codebase for 3-6 months. It must be easy to resume.

**Design Implications:**

**1. Comprehensive README Files:**
Every directory has README.md:
- What is this?
- How do I run it locally?
- How do I deploy it?
- Where are the docs?

**2. Self-Contained Documentation:**
- CODEMAP.md has repository structure and tech stack
- .claude/guidelines/ has all technology patterns
- .claude/ has all AI context
- No reliance on external wikis/Notion

**3. Automated Environments:**
- DevContainer builds everything (`devcontainer.json`)
- One command to run locally (`make dev`)
- One command to deploy (`make deploy-prod`)
- No manual configuration required

**4. Clear Entry Points:**
Start here when returning:
1. Read README.md (2 min)
2. Read .claude/CLAUDE.md (5 min)
3. Read CODEMAP.md for repository specifics (5 min)
4. Run `make dev` (start local environment)
5. Reference .claude/guidelines/ for deep dives

### Design Decisions Must Be Rediscoverable

**Principle:** Don't rely on memory. Document everything.

**Required Documentation:**

**For Architecture Decisions:**
```markdown
## Decision: Use DynamoDB Single-Table Design

**Context:** Need database for user data, low traffic expected.

**Decision:** Use DynamoDB with single-table design.

**Rationale:**
- Zero cost when idle
- Scales automatically
- No server management
- Fits access patterns (get user by ID, list by org)

**Trade-Offs:**
- Less flexible than relational DB
- Requires access-pattern-first design
- Query complexity limited

**Alternatives Considered:**
- RDS PostgreSQL: Rejected due to $15/month minimum cost
- Multiple DynamoDB tables: Rejected due to cost ($/table/month)

**Date:** 2026-01-11
```

**For Code Patterns:**
- Why this pattern? (comment in code)
- Example usage (in README or doc)
- When to deviate (in guidelines)

**For Infrastructure:**
- Why this configuration? (Terraform comments)
- Cost implications (in terraform.md)
- How to change (in README)

---

## Summary Checklist

When designing or reviewing systems, ask:

**Single-Developer Constraints:**
- [ ] Can this run without me for 48 hours?
- [ ] Is operational burden < 2 hours/week?
- [ ] Will I understand this in 6 months?

**Incremental Hardening:**
- [ ] Is this minimal version usable?
- [ ] What's the next hardening step?
- [ ] Am I adding complexity too early?

**Robustness:**
- [ ] Is this the boring, obvious solution?
- [ ] Will this still work in 2 years?
- [ ] Can I debug this half-asleep?

**Cost:**
- [ ] Does this cost $0 when idle?
- [ ] Have I justified any fixed costs?
- [ ] Is there a cheaper pay-per-use option?

**Pause-and-Resume:**
- [ ] Is there a README explaining this?
- [ ] Can I resume work without research?
- [ ] Are decisions documented with rationale?

---

*This philosophy document guides all other decisions in this repository. When in doubt, optimize for what one developer can sustain.*
