# ADR 001: Keep the reader core source-oriented

- Status: accepted
- Date: 2026-09-21
- Author: Yudai Takada

## Context

Docs, feeds, and mail share fetching, normalization, safe HTML handling,
storage, and history. Their input parsers are separate libraries, while the
reader needs one small source interface.

## Decision

Dubhe owns source orchestration, policies, file-backed storage, HTTP fetching,
and reader state. Iklil owns feed parsing, Ukdah owns MIME parsing, and Jabbah
owns HTML parsing/sanitization. The v1 renderer is intentionally plain and
does not inspect author CSS. JavaScript and WebView embedding are out of scope.

## Consequences

The feed path is useful without a GUI and remains testable with deterministic
fetchers. A future UI can consume `Entry`, `Body`, and `Source` without
reimplementing security or persistence. A richer CSS renderer can be added
later without changing source contracts.
