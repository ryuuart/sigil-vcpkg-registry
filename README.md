# sigil-vcpkg-registry

A [vcpkg git registry](https://learn.microsoft.com/vcpkg/produce/publish-to-a-git-registry)
hosting custom C/C++ packages ("ports"). Downstream projects reference this repo
as a registry source and pull in only the ports they list.

## Ports

| Port | Version | Upstream |
| --- | --- | --- |
| `choreograph` | 2016-07-21 | [sansumbrella/Choreograph](https://github.com/sansumbrella/Choreograph) |
| `diligent-engine` | 2026-07-22#2 (also 2.5.6) | [DiligentGraphics/DiligentEngine](https://github.com/DiligentGraphics/DiligentEngine) |
| `example-lib` | 1.0.0 | (template) |
| `libdatachannel` | 0.24.3#1 | [paullouisageneau/libdatachannel](https://github.com/paullouisageneau/libdatachannel) |
| `shader-slang` | 2026.17 | [shader-slang/slang](https://github.com/shader-slang/slang) |
| `skia` | 151#3 | [google/skia](https://skia.googlesource.com/skia) |
| `syphon` | 2025-10-06 | [Syphon/Syphon-Framework](https://github.com/Syphon/Syphon-Framework) |
| `yoga` | 3.2.1#1 | [facebook/yoga](https://github.com/facebook/yoga) |

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

Five of these deliberately shadow or diverge from what vcpkg ships upstream:

- **`shader-slang`** is vcpkg's builtin port — a downloader for the official
  release archives, not a build — carried forward to 2026.17. The builtin one
  stops at 2026.7.1, whose SPIR-V emitter writes no `NoContraction` decoration
  on any arithmetic even under `-fp-mode precise`; from 2026.13 the emitter
  decorates every scalar, vector and matrix float arithmetic result, which is
  what lets a kernel compiled once for the host and once for a device round the
  same way in both. A consumer only gets this version if `"shader-slang"` is
  listed in this registry's `packages` array.

  It also installs release binaries only. The distribution has one build of
  Slang and it is a release build; the builtin port copies it under the debug
  prefix as well, which leaves a second dylib of every Slang name beside the
  debug builds of other packages. A Debug link that resolves Slang from one
  prefix and a neighbour from the other has no ordering of the two directories
  that satisfies both, and CMake answers with a runtime-search-path cycle
  warning and no rpath. The imported targets name the release library for a
  Debug, RelWithDebInfo and MinSizeRel configuration instead.

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

  Its `avif` feature asks for `libavif[dav1d]`. libavif with no codec feature
  parses an AVIF container and decodes no frame from it, with no error at
  build, link or run time — so a decoder is part of what "AVIF support" means.

  Its raw codec is compiled with run-time type information on. Skia's `raw`
  target — `SkRawCodec.cpp`, built when the `dng` feature is on, which it is by
  default — carries `add_exceptions`, because the codec catches what the DNG SDK
  throws, over the `no_rtti` default every Skia target carries. A translation
  unit compiled with exceptions and without run-time type information emits a
  private, non-unique copy of the typeinfo of every standard exception type it
  names, and the linker satisfies every other object's reference to those names
  with that copy. The handler search compares a typeinfo by address, so in any
  binary linking `libskia.a` a `catch (const std::exception &)` matches nothing
  the standard library throws, and a process that wrote a handler for what it
  caught terminates instead. Skia's own dng_sdk target already pairs `add_rtti`
  with `add_exceptions`; the codec that catches from it is the omission, and the
  patch gives it the same pair. Leaving the raw codec out of the build instead
  would answer only for a consumer who does not want it, and leave the trap
  standing for one who asks for `dng`.

  Its exported config also differs from the builtin port's in how it states the
  link interface. Frameworks are resolved with `find_library` to the absolute
  path of the bundle, not left as the opaque flag string `-framework Foo`,
  which reaches the link line unsplit and which `swiftc` rejects; from a path
  CMake writes the spelling each driver wants. And a dependency whose vcpkg
  config exports an imported target — `PNG::PNG`, `ZLIB::ZLIB`, `JPEG::JPEG`,
  `expat::expat`, `WebP::*`, `freetype`, `harfbuzz::*`, `ICU::*`, `BZip2::BZip2`,
  `unofficial::brotli::*`, `avif`, `yuv` — is named by that target rather than
  flattened to an archive path. CMake de-duplicates targets against targets and
  paths against paths, never a target against a path, so a path here would meet
  the same archive named as a target by freetype's or OpenImageIO's config and
  both would reach the linker. A name with no such target falls back to the
  resolved path.
- **`libdatachannel`** is vcpkg's builtin port at the same upstream version,
  0.24.3, with one patch added and the port version bumped so that this copy
  shadows the builtin one. The library ends the whole process from threads it
  owns: the ICE state change that starts the DTLS transport throws when the
  handshake's first write fails, and the SCTP write callback throws when the
  protocol underneath is already shut down. Either throw travels up the C
  frames the library is called back through — libjuice's poll sweep under the
  first, usrsctp's under the second — where no frame of a consumer's stands, so
  nothing a consumer guards can catch it and the process aborts. The patch
  makes each one connection's failure reported through its state: a failed
  handshake start takes the Failed state that ICE callback already gives a
  route nobody found, and a write on a transport being torn down is refused
  with -1 the way its neighbours are. Two ICE agents completing on one poll
  sweep provoke the first, which is what two ends of a conversation in one
  process arrange; teardown provokes the second.

  Both guards are catch-alls. The library's own guards on these two paths catch
  `const std::exception &`, which matches nothing in an image that carries a
  hidden `typeinfo for std::exception` of its own — a static dependency
  compiled with hidden visibility emits one, and the handler search compares a
  type_info by address. Because the port name matches a builtin one, a consumer
  only gets this version if `"libdatachannel"` is listed in this registry's
  `packages` array.

- **`yoga`** is vcpkg's builtin port at the same upstream version, 3.2.1, with
  one patch added and the port version bumped so that this copy shadows the
  builtin one. Yoga's `cmake/project-defaults.cmake` compiles the library with
  exceptions enabled and run-time type information disabled, and ten of its
  objects throw or catch a standard exception. Each of them therefore emits a
  private, non-unique copy of that type's typeinfo, and the linker satisfies
  every other object's reference to the name with that copy — so in any binary
  linking `libyogacore.a` a `catch (const std::exception &)` matches nothing the
  standard library throws, because the handler search compares a typeinfo by
  address. The patch leaves run-time type information on and changes nothing
  else; exceptions stay as they are. Because the port name matches a builtin
  one, a consumer only gets this version if `"yoga"` is listed in this
  registry's `packages` array.

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

  Its `vulkan` feature depends on `volk`, and the config declares
  `unofficial::diligent-engine::volk` for it. The engine dispatches every
  Vulkan call through volk and carries its own copy, so nothing has to link
  that target to run; it exists for a process that replaces `volkInitialize`,
  which is how the engine is pointed at a loader the stock one cannot find —
  a leaf name and `/usr/local/lib` are all it tries, which on Apple Silicon
  misses the Homebrew MoltenVK and loader install. Replacing it means
  compiling `volk.c`, which the volk port installs beside `volk.h`, and the
  target carries the WSI definitions the engine's own volk was built with
  (`VK_USE_PLATFORM_METAL_EXT` on Apple, the Win32 and X11/Wayland ones
  elsewhere). Compiled with less, that volk is missing the surface entry point
  the engine calls, the engine's copy is pulled in beside it, and every loader
  symbol is then defined twice. The definitions travel on a target of their
  own rather than on `DiligentCore`, because `VK_USE_PLATFORM_WIN32_KHR` wants
  `windows.h` ahead of `vulkan.h` and the Linux ones want the X11 and Wayland
  headers. The volk port's static library is not linked: it is built with no
  platform definitions at all, so the engine's surface entry point would be
  missing from it too.

`skia`, `diligent-engine`, `libdatachannel` and `yoga` were build-tested on `arm64-osx`, and
`diligent-engine` also on `arm64-osx-dynamic`; other triplets are unverified. The Windows shared-library
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
