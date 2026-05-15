# Contributing

Thanks for helping improve Parcelite.

## Development

Use the standard Swift toolchain:

```bash
swift build
swift test
make app
```

Keep app-facing text in English. Keep Ship24-specific code behind the tracking provider boundary so future providers can be added without rewriting the UI.

## Pull Requests

- Describe the user-facing change and any migration impact.
- Add or update tests for parsing, persistence, validation, and provider behavior when relevant.
- Run `swift build` and `swift test` before opening a PR.

## Release Notes

User-facing changes should be recorded in `CHANGELOG.md`.
