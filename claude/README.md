# Claude Knowledge Base

This directory contains structured knowledge for AI code assistants working with this repository.

**Purpose:** Provide explicit context, rules, guidelines, and preferences for AI-assisted development.

**Primary File:** [CLAUDE.md](CLAUDE.md) - Auto-loaded by Claude Code at session start

---

## Quick Navigation

**Start Here:**
- [CLAUDE.md](CLAUDE.md) - Essential context (5 min read)
- [../CODEMAP.md](../CODEMAP.md) - Repository-specific structure, tech stack, and patterns

**Specific Topics:**
- [guidelines/](guidelines/) - Preferred approaches and best practices
- [constraints/](constraints/) - Mandatory rules and technical limits
- [preferences/](preferences/) - Technology choices and defaults
- [rules/](rules/) - Hard invariants that must be followed
- [philosophy/](philosophy/) - Operating model and mindset

---

## Directory Structure

```
.claude/
├── CLAUDE.md              # Main context file (auto-loaded)
├── README.md              # This file
├── guidelines/            # Best practices (should follow)
│   ├── csharp.md          # C# backend patterns
│   ├── frontend.md        # Vue.js/TypeScript patterns
│   ├── terraform.md       # Infrastructure patterns
│   ├── dynamodb.md        # Database modeling patterns
│   ├── cicd.md            # CI/CD pipeline patterns
│   └── security.md        # Security best practices
├── constraints/           # Mandatory rules (must follow)
│   └── repository-structure.md
├── preferences/           # Defaults (can deviate with justification)
│   └── technology-choices.md
├── rules/                 # Invariants (cannot violate)
│   ├── core-principles.md
│   └── llm-governance.md  # How Claude Code should work
└── philosophy/            # Operating model and mindset
    └── solo-developer.md
```

---

## How to Use

### For AI Assistants (Claude Code)

1. **CLAUDE.md is auto-loaded** - No need to read explicitly
2. **Reference repository specifics** → [../CODEMAP.md](../CODEMAP.md) for tech stack and structure
3. **Check specific topics** for deep dives:
   - Repository structure → [constraints/repository-structure.md](constraints/repository-structure.md)
   - Technology choices → [preferences/technology-choices.md](preferences/technology-choices.md)

### For Human Developers

1. **Onboarding:** Read [CLAUDE.md](CLAUDE.md) for quick context, then [../CODEMAP.md](../CODEMAP.md) for repository specifics
2. **Working:** Check topic-specific guidelines in [guidelines/](guidelines/) for patterns and decisions
3. **Deep Dive:** Read individual guideline files for comprehensive patterns

---

## Philosophy

### Context Engineering Over Prompt Engineering

This knowledge base is designed for **systematic context provision**, not one-off prompts.

**Principles:**
- **Explicit over implicit** - No tribal knowledge
- **Structured for AI parsing** - Consistent formats, clear headers
- **Example-driven** - Patterns demonstrated in code
- **Maintainable** - Version-controlled, evolves with codebase

### Knowledge Categories

| Category | Purpose | Flexibility |
|----------|---------|-------------|
| **Rules** | Hard invariants that cannot be violated | None (must follow) |
| **Constraints** | Technical and architectural limits | None (must follow) |
| **Guidelines** | Preferred approaches and best practices | Should follow |
| **Preferences** | Technology choices and defaults | Can deviate with justification |
| **Philosophy** | Operating model and mental frameworks | Guides thinking, not enforcement |

---

## Precedence

When documentation conflicts (rare):

1. **Constraints** (highest - repository structure rules)
2. **Rules** (core principles)
3. **Guidelines** (specific patterns)
4. **Preferences** (technology choices)
5. **CLAUDE.md** (quick reference)

**More specific always wins:** Domain-specific guidance (terraform.md, csharp.md) overrides general guidance.

---

## Maintenance

### When to Update

**Update these docs when:**
- New patterns emerge from actual code
- Technology choices change
- Architectural decisions are made
- Common questions arise repeatedly

**Don't update for:**
- One-off solutions
- Experimental code
- Project-specific details (put in project docs, not template)

### How to Update

1. **Make changes** in same PR as code introducing the pattern
2. **Maintain consistency** with existing format and style
3. **Add examples** - show, don't just tell
4. **Update cross-references** if structure changes

---

## Status (Bootstrap Template)

**Current State:** Minimal viable knowledge base

**Well-Documented:**
- ✅ Repository structure rules and service-scoped organization
- ✅ Technology stack overview and preferences
- ✅ Core patterns (Minimal API, DynamoDB single-table, Composition API)
- ✅ C# patterns (hexagonal architecture, domain modeling, error handling)
- ✅ Frontend patterns (Vue.js philosophy, component reuse, state management)
- ✅ Infrastructure patterns (Terraform environments, cost-aware defaults)
- ✅ DynamoDB modeling (access patterns, key encoding, multi-tenancy)
- ✅ CI/CD patterns (Gitea Actions, cost optimization)
- ✅ Security guidelines (architectural security, deferred hardening)
- ✅ LLM governance (how Claude Code should interact with this repo)
- ✅ Solo developer philosophy (incremental hardening, cost consciousness)

**To Be Expanded (as patterns emerge in actual projects):**
- ⚠️ Monitoring and alerting (CloudWatch, alarms)
- ⚠️ Advanced testing patterns (integration, E2E)
- ⚠️ Deployment rollback strategies
- ⚠️ Data migration patterns

**Evolution Strategy:** Start minimal, expand based on real usage in projects created from this template.

---

*This knowledge base is optimized for Claude Code and AI-assisted development.*
