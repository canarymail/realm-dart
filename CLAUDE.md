# canarymail/realm-dart fork — maintainer notes

This is Canary Mail's fork of `realm/realm-dart`. The working branch is **`dove`**.

It carries one logical fix, delivered as a plain **git dependency**.

## The fix ([issue #1887](https://github.com/realm/realm-dart/issues/1887))

Upstream's `prepare_command` interpolates an absolute filesystem path, which gets baked into
`Pods/Local Podspecs/realm.podspec.json` and makes `SPEC CHECKSUMS` in `Podfile.lock` differ
between developers. Two podspec files are involved:

- **`packages/realm/ios/realm.podspec`**
  - Writes the machine-specific path into a sidecar script (`.realm_flutter_install_env.sh`)
    next to the podspec and references it from `prepare_command` with a **constant relative
    path**, so the podspec JSON (and therefore the checksum) is identical across machines.
  - `prepare_command` also begins with a **symlink guard**:
    `if [ -L realm_dart.xcframework ]; then rm -f realm_dart.xcframework; fi`.
    See "Why the guard" below.
- **`packages/realm/macos/realm.podspec`** — uses a relative `touch librealm_dart.dylib`
  instead of an absolute path.

The fix is machine-independent: the only per-machine data lives in the sidecar file, never in
the podspec JSON.

## How it's consumed

As a git dependency on `dove` (in the consumer app's `dependency_overrides`):

```yaml
realm:
  git:
    url: https://github.com/canarymail/realm-dart.git
    path: packages/realm
    ref: dove
```

`realm_dart`, `realm_common`, etc. resolve unchanged from pub.dev. Native binaries are downloaded
at install time by `realm install` from `https://static.realm.io/downloads/dart/<version>/<os>.tar.gz`
(`packages/realm_dart/lib/src/cli/install/install_command.dart`).

### Why the guard

This repo commits a symlink `packages/realm/ios/realm_dart.xcframework -> ../../realm_dart/binary/ios/...`
(for in-repo development). In a fresh git checkout that target doesn't exist, so the symlink dangles.
`realm install` then can't extract the downloaded xcframework *through* the dangling symlink and
`pod install` fails with `PathNotFoundException`. The guard deletes the dangling symlink first, so
`realm install` creates a real directory. It's a no-op once a real dir exists, and would be a no-op
for the published pub.dev package (which has no symlink). The official publish pipeline strips these
symlinks (`.github/workflows/publish-release.yml`); the guard is the git-dependency equivalent.

> Note: the macOS podspec has the analogous committed-symlink situation (`librealm_dart.dylib`).
> If you start consuming realm on macOS via this git dependency, verify `pod install` there and add
> an equivalent guard if needed — it has not been exercised yet.

## Updating the fork

1. Make changes on `dove`, `git push origin dove`.
2. In the consumer app: `flutter pub upgrade realm` (re-resolves the branch to the new HEAD),
   then `flutter pub get && (cd ios && pod install)`.

There is no package to publish and no registry to deploy — pushing `dove` is the whole release.

## Versioning

The package version in `packages/realm/pubspec.yaml` (currently `20.2.0`) must equal a **real
upstream realm release**, because `realm install` derives the native-binary download URL from it
(`static.realm.io/downloads/dart/<version>/...`). A made-up version (`20.2.1`) or a
`+build`/`-prerelease` suffix would make the binary download 404.

- **To track a new upstream release:** rebase `dove` onto the new upstream tag, re-apply the two
  podspec edits, set the matching version, push. Binaries for released versions exist on
  `static.realm.io`, so it just works.
- **To iterate the patch within the same upstream version:** just push to `dove` and have consumers
  `flutter pub upgrade realm`. The version number stays the same; pub re-pins to the new commit.

## Long-term

The #1887 podspec fix is a good upstream PR candidate. If it lands upstream, drop this fork and the
override entirely and use the official hosted `realm`.
