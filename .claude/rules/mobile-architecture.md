---
paths:
  - "apps/mobile/**"
---

# Mobile architecture (`apps/mobile`)

Sources: [TDD Clean Architecture for Flutter (Reso Coder)](https://github.com/ResoCoder/flutter-tdd-clean-architecture-course), [Flutter Clean Architecture with Riverpod](https://github.com/uuttssaavv/flutter-clean-architecture-riverpod).

## Layers (per feature) — 3 layers, NOT 4

```
features/<snake_name>/
  domain/                              # Pure Dart — no Flutter, no Dio, no Riverpod
    entities/                          # Equatable classes
    repositories/                      # Abstract interfaces returning Either<Failure, T>
    services/                          # Pure-Dart domain services — stateless ops, no Flutter/Riverpod imports.
                                       # Use sparingly; most logic belongs on entities or in use cases.
    usecases/                          # Implements UseCase<T, Params>; Future<Either<Failure, T>>
    validators/                        # Per-field input validation — pure functions returning ValidationResult
  data/
    models/                            # JSON serialization + toEntity()
    datasources/                       # RemoteDataSource (interface + impl colocated)
    repositories/                      # Concrete impls — catch DioException → Failure
  presentation/
    pages/                             # ConsumerWidget screens
    widgets/                           # Feature-scoped widgets
    providers/                         # Riverpod providers wiring use cases
    controllers/                       # StateNotifier — owns state transitions
    state/                             # Sealed state classes
```

## Why Flutter is 3-layer (NOT 4-layer like the API)

Flutter use cases are thin wrappers: `call(params) => repository.method()`. They don't orchestrate transactions, multiple aggregates, or events. Adding an `application/` layer for thin wrappers is over-engineering on the client. Reso Coder's tutorial and the Riverpod community examples both keep use cases in `domain/usecases/` — we follow that convention. **The asymmetry is intentional**, not an inconsistency to "fix."

## Why mobile keeps `data/datasources/` (the API doesn't)

On the API, Prisma is the persistence layer — a separate datasource layer adds dead weight. On the mobile, the datasource layer is meaningful (REST + cache + local DB are genuinely different sources, and the repository orchestrates them). The Flutter community convention earns its keep here.

## Why repositories return `Either<Failure, T>` on mobile but throw on API

- API: throwing `AppError` flows into Hono's `onError` middleware producing a uniform HTTP shape.
- Mobile: UI needs to render error states declaratively; failures are part of the type signature, eliminating uncaught-exception UI bugs.

## Mobile gotchas

- **Mobile session-state is the first sanctioned cross-feature `presentation/` import** (unless explicitly sanctioned below). Features may import `auth/presentation/providers/auth_providers.dart` to read `sessionControllerProvider` for current-user identity; every other cross-feature `presentation/`-to-`presentation/` import violates the bounded-context rule unless explicitly listed below. Session identity is genuinely app-global state, not feature state — duplicating it per feature would fragment auth and invite drift on logout/refresh.
- **The `join_requests/presentation/` layer is the second sanctioned cross-feature import.** Features may import from `join_requests/presentation/{controllers,providers,state,widgets}/` directly (e.g., `discover/` event-detail importing `ConfirmJoinSheet` + `joinRequestController`; `my_events/` Requests tab importing `MyJoinRequestRow` + `myJoinRequestsController`; `my_events/` hosting badge reading `hostingPendingCountProvider`). Join-request is a request-pattern primitive shared by `events`, `discover`, and `my_events` — relocating its widgets/controllers/state/providers into `core/` would surface every primitive each consumer already needs without adding information-hiding.
- **`users/presentation/providers/capability_providers.dart` is the third sanctioned cross-feature import.** Features may import `myCapabilitiesProvider` to read app-global host capabilities (e.g., `events/` create-event controller reading `canPostPrivateVenue` to drive TRI-33 warning copy), and `selfieGatingStateProvider` to read the authenticated user's selfie gate state (e.g., the `events/` and `join_requests/` disabled-CTA hint widgets reading it to decide which hint copy to show — TRI-70 Brief E). Both are session-scoped app-global state — like `auth_providers.dart`, not feature state. Moving them to `core/` would invert layering (`core/` → `users/data/UserCapabilitiesRepository`); inlining thin duplicates per feature fragments Riverpod cache keys and breaks `ref.invalidate` propagation on refresh. The auth precedent deliberately kept session-scoped providers in their owning feature; capabilities and selfie-gating follow the same pattern. This exception also covers two transitive companion files that are inseparable from the sanctioned providers' consumption surface: `users/presentation/state/selfie_gating_state.dart` (the sealed-class return type of `selfieGatingStateProvider` — required by any consumer that pattern-matches on the gating value) and `users/presentation/string_assets/verification_failure_copy.dart` (the Designer-mandated copy SoT for disabled-CTA hints rendered alongside the sanctioned providers' state — required by `events/` and `join_requests/` per TRI-70 Brief F). The state-class and copy-SoT companion imports are covered under the same exception because they are inseparable from the sanctioned provider's consumption surface — pattern-matching on a sealed return type requires importing the class; rendering Designer-mandated verbatim copy requires importing the SoT constants. Do NOT extend this exception to a FIFTH feature without orchestrator + engineering-lead sign-off; the bar remains "would `core/` extraction produce meaningful information-hiding?" and "is this a primitive or a feature?".
- **`reviews/presentation/{providers,controllers,state}/` is the fourth sanctioned cross-feature import.** Features may import `reviewRepositoryProvider`, `getPendingReviewPromptUseCaseProvider`, `pendingReviewBannerControllerProvider`, and the review-aggregate widget directly. Reviews are app-global state on every profile and integrate with `users/` (profile aggregate render), `events/` (post-event composer entry), and `my_events/` (foreground banner + edit list). Relocating to `core/` would force every consumer to import the use-case-shaped provider surface without information-hiding (3 consumers crossing the threshold). The state/controller/provider exception covers what's needed for ConsumerWidget renders and ref.listen wiring; do NOT extend to widget imports without explicit orchestrator + engineering-lead sign-off (Brief 2A/2B exceptions are inline one-widget references, not blanket cross-feature widget imports).
- **Mobile `flutter create` is required on first run** — repo ships without `ios/`/`android/` folders.
- **Mobile lint plugin: top-level `plugins:`, NOT `analyzer.plugins: - custom_lint`.** `riverpod_lint` uses the Dart 3.5+ `analysis_server_plugin` mechanism in `apps/mobile/analysis_options.yaml`. The `analyzer.plugins:` form (custom_lint host) has an upstream synthesizer bug that breaks resolution.
- **Mobile controllers use `Notifier<T>`, auto-dispose lives on the provider.** Riverpod 3 controllers in this codebase extend `Notifier<FooState>` (never `AutoDisposeNotifier` — not exported in our Riverpod 3.x version). Autodispose is configured on the provider chain: `NotifierProvider.autoDispose<FooController, FooState>(FooController.new)`. Pairing `Notifier<T>` with `NotifierProvider.autoDispose` is the established convention (verified across `hosting_pending_count_controller`, `my_join_requests_controller`, `host_pending_list_controller`, `request_to_join_controller`, the auth controllers, and post-TRI-28 `hosting_tab_controller` and `my_events_controller`). Do NOT introduce `AutoDisposeNotifier<T>` — analyzer will reject it.
- **Flutter golden tests are macOS-baseline; Linux CI must skip them.** Goldens generated on macOS will not match CI's Linux FreeType rendering (~1-2% pixel diff from font hinting/anti-aliasing). Guard golden test bodies with `skip: Platform.isLinux ? 'skip reason' : null` so they run on developer machines (catching real layout regressions at PR-author time) but skip in CI. Cross-platform baselines or font-normalization harnesses (alchemist, golden_toolkit) are deferred — revisit when goldens become a recurring pattern, not a one-off.
