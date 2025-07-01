# LLM Governance Rules

**Status:** RULES - Invariant, must be followed

**Purpose:** Define how Claude Code and other LLM assistants should interact with this repository.

---

## .claude/ as Source of Truth

**Rule:** The `.claude/` directory is the authoritative source for AI-assisted development guidance.

**Implications:**
- ✅ Claude Code automatically loads `.claude/CLAUDE.md` at session start
- ✅ All AI assistants must respect `.claude/` documentation
- ✅ When conflicts arise, `.claude/` overrides general LLM knowledge
- ✅ Repository-specific patterns take precedence over generic best practices

**Example:**

```
User: "Create a new API endpoint for users"

Claude: [Reads .claude/guidelines/csharp.md]
        [Follows Minimal API pattern from documentation]
        [Uses service-scoped directory structure from constraints/]
        [Creates: src/LibraryService/LibraryService.Api/Endpoints/Users/CreateUserEndpoint.cs]
```

**What "Source of Truth" Means:**
- If `.claude/guidelines/csharp.md` says "Use Minimal API", don't use Controllers
- If `.claude/constraints/repository-structure.md` says "No top-level source files", enforce it
- If `.claude/preferences/technology-choices.md` says "C# for backend", don't suggest Python

---

## Read-Only by Default

**Rule:** The `.claude/` directory is read-only for AI assistants unless explicitly requested by the user.

**Rationale:**
- Documentation should be stable and intentional
- Changes to guidance affect all future sessions
- User should control documentation evolution

**When to Modify `.claude/`:**
- ✅ User explicitly requests: "Update .claude/guidelines/csharp.md to include..."
- ✅ User asks: "Document this pattern in .claude/"
- ✅ User says: "Add this to the guidelines"

**When NOT to Modify `.claude/`:**
- ❌ You notice a pattern while working on code
- ❌ You think guidance is outdated
- ❌ You want to improve documentation proactively
- ❌ User asks you to "remember this for next time" (use project-specific docs instead)

**If You Think Documentation Should Change:**

```markdown
💡 **Suggestion:** This pattern could be documented in .claude/guidelines/csharp.md.
Would you like me to add it to the guidelines?

[Wait for user approval before modifying]
```

---

## Modular Documents Over Monolithic Documents

**Rule:** Guidance is organized in small, focused files rather than large monolithic documents.

**Structure:**

```
.claude/
├── CLAUDE.md                    # Quick reference (< 500 lines)
├── guidelines/                  # Technology-specific patterns
│   ├── csharp.md               # C# patterns only
│   ├── frontend.md             # Vue.js patterns only
│   ├── terraform.md            # Infrastructure patterns only
│   ├── dynamodb.md             # Database patterns only
│   └── cicd.md                 # Pipeline patterns only
├── constraints/                 # Hard rules
│   └── repository-structure.md # File placement only
├── preferences/                 # Technology choices
│   └── technology-choices.md   # Language/tool preferences only
├── rules/                       # Invariants
│   ├── core-principles.md      # Fundamental rules only
│   └── llm-governance.md       # This file
└── philosophy/                  # Operating model
    └── solo-developer.md       # Operating constraints only
```

**Benefits:**
- **Focused:** Each file has a single responsibility
- **Discoverable:** Easy to find relevant guidance
- **Maintainable:** Changes are localized
- **Composable:** Load only what's needed for the task
- **AI-Friendly:** Clear context boundaries

**Anti-Pattern:**

```
❌ BAD: .claude/EVERYTHING.md (5,000 lines covering all topics)
✅ GOOD: 10 files × 500 lines each, focused topics
```

---

## North-Star Index Document

**Rule:** `CLAUDE.md` is the index/entry point that defines philosophy and points to detailed guidance.

**CLAUDE.md Responsibilities:**
- ✅ Auto-loaded context for every session
- ✅ Quick reference for common patterns
- ✅ Pointers to detailed documentation
- ✅ Technology stack overview
- ✅ Repository structure rules
- ✅ Anti-patterns to avoid

**CLAUDE.md Should NOT:**
- ❌ Duplicate content from other `.claude/` files
- ❌ Exceed ~500 lines (stay concise)
- ❌ Include implementation details (link to guidelines instead)

**Navigation Pattern:**

```markdown
## C# Backend Patterns

**Quick Reference:**
- Use Minimal API pattern (one endpoint per file)
- Records for DTOs, immutability preferred
- Repository pattern for data access

**Detailed Guidance:**
- Architecture → [guidelines/csharp-core.md](../guidelines/csharp-core.md) and [csharp/basics.md](../csharp/basics.md)
- Database → [guidelines/dynamodb.md](../guidelines/dynamodb.md)
- Testing → [csharp/testing.md](../csharp/testing.md)
```

---

## Precedence Rules

**Rule:** When documentation conflicts (rare), follow this precedence order.

**Precedence (Highest to Lowest):**

1. **Constraints** (`.claude/constraints/`) - Mandatory, no exceptions
   - Example: "No source files directly in `src/`"

2. **Rules** (`.claude/rules/`) - Invariant principles
   - Example: "Zero-cost-when-idle architecture"

3. **Guidelines** (`.claude/guidelines/`) - Technology-specific patterns
   - Example: "Use Minimal API for C#"

4. **Preferences** (`.claude/preferences/`) - Default choices
   - Example: "C# preferred for backend"

5. **Philosophy** (`.claude/philosophy/`) - Mindset and approach
   - Example: "Incremental hardening over perfect-on-day-one"

6. **CLAUDE.md** - Quick reference
   - Example: "Serverless-first architecture"

**More Specific Always Wins:**
- `guidelines/csharp.md` > `CLAUDE.md` for C# questions
- `guidelines/terraform.md` > `preferences/technology-choices.md` for infrastructure

**Example Conflict Resolution:**

```
Conflict: Should I use DynamoDB or RDS?

preferences/technology-choices.md: "DynamoDB preferred"
guidelines/dynamodb.md: "Use DynamoDB unless complex relational queries required"

Resolution: guidelines/dynamodb.md wins (more specific)
Decision: Use DynamoDB unless user explicitly needs relational features
```

---

## Vision Documents

**Rule:** Vision documents capture intent for major efforts and persist direction outside chat history.

**Purpose:**
- Long-term direction for multi-session work
- Architectural decisions with rationale
- Feature roadmaps and priorities
- Migration strategies

**Location:** `docs/vision/` (not `.claude/` - these are project-specific, not template guidance)

**Example - Vision Document:**

```markdown
# docs/vision/multi-tenant-architecture.md

## Vision
Support multiple tenants (organizations) in the portal service with data isolation.

## Context
Current system is single-tenant. Need to scale to 100+ organizations.

## Approach
1. Add TenantId to DynamoDB partition keys
2. Implement tenant middleware for request scoping
3. Update all queries to filter by tenant
4. Add tenant management UI

## Constraints
- Must be zero-cost-when-idle (no per-tenant infrastructure)
- Data isolation at partition key level (not separate tables)
- Tenant admin can only see their org's data

## Decisions
- **Decision:** Use DynamoDB partition key prefixing (`TENANT#{id}#USER#{id}`)
- **Rationale:** Cheaper than separate tables, enforces isolation

## Timeline
Phase 1: Backend multi-tenancy (2 weeks)
Phase 2: UI updates (1 week)
Phase 3: Migration of existing data (1 week)

## Success Criteria
- Can create 100 tenants without infrastructure changes
- Data queries automatically scoped to tenant
- No cross-tenant data leakage (verified by security scan)
```

**When to Create Vision Documents:**
- Major architectural changes
- Multi-session features (> 1 day of work)
- Decisions that affect multiple services
- When you need Claude to "remember" the plan across sessions

**Vision vs Guidelines:**

| Vision Docs | Guidelines |
|-------------|------------|
| Project-specific | Template/reusable |
| Temporary (archived after complete) | Permanent |
| `docs/vision/` | `.claude/guidelines/` |
| Describe what to build | Describe how to build |

---

## Plan Documents

**Rule:** Plan documents enable staged, incremental implementation with stop/check/refine workflow.

**Purpose:**
- Break large tasks into phases
- Allow user review before each phase
- Capture decisions and rationale
- Enable Claude to resume work across sessions

**Location:** `docs/plans/` or temporary `.claude/plans/` (auto-generated by plan mode)

**Example - Plan Document:**

```markdown
# docs/plans/implement-user-authentication.md

## Goal
Add JWT-based authentication to portal API.

## Phase 1: Infrastructure (User Approval Required)
- [ ] Create Cognito User Pool (Terraform)
- [ ] Create API Gateway authorizer
- [ ] Deploy to staging
- [ ] Test: Can create user pool, authorizer works

**Dependencies:** None
**Risks:** Cognito costs (~$0.0055/MAU)

## Phase 2: Backend Integration (User Approval Required)
- [ ] Add JWT validation middleware
- [ ] Update endpoints to require auth
- [ ] Add user claims to request context
- [ ] Write tests for auth middleware

**Dependencies:** Phase 1 complete
**Risks:** Breaking existing unauthenticated endpoints

## Phase 3: Frontend Integration (User Approval Required)
- [ ] Add login form
- [ ] Store JWT in localStorage
- [ ] Add auth interceptor to API client
- [ ] Handle token refresh

**Dependencies:** Phase 2 complete
**Risks:** User experience for token expiry

## Decision Log
- **2026-01-11:** Use Cognito instead of custom auth (lower operational burden)
- **2026-01-11:** JWT in localStorage (not cookies) for SPA compatibility
```

**Plan Mode Workflow:**

```
1. User: "Add authentication to the app"
2. Claude enters plan mode
3. Claude explores codebase, documents, existing patterns
4. Claude creates plan with phases
5. Claude asks user to approve plan
6. User reviews, requests changes
7. Claude updates plan
8. User approves Phase 1
9. Claude implements Phase 1
10. User tests Phase 1
11. User approves Phase 2
12. [Repeat...]
```

---

## Task-Scoped Prompting

**Rule:** Only include relevant `.claude/` files in prompts; avoid context dilution.

**Principle:** Load only what's needed for the current task.

**Example - C# Backend Task:**

```
Task: "Add a new user endpoint"

Relevant Context:
✅ .claude/CLAUDE.md (auto-loaded)
✅ .claude/guidelines/csharp.md (C# patterns)
✅ .claude/guidelines/dynamodb.md (if accessing database)
✅ .claude/constraints/repository-structure.md (file placement)

Irrelevant Context:
❌ .claude/guidelines/frontend.md (not working on UI)
❌ .claude/guidelines/terraform.md (not changing infrastructure)
❌ .claude/guidelines/cicd.md (not modifying pipelines)
```

**Example - Frontend Task:**

```
Task: "Add a user profile page"

Relevant Context:
✅ .claude/CLAUDE.md (auto-loaded)
✅ .claude/guidelines/frontend.md (Vue patterns)
✅ .claude/preferences/technology-choices.md (component library choice)

Irrelevant Context:
❌ .claude/guidelines/csharp.md (not writing backend code)
❌ .claude/guidelines/dynamodb.md (not modeling data)
```

**How Claude Should Approach This:**
1. Read task description
2. Identify relevant technology areas
3. Read only related `.claude/` files
4. Apply patterns from those specific files
5. Don't load unnecessary context

---

## LLM Enforcement Rules

**Rule:** Claude Code should enforce guidance through action, not just suggestions.

### Ask When Intent Is Unclear

**Principle:** Don't guess, ask for clarification.

**Examples:**

```
User: "Add a new service"

Claude: "I need clarification:
1. Is this a backend service (C# in src/) or frontend app (Vue in app/)?
2. What should I name it?
3. Does it need database access?"

[Wait for user response before creating files]
```

```
User: "Store this data"

Claude: "Where should I store this data?
1. DynamoDB (serverless, key-value access)
2. S3 (file storage, large objects)
3. User preferences (localStorage on frontend)

Each option has different cost and access patterns. Which fits your use case?"
```

### Prefer Safe, Conservative Defaults

**Principle:** When in doubt, choose the safer, cheaper, more maintainable option.

**Decision Matrix:**

| Choice | Prefer | Avoid | Why |
|--------|--------|-------|-----|
| **Backend Language** | C# | Python, Go | Repo standard |
| **Database** | DynamoDB | RDS | Zero-cost-when-idle |
| **Compute** | Lambda | EC2, Fargate | Serverless default |
| **State Management** | Pinia | Custom solution | Framework-aligned |
| **Infrastructure** | Terraform | CloudFormation | Repo standard |

**Example:**

```
User: "Add user storage"

Claude: "I'll use DynamoDB (repository default for serverless).
- On-demand billing (zero-cost-when-idle)
- Single-table design (cost-effective)
- Repository pattern (matches .claude/guidelines/dynamodb.md)

If you need complex relational queries later, we can migrate to RDS."

[Proceeds with DynamoDB implementation]
```

### Enforce Constraints Automatically

**Principle:** Don't ask permission to follow constraints; enforce them.

**Examples:**

```
❌ BAD:
User: "Create src/Program.cs"
Claude: "Should I create it at src/Program.cs or in a service subdirectory?"

✅ GOOD:
User: "Create src/Program.cs"
Claude: "I can't create files directly in src/ (.claude/constraints/repository-structure.md).
I need a service name. What service should this belong to?"

User: "LibraryService"
Claude: [Creates src/LibraryService/Program.cs]
```

```
❌ BAD:
User: "Use EC2 for this API"
Claude: "OK, creating EC2 instance"

✅ GOOD:
User: "Use EC2 for this API"
Claude: "This repository uses serverless-first architecture (.claude/rules/core-principles.md).

EC2 has always-on costs (~$10-50/month even at zero traffic).
Lambda is the default (pay-per-request, zero-cost-when-idle).

Do you have a specific requirement that Lambda can't meet?
- Long-running processes (>15 min)?
- Specific OS/kernel requirements?
- Existing EC2-only software?

If not, I'll implement with Lambda (following repository standards)."
```

### Suggest Improvements, Don't Mandate

**Principle:** For guidelines and preferences (not constraints), suggest but don't block.

**Example:**

```
User: "Use React for the frontend"

Claude: "This repository prefers Vue.js (.claude/preferences/technology-choices.md) because:
- Existing codebase is Vue
- Component library is Vuetify
- Team familiarity

However, preferences can be deviated from with justification.

Why React for this project?
- Team expertise?
- Specific library requirement?
- Migration plan?

I can proceed with React if you document the rationale in the component's README."
```

---

## Summary

**LLM Governance Hierarchy:**

```
.claude/ = Source of Truth
  ├─ Read-only by default (user must approve changes)
  ├─ Modular files (small, focused documents)
  ├─ CLAUDE.md is index (not comprehensive guide)
  └─ Precedence: Constraints > Rules > Guidelines > Preferences > Philosophy

Task-Scoped Loading
  └─ Load only relevant files, avoid context dilution

Enforcement Strategy
  ├─ Ask when intent unclear
  ├─ Prefer safe, conservative defaults
  ├─ Enforce constraints automatically
  └─ Suggest improvements for preferences
```

**Claude Code Behavior:**

1. **Auto-load** `.claude/CLAUDE.md` every session
2. **Read** relevant `.claude/` files based on task
3. **Follow** constraints (no exceptions)
4. **Apply** guidelines (deviations with user approval)
5. **Suggest** preferences (deviations with documentation)
6. **Ask** when requirements unclear
7. **Enforce** repository standards proactively

---

*These rules ensure consistent, high-quality AI-assisted development across all sessions.*
