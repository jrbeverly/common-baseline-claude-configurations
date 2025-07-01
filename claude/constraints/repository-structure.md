# Repository Structure (Mandatory Rules)

**Status:** MANDATORY - These rules cannot be violated.

**Purpose:** Ensure predictable layout, prevent merge conflicts, enable AI-assisted development.

**Repository-Specific Details:** See [CODEMAP.md](../../CODEMAP.md) for THIS repository's actual directory structure, conventions, and technology stack.

---

## Core Principle

**Top-level directories are containers, not code locations.**

All source code, infrastructure, and tests must be **service-scoped** (placed in subdirectories, never directly in top-level containers).

---

## Critical Rule: No Top-Level Source Files

**NEVER place source files directly in these directories:**
- `src/`
- `app/`
- `env/`
- `lib/`
- `test/`

These directories must **only contain subdirectories**.

### Examples

❌ **WRONG:**
```
src/Program.cs              # NO! File directly in src/
app/main.ts                 # NO! File directly in app/
env/main.tf                 # NO! File directly in env/
```

✅ **CORRECT:**
```
src/{ServiceName}/          # Service-scoped
  {ServiceName}.Api/
    Program.cs              # Source files inside service directory
app/{ServiceName}/          # Service-scoped
  src/
    main.ts                 # Source files inside app directory
env/{service-name}/         # Service-scoped
  prod/
    main.tf                 # Infrastructure inside service/environment
```

**See [CODEMAP.md](../../CODEMAP.md) for THIS repository's actual naming conventions.**

---

## Directory Definitions

**Note:** These are generic patterns. See [CODEMAP.md](../../CODEMAP.md) for THIS repository's specific directory structure and conventions.

### `{source-directory}` - Backend Services

**Generic Purpose:** Backend services, APIs, business logic, serverless functions

**Mandatory Rules:**
- One subdirectory per service
- No shared code directly under this directory (use shared library directory instead)
- All code must be service-scoped

**Generic Pattern:**
```
{source-directory}/
  {ServiceName}/
    {Service}.Api/              # REST API or entrypoint
    {Service}.Domain/           # Core business logic (if applicable)
    {Service}.Infrastructure/   # Data access, external services (if applicable)
```

### `{app-directory}` - Frontend Applications

**Generic Purpose:** Web frontends, browser-based UIs, client applications

**Mandatory Rules:**
- One subdirectory per frontend application
- Frontend code mirrors backend service naming where applicable
- All code must be service-scoped

**Generic Pattern:**
```
{app-directory}/
  {ServiceName}/
    src/                        # Application source
    tests/                      # Application tests
    package.json                # Dependencies (if applicable)
```

### `{infrastructure}` - Infrastructure Deployments

**Generic Purpose:** Real infrastructure deployments (production, staging, etc.)

**Mandatory Rules:**
- Contains **only deployable infrastructure**
- No reusable module definitions (use modules directory)
- Configuration-oriented (calls modules, wires inputs/outputs)
- Environment-specific configurations separated

**Generic Pattern:**
```
{infrastructure}/
  {service-name}/
    prod/
      # Production configuration
    staging/
      # Staging configuration
```

### `{shared}` - Shared Libraries

**Generic Purpose:** Code shared across 2+ services

**Mandatory Rules:**
- Must be reusable by multiple services
- No service-specific logic
- No reverse dependencies (doesn't depend on source or app directories)
- Should be designed for future extraction

**Generic Pattern:**
```
{shared}/
  {PackageName}/
    src/
    tests/
```

### `{modules}` - Infrastructure Modules

**Generic Purpose:** Reusable infrastructure modules (project-local)

**Mandatory Rules:**
- No environment-specific configuration
- Reusable within this repository
- Prefer external registry modules when possible

**Generic Pattern:**
```
{modules}/
  {module-name}/
    # Module definition files
    # Variables, outputs, README
```

### `{tests}` - Tests

**Generic Purpose:** Tests scoped to services or libraries

**Mandatory Rules:**
- Mirror source directory structure
- No tests at top-level
- Follow language-specific test file naming conventions

**Generic Pattern:**
```
{tests}/
  {ServiceName}/
    {Service}.Tests/
    # Or whatever test structure mirrors source
```

---

## Service Naming Consistency

**Rule:** The same logical service name should appear across all relevant top-level directories.

**Generic Pattern:**
```
{source-directory}/{ServiceName}/     # Backend code
{app-directory}/{ServiceName}/        # Frontend code
{infrastructure}/{service-name}/      # Infrastructure (may use different casing)
{tests}/{ServiceName}/                # Tests
```

**Benefits:**
- Easy to find related code
- Clear service boundaries
- AI can infer relationships

**See [CODEMAP.md](../../CODEMAP.md) for THIS repository's naming conventions** (PascalCase, kebab-case, etc.)

---

## Expansion Model (Future-Proofing)

**Adding new services means adding new directories, not changing existing ones.**

### Adding a New Service

1. Create service directory in source location
2. Create frontend directory (if needed)
3. Create infrastructure directory
4. Create test directory
5. Add README.md to each explaining purpose

**See [CODEMAP.md](../../CODEMAP.md) for specific commands and directory names for THIS repository.**

### What NOT to Do

❌ Don't refactor existing services when adding new ones
❌ Don't create generic "utils" or "common" directories under source directories
❌ Don't share code by copy-paste (use shared library directory instead)

---

## Enforcement for AI/LLMs

When generating code or infrastructure:

**Always:**
1. Identify which service the code belongs to
2. Create or use the service-scoped directory
3. Never place files directly in top-level containers
4. Ask if unsure which service

**If tempted to create a top-level file:**
→ Stop and ask: "Which service does this belong to?"
→ If "multiple services" → Consider `lib/` for shared code
→ If "no specific service" → It probably shouldn't exist

---

## Rationale

**Why service-scoped directories?**

1. **Merge Safety:** Prevents naming collisions when merging repositories
2. **Scalability:** Repository scales from 1 to many services without refactoring
3. **Clarity:** Service boundaries are explicit
4. **AI-Friendly:** Structure communicates intent
5. **Extraction:** Can extract a service to its own repo cleanly

**Why this matters for AI:**
- Predictable patterns → Better code generation
- Explicit structure → Fewer placement errors
- Clear boundaries → Less coupling

---

## Exceptions

**None.** These rules have no exceptions.

If you think you need an exception, you probably need to:
- Create a new service subdirectory
- Use `lib/` for shared code
- Reconsider the architecture

---

*This is a constraint document. Rules here are mandatory and cannot be violated.*
