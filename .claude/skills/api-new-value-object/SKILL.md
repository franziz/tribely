---
name: api-new-value-object
description: BACKEND ONLY. Scaffold a value object in apps/api/src/features/<feature>/domain/value-objects/<name>.ts with private constructor + create() factory + validation.
---

# /api-new-value-object

```
/api-new-value-object <feature> <Name>
```

**Scope guard:** Backend API only. If the user wants a Dart VO for Flutter, ask first — Flutter side typically uses simpler classes and we don't currently have a `/mobile-new-value-object` skill (Flutter VOs are rarer in our stack).

Examples:

- `/api-new-value-object users Email`
- `/api-new-value-object events Capacity`

## Validate

REFUSE if:

- `<feature>` doesn't exist.
- Name is not PascalCase singular noun.
- Would overwrite an existing file.

## Scaffold

Path: `apps/api/src/features/<feature>/domain/value-objects/<kebab>.ts`.

```ts
import { AppError } from '@/core/errors/app-error.js';

/**
 * <Name> value object.
 *
 * Identity is its normalized value — two <Name>s with the same value are equal.
 * Construct via <Name>.create(raw); never `new <Name>(...)`.
 */
export class <Name> {
  private constructor(public readonly value: string) {}

  static create(raw: string): <Name> {
    // TODO: normalize (trim, lowercase, etc.) then validate
    const normalized = raw.trim();
    if (/* TODO: invalid */ false) {
      throw AppError.validation(`Invalid <Name>: ${raw}`);
    }
    return new <Name>(normalized);
  }

  equals(other: <Name>): boolean {
    return this.value === other.value;
  }

  toString(): string {
    return this.value;
  }
}
```

If the VO wraps a non-string primitive (number, Date), adjust the field type and the `create` parameter accordingly.

## Print after scaffolding

```
Value object scaffolded at <path>

NEXT STEPS:
  1. Implement the validation rules in `create`.
  2. Replace primitive-typed fields on related entities with the VO type.
  3. Update mappers: domain VOs → row primitives via `.value`; row → domain via `<Name>.create(...)`.
```
