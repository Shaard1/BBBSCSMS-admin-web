---
name: coding-excellence
description: Language-agnostic rules for writing clean, maintainable, secure code.
tags: [clean-code, architecture, security]
version: 2.0
---

# Coding Excellence

## Core Rules

- Clarity over cleverness
- Simplicity over complexity
- Consistency over personal style
- Explicit over implicit behavior

## Design Principles (SOLID)

- Single responsibility per unit
- Extend via composition, not modification
- Enforce contracts/types correctly
- Prefer small, focused interfaces
- Depend on abstractions, not implementations

## Naming

- Descriptive, domain-aligned names
- Avoid ambiguity and unnecessary abbreviations
- Functions = actions (verbs), variables = entities (nouns)
- Follow language conventions

## Code Organization

- Small, cohesive modules
- One abstraction level per function
- Organize by feature/domain, not file type
- Minimize cross-module coupling

## Functions

- Single responsibility only
- Prefer pure functions (no side effects)
- Limit parameters (3 or fewer)
- Early returns over deep nesting
- Keep length short (15-30 lines ideal)

## State & Data

- Minimize mutable state
- Prefer immutability
- Centralize state changes
- Validate all external data at boundaries

## Error Handling

- Fail fast and explicitly
- No silent failures
- Return structured, meaningful errors
- Avoid excessive error nesting

## Comments & Docs

- Explain intent (why), not implementation (what)
- Keep docs in sync with code
- Self-documenting code > comments

## Testing

- Test observable behavior
- Cover edge cases and failure paths
- Keep tests deterministic and isolated
- Prefer unit tests; add integration where necessary

## Refactoring

- Continuous and incremental
- Eliminate duplication
- Improve readability before optimization
- Preserve behavior (tests as safety net)

## Security

- Treat all inputs as untrusted
- Validate and sanitize at boundaries
- Enforce least privilege
- Never hardcode secrets
- Use safe defaults (deny by default)

## Performance

- Measure before optimizing
- Focus on algorithmic efficiency first
- Avoid premature optimization
- Cache and batch where appropriate

## Logging

- Log key events, errors, state transitions
- Include context for debugging
- Exclude sensitive data
- Ensure logs are structured

## Code Smells

- Long functions or large classes
- Deep nesting (>3 levels)
- Repetition (DRY violations)
- God objects or tight coupling
- Magic numbers without explanation

## Anti-Patterns

- Spaghetti code (no structure)
- Primitive obsession (use domain objects)
- Hardcoded credentials
- Silent exception handling
- Missing input validation

## Code Review Checklist

- Readable without context?
- Correct abstraction level?
- Test coverage adequate?
- Security/validation enforced?
- Minimal complexity?

## Decision Heuristic

1. Simplest correct solution
2. Optimize for readability and maintainability
3. Ensure testability
4. Optimize only if justified
5. When in doubt: KISS > DRY
