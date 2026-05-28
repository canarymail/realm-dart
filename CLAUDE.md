# canarymail/realm-dart fork — maintainer notes

This is Canary Mail's fork of `realm/realm-dart`. The working branch is **`dove`**.

It exists to carry one fix and to ship it as a normal hosted dependency:

1. **iOS/macOS podspec fix for [issue #1887](https://github.com/realm/realm-dart/issues/1887).**
   Upstream's `prepare_command` interpolates an absolute filesystem path, which gets baked
   into `Pods/Local Podspecs/realm.podspec.json` and makes `SPEC CHECKSUMS` in `Podfile.lock`
   differ between developers. The fix is in:
   - `packages/realm/ios/realm.podspec` — writes the machine-specific path into a sidecar
     script (`.realm_flutter_install_env.sh`) next to the podspec and references it with a
     constant relative path, so the podspec JSON is identical across machines.
   - `packages/realm/macos/realm.podspec` — uses a relative `touch` instead of an absolute path.

2. **Distribution as a static hosted-pub registry (not a git dependency).**
   Consuming this fork as a `git:` dependency drags in committed, dangling symlinks
   (`ios/realm_dart.xcframework -> ../../realm_dart/binary/ios/...`, plus android/linux/windows).
   In a fresh checkout those targets don't exist, and `dart run realm install` can't extract
   through a dangling symlink — `pod install` fails. The official publish pipeline strips those
   symlinks before packaging; we reproduce that and serve the result from a static pub registry.

## How distribution works

- We publish **only the `realm` package**. `realm_dart`, `realm_common`, etc. are consumed
  unchanged from pub.dev (`realm`'s pubspec depends on `realm_dart: ^20.2.0`).
- The registry is a **static "hosted pub repository"** served from this repo's GitHub Pages
  (`gh-pages` branch): `https://canarymail.github.io/realm-dart/`.
  - `api/packages/realm` — JSON version index (pub fetches this).
  - `archives/realm-<version>.tar.gz` — the package archive (symlinks stripped).
  - `.nojekyll` — disables Jekyll so Pages serves files as-is (without it, Jekyll tries to
    build the repo and chokes on the dangling symlink).
- Native binaries are **not** in the package. `realm install` downloads them at install time
  from `https://static.realm.io/downloads/dart/<version>/<os>.tar.gz`
  (`packages/realm_dart/lib/src/cli/install/install_command.dart`).

Consumers depend on it via a `dependency_overrides` (or direct) entry:

```yaml
realm:
  hosted: https://canarymail.github.io/realm-dart/
  version: 20.2.0
```

## Launching an updated package

From the repo root on `dove`:

```bash
# 1. Build the static registry (strips symlinks, pins to packages/realm/pubspec.yaml version).
tool/build_pub_registry.sh https://canarymail.github.io/realm-dart/
#    -> writes build/pub-registry/site/{.nojekyll, api/packages/realm, archives/realm-<v>.tar.gz}

# 2. Deploy that site to the gh-pages branch. Run in /tmp (NOT a subdir of this repo) so the
#    nested git repo can't accidentally operate on the main repo.
REMOTE="$(git remote get-url origin)"
rm -rf /tmp/realm-ghpages
cp -R build/pub-registry/site /tmp/realm-ghpages
cd /tmp/realm-ghpages
git init -q && git checkout -q -b gh-pages && git add -A
git commit -qm "Static pub registry: realm <version>"
git push -f "$REMOTE" gh-pages    # force: gh-pages is a generated branch, history is disposable
cd -

# 3. Verify (Pages rebuilds in ~1 min).
curl -s https://canarymail.github.io/realm-dart/api/packages/realm | head -c 200
curl -s -o /dev/null -w '%{http_code}\n' https://canarymail.github.io/realm-dart/archives/realm-20.2.0.tar.gz

# 4. In the consumer app: flutter pub get && (cd ios && pod install)
```

The `gh-pages` branch must contain **only** the site (the build script's output), never the
SDK source. If it ever ends up with the full repo, Pages will run Jekyll and fail on the symlink.

## Versioning — how to "increase" the version

The hard constraint: `realm install` builds the binary download URL from the **package version**
(`static.realm.io/downloads/dart/<version>/...`), and only **real upstream release versions**
exist there. So the published version must equal a version whose binaries exist on
`static.realm.io`. A made-up version like `20.2.1`, or a `+build`/`-prerelease` suffix
(`20.2.0+canary.1`), makes the binary download 404.

Practical options:

- **Track a new upstream release (the normal bump).** When upstream cuts e.g. `20.3.0`:
  rebase `dove` onto that tag, re-apply the two podspec edits, set `packages/realm/pubspec.yaml`
  `version: 20.3.0`, then rebuild + deploy. Binaries for `20.3.0` exist on `static.realm.io`,
  so it just works. This is the clean way to raise the version number.

- **Iterate our patch within the same upstream version (no number change).** Rebuild + redeploy
  the same version. The tarball hash changes (tar embeds mtimes), so existing consumers must run
  `flutter pub upgrade realm` to re-pin the new `sha256` in `pubspec.lock`. Don't invent a new
  version number for this — the binaries won't be there.

- **Full control over version numbers (heavier, only if really needed).** To publish arbitrary
  versions (e.g. `20.2.0+canary.N`) you'd also have to (a) fork + publish `realm_dart` to this
  registry and (b) change its install URL to a binary mirror you host (you can mirror the same
  `<os>.tar.gz` files onto this Pages site). Not currently done — avoid unless required.

Note: our registry's `20.2.0` and pub.dev's `20.2.0` are distinct to pub because they have
different hosted source URLs, so reusing the upstream number is fine.

## Gotchas

- **Apple's bundled rsync (2.6.9)** errors on the excluded dangling symlinks, so the build script
  copies with `cp -R` and dereferences valid symlinks manually — don't "simplify" it back to `rsync -L`.
- **`pubspec_overrides.yaml`** (melos path overrides) must never ship in the archive — the build
  script deletes it; otherwise consumers would try to resolve `realm_dart` from a local path.
- **GitHub Pages is public.** This fork is already public and the SDK is Apache-2.0, so nothing
  secret is exposed — but the registry is not access-controlled. For private hosting use a real
  private pub registry (Cloudsmith, self-hosted unpub, S3+auth).
- **Upstreaming.** The #1887 podspec fix is a good PR candidate. If it lands upstream, you can drop
  this registry entirely and go back to the official hosted `realm`.
