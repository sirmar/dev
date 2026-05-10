# ADR 007: Prebuilt language base images

**Status:** Accepted  
**Date:** 2026-04-09 (`d77dda8 Switch to prebuilt stage images in Dockerfile`)

## Context

ADR 006 established that all toolchain logic lives in Dockerfiles. Each project still needs to install its language runtime, common tooling (linters, test runners, normalizer scripts), and shared entrypoints. If projects do this from scratch in their own Dockerfiles, every project re-downloads and re-installs the same layers on every build — slow, verbose, and inconsistent across projects using the same language.

## Decision

`dev` ships a set of prebuilt, versioned language base images under `images/<language>/`. Each image bundles:

- The language runtime (e.g. Python, Node)
- Common tooling needed by `dev` (e.g. `jq` for result parsing, `uv`/`pnpm` for dependency management)
- Shared entrypoint scripts (e.g. `unit-entrypoint.sh`, `unit-normalizer`) that implement the dev result format contract
- A `healthcheck.sh` for Compose-based environments

Project Dockerfiles inherit from these images (`FROM ghcr.io/sirmar/dev-<language>:<version>`) rather than from upstream language images directly. This makes the project Dockerfile a thin layer of project-specific setup on top of a stable, pre-cached base.

The images live in `images/<language>/` in this repo, are built and pushed via `mdev push`, and are tagged on release.

## Consequences

- Project Dockerfiles are shorter and more consistent — they don't repeat runtime installation and entrypoint wiring.
- Updates to shared tooling (e.g. a new normalizer version, a new `dev`-mandated env var) are made in the base image and inherited by all projects on upgrade.
- Projects are coupled to the base image version; upgrades may require coordinated changes across repos.
- The `image` repo type exists specifically to build and publish these base images using `dev` itself.
