# C# Guidelines

**Purpose:** Focused guidance for C# backend development patterns.

**See [CODEMAP.md](../../CODEMAP.md) for THIS repository's C# usage and conventions.**

---

## Navigation

This directory contains focused documents for specific C# topics:

### Core Patterns

- **[minimal-api.md](minimal-api.md)** - Minimal API pattern (static classes, one endpoint per file)
- **[basics.md](basics.md)** - Records, dependency injection, validation, basic error handling

### Design Patterns

- **[domain-modeling.md](domain-modeling.md)** - Value objects, immutability, equality by value
- **[error-modeling.md](error-modeling.md)** - Result pattern, explicit error types

### Cross-Cutting Concerns

- **[logging.md](logging.md)** - Structured logging, correlation IDs, CloudWatch integration
- **[testing.md](testing.md)** - Testing strategy, fakes over mocks, deterministic tests

---

## When to Use Each Document

**Starting a new service?** → Read in this order:
1. [minimal-api.md](minimal-api.md) - Endpoint pattern (versioned routes, nested classes)
2. [basics.md](basics.md) - Common patterns (records, DI, validation)
3. [domain-modeling.md](domain-modeling.md) - Domain design (value objects, immutability)

**Adding domain logic?** → [domain-modeling.md](domain-modeling.md)

**Handling errors?** → [error-modeling.md](error-modeling.md)

**Setting up logging?** → [logging.md](logging.md)

**Writing tests?** → [testing.md](testing.md)

---

## Related Documentation

- **[CODEMAP.md](../../CODEMAP.md)** - Repository-specific C# conventions
- **[.claude/guidelines/dynamodb.md](../guidelines/dynamodb.md)** - DynamoDB patterns
- **[.claude/philosophy/solo-developer.md](../philosophy/solo-developer.md)** - Why these choices matter

---

**Status:** GUIDELINES - Preferred approaches, deviations allowed with justification.
