import type { MiddlewareHandler } from 'hono';
import type { ZodType, ZodTypeDef } from 'zod';
import { AppError } from '../errors/app-error.js';

/**
 * Middleware that validates an **optional** JSON request body against a Zod schema.
 *
 * Unlike `zValidator('json', schema)`, which throws 400 when the body is absent
 * or empty (Hono's `json` validation target calls `c.req.json()` before the
 * validation function runs and throws on an empty body), this middleware performs
 * its own tolerant body read so that absent / empty / unparseable bodies resolve
 * to `{}` before schema validation.
 *
 * Behaviour:
 *  - Absent, empty, or unparseable body  → resolved to `{}`  → validated against schema.
 *  - Present + schema-valid body         → `c.req.valid('json')` returns the parsed data.
 *  - Present + schema-invalid body       → throws `AppError.validation` → HTTP 400.
 *
 * The validated data is stashed via `c.req.addValidatedData('json', data)`, which
 * is the same internal call that Hono's own `validator()` makes, so downstream
 * handlers reading `c.req.valid('json')` receive it unchanged.
 *
 * This construct is opt-in: mount it only on endpoints whose JSON body is entirely
 * optional. Do NOT use it where a body is always required — use `zValidator`
 * directly in that case.
 *
 * @example
 * ```ts
 * app.post('/events/:id/join-requests',
 *   optionalJsonValidator(requestToJoinEventBodySchema),
 *   controller.createAction,
 * );
 * ```
 */
export const optionalJsonValidator =
  <Output, Def extends ZodTypeDef, Input>(schema: ZodType<Output, Def, Input>): MiddlewareHandler =>
  async (c, next) => {
    // Tolerant body read: absent, empty, or non-JSON bodies all resolve to `{}`.
    // This is the same primitive used in join-request.controller.ts `createAction`
    // to work around the empty-body 400 trap in Hono's `json` validation target.
    const raw = await c.req.json<unknown>().catch(() => ({}));

    const parsed = schema.safeParse(raw);

    if (!parsed.success) {
      throw AppError.validation('Invalid request body', parsed.error.flatten());
    }

    // Mirror the exact internal call that Hono's `validator()` makes so that
    // downstream `c.req.valid('json')` reads the stashed value correctly.
    // Source: node_modules/hono/dist/validator/validator.js line 80.
    // `addValidatedData` is typed as `(target, data: {})`. Casting via `object`
    // satisfies the constraint; the linter rejects `{}` (empty-object-type rule)
    // but `object` is the correct semantic ("any non-primitive value") here.
    c.req.addValidatedData('json', parsed.data as object);

    await next();
  };
