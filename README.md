# Common Baseline Claude Configurations

> [!WARNING]
> **AI-authored:** This change was autonomously planned and implemented by an AI software factory from a human-authored specification, with possible subsequent human review or modification.

> [!WARNING]
> This experiment is effectively abandoned. The generated material is retained primarily as a research artifact.

Explores a common baseline `.claude/` configuration shared across many repositories, structured as a knowledge base / wiki rather than one large instruction file. Abandoned to pursue decomposition approaches.

The top-level `CLAUDE.md` was meant to act as an index ("looking for X, go to this file"), keeping the always-loaded context short, with the detailed guidance read only when relevant to the task.

```text
claude/
├── CLAUDE.md        # entry point / index
├── constraints/     # must follow
├── rules/           # invariants
├── preferences/     # defaults, deviations need justification
├── guidelines/      # per-technology patterns (terraform, dynamodb, frontend, security, cicd)
├── csharp/          # C# patterns (basics, minimal API, domain modeling, errors, testing, logging)
└── philosophy/      # operating model (solo developer)
```

## Notes

- The index did not stay an index. `CLAUDE.md` grew to ~350 lines, restating decision guides, twelve-factor principles, and pattern summaries alongside the "go to this file" pointers.
- Linked files are large (1,300–1,800 lines for `minimal-api.md`, `basics.md`, `dynamodb.md`, `frontend.md`), so a single "read when relevant" hop still pulls in a lot of context. The knowledge base totals ~12,800 lines across 20 files.
- Guidance is split by authority level (constraints / rules / preferences / guidelines / philosophy), but the same principles (zero-cost-when-idle, avoid premature abstraction, explicit over implicit) repeat across several levels.
- Being a shared baseline, `CLAUDE.md` defers repository specifics to a `CODEMAP.md` outside `.claude/`, which each consuming repository has to provide.
- `execute.sh` was the distribution mechanism: a workspace automation recipe that copies `.claude/` into repositories that lack one and commits it. The directory is stored here as `claude/` rather than `.claude/`, so the script does not run as-is.

Overall idea was eventually abandoned as I pursued more loop-driven flows in which tasks were divided to specialized agents with well-defined inputs and outputs, alongside detailed documentation in the repository itself (human consumable).
