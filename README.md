# sigil-vcpkg-registry

A [vcpkg git registry](https://learn.microsoft.com/vcpkg/produce/publish-to-a-git-registry)
hosting custom C/C++ packages ("ports"). Downstream projects reference this repo
as a registry source and pull in only the ports they list.

## Ports

| Port | Version | Upstream |
| --- | --- | --- |
| `choreograph` | 2016-07-21 | [sansumbrella/Choreograph](https://github.com/sansumbrella/Choreograph) |
| `diligent-engine` | 2026-07-22 (also 2.5.6) | [DiligentGraphics/DiligentEngine](https://github.com/DiligentGraphics/DiligentEngine) |
| `example-lib` | 1.0.0 | (template) |
| `skia` | 151 | [google/skia](https://skia.googlesource.com/skia) |

`diligent-engine` is registered at two versions. The baseline is a snapshot of
the `master` branch, which is where Diligent lands finished work between its
infrequent releases — the last one, v2.5.6, is from September 2024, while master
carries API version 256020 against that tag's 255001. Master has no upstream
version number, so it is dated after the pinned commit, per vcpkg's convention
for an untagged snapshot. The v2.5.6 release is still registered and can be
selected with an exact pin:

```json
{ "overrides": [ { "name": "diligent-engine", "version": "2.5.6" } ] }
```

Note that the two use different version schemes (`date` and `relaxed`), which
vcpkg cannot order against each other. An exact `overrides` pin works, but a
`version>=` constraint spanning them fails with an incomparable-schemes error.

Two of these deliberately shadow or diverge from what vcpkg ships upstream:

- **`skia`** is a fork of vcpkg's builtin `skia` port, which tracks milestone
  148. This copy is bumped to the `chrome/m151` branch head, with the external
  revisions taken from that branch's `DEPS` and three of the upstream patches
  rebased. It also builds with `skia_use_partition_alloc=false`: m151 made the
  main target depend on `//src/partition_alloc:raw_ptr`, and honouring that
  would mean vendoring both PartitionAlloc and Chromium's `buildtools`, so the
  port takes Skia's own no-op `raw_ptr` instead (and thus does not define
  `SK_USE_PARTITION_ALLOC`). Because the port name matches a builtin one, a
  consumer only gets this version if `"skia"` is listed in this registry's
  `packages` array.

  It also adds a `default-visibility` feature that vcpkg's port does not have.
  Skia normally compiles with `-fvisibility=hidden`, so a static `libskia.a`
  linked into an executable exports only the `SK_API` surface. A plugin the host
  `dlopen`s therefore cannot resolve Skia's internals and has to link its own
  copy of the archive — leaving two Skia images in one process, each with its
  own `SkString::gEmptyRec`, so an `SkString` passed between them trips
  `SkString::validate()`. The feature rebuilds Skia with default visibility so
  one host can be the single Skia image for its plugins. It is opt-in because
  the cost is a much larger dynamic symbol table.
- **`diligent-engine`** has no upstream vcpkg port. It builds the DiligentCore,
  DiligentTools and DiligentFX modules, pinning each of the 17 nested submodules
  itself (only release archives bundle them), and adds the CMake package
  config that upstream does not provide. That config also carries Diligent's
  public compile definitions (`PLATFORM_*`, `*_SUPPORTED`), without which its
  headers refuse to compile. It honours the triplet's linkage: a dynamic triplet
  additionally installs the graphics backends as shared libraries, each with its
  own target. DiligentCore/Tools/FX are static archives either way, because
  upstream builds no shared flavour of them — so a dynamic install has the same
  shape as a system-wide install of Diligent. Samples and tutorials are not
  built, and the Metal and WebGPU backends are unavailable.

Both ports were build-tested on `arm64-osx`, and `diligent-engine` also on
`arm64-osx-dynamic`; other triplets are unverified. The Windows shared-library
path in particular is written from upstream's build rules rather than observed.

## Layout

```
ports/<port>/          # one directory per package
    vcpkg.json         #   manifest: name, version, dependencies
    portfile.cmake     #   how to fetch + build + install it
versions/
    baseline.json      #   the current "default" version of every port
    <letter>-/<port>.json  # per-port version history (git-tree pinned)
```

The `versions/` database is machine-generated — never hand-edit it. Each entry
pins a version to a **git-tree SHA**, so consumers fetch the exact committed
port directory, fully reproducibly.

## Consuming this registry (downstream project)

In the consuming project's **`vcpkg-configuration.json`**:

```json
{
  "default-registry": {
    "kind": "git",
    "repository": "https://github.com/your-org/builtin-baseline-repo",
    "baseline": "<commit-sha-of-vcpkg-repo>"
  },
  "registries": [
    {
      "kind": "git",
      "repository": "https://github.com/18nguyenl/sigil-vcpkg-registry",
      "baseline": "<latest-commit-sha-of-THIS-repo>",
      "packages": [ "example-lib" ]
    }
  ]
}
```

- `repository` — the GitHub URL of this repo (update after you push).
- `baseline` — the commit SHA in **this** repo whose `versions/baseline.json`
  the consumer should trust. Bump it to adopt newer port versions.
- `packages` — which ports resolve from this registry. vcpkg routes only these
  names here; everything else comes from the default registry.

Then list the port as a normal dependency in the project's **`vcpkg.json`**:

```json
{
  "name": "my-app",
  "version": "0.1.0",
  "dependencies": [ "example-lib" ]
}
```

`vcpkg install` (or a CMake toolchain configure) now pulls `example-lib` from here.

## Adding or updating a port (maintainer)

1. Copy `ports/example-lib/` to `ports/<your-port>/` and edit `vcpkg.json`
   (name, version, dependencies) and `portfile.cmake` (fetch + build).
2. Commit the port changes.
3. Regenerate the version database:

   ```sh
   vcpkg --x-builtin-ports-root=./ports \
         --x-builtin-registry-versions-dir=./versions \
         x-add-version <your-port>
   ```

   (Add `--overwrite-version` if you re-tagged an existing version.)
4. Commit the updated `versions/` files.
5. Push. Consumers pick up the change by bumping their `baseline` to your new
   commit SHA.

> The version database records a git-tree SHA of the port directory, so a port's
> files **must be committed before** `x-add-version` is run for that version.

## Requirements

- `vcpkg` on PATH (`VCPKG_ROOT` set) for `x-add-version` and local testing.
- Ports that build real sources typically depend on `vcpkg-cmake` /
  `vcpkg-cmake-config` (host dependencies), as the `example-lib` template does.
