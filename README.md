# sigil-vcpkg-registry

A [vcpkg git registry](https://learn.microsoft.com/vcpkg/produce/publish-to-a-git-registry)
hosting custom C/C++ packages ("ports"). Downstream projects reference this repo
as a registry source and pull in only the ports they list.

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
