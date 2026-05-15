# Releasing Parcelite

Parcelite releases are created from version tags.

## Checklist

1. Update `CHANGELOG.md` with the release date and user-facing changes.
2. Confirm the build and tests pass locally:

```bash
swift build
swift test
make app
```

3. Create and push the version tag:

```bash
git tag v0.1.0
git push origin v0.1.0
```

4. Check the GitHub Release created by the `Release` workflow.
5. Confirm the `Parcelite-*-macOS.zip` asset is attached.

## First Launch Note

Until Parcelite is notarized, macOS may show a Gatekeeper warning on first launch. Open the app from Finder's context menu if you trust the downloaded build.
