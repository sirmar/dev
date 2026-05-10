# ADR 011: mdev service discovery by filesystem convention

**Status:** Accepted  
**Date:** 2026-05-02

## Context

`mdev` needs to know which services exist in a monorepo in order to fan out commands. The options are: an explicit list in config, a convention-based discovery, or a combination with explicit as override.

An explicit-only list requires authors to update `.mdev` whenever a service is added or removed — a maintenance burden that diverges from the codebase. A pure convention risks picking up non-service directories that happen to contain a `.dev` file.

## Decision

`mdev` discovers services by finding all `.dev` files at exactly one level of depth below the monorepo root (`find "$MDEV_ROOT" -mindepth 2 -name '.dev' -type f`). Each directory containing a `.dev` file is treated as a service.

`MDEV_SERVICES` in `.mdev` provides an explicit override: when set, discovery is skipped entirely and only the listed services are used. This covers cases where the filesystem layout is flat, nested differently, or where certain directories with `.dev` files should be excluded from monorepo orchestration.

## Consequences

- Adding a new service directory with a `.dev` file is sufficient for `mdev` to pick it up — no config update required.
- Removing a service directory automatically removes it from `mdev`'s scope.
- Services must live exactly one level deep under the monorepo root; nested workspaces require `MDEV_SERVICES`.
- `MDEV_SERVICES` is an escape hatch, not the default path — the convention should be preferred.
