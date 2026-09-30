# Crown

Crown is a minimal, fully sovereign systems programming language for agentic engineering, helping agents and people build, test, refactor, and maintain software with measurable quality.

Example application: [Crown GBA](https://github.com/MashDevel/crown-gba), a Game Boy Advance emulator written in Crown with macOS and Linux frontends.

The goal is a fully malleable programming language that gives agents and users full control over the binaries they generate.

## Implementation size

Minimality applies to the implementation as well as the language. Crown's [implementation](components) totals **~88k source lines**, covering its compiler, backend, native linker, standard library, platform integrations, and development tools. The comparison below matches the relevant compiler layers.

| Compiler layer | Crown source lines | Comparable upstream source lines |
| --- | --- | --- |
| Language analysis and lowering | **~38k** — [compiler](components/compiler/src), including parsing, semantic analysis, lowering, diagnostics, and built-in source tools | **~750k** — [Rust compiler](https://github.com/rust-lang/rust/tree/c1070d69382b8d2f2eb65119c738a77d9e324c9e/compiler), excluding backend adapter crates |
| Backend infrastructure, optimization, and machine-code generation | **~41k** — [backend](components/backend/src), excluding the native linker | **~2.8M** — [LLVM libraries and headers](https://github.com/llvm/llvm-project/tree/844f9339a276cf18b7aac38c89f02a0d42e2339b/llvm), retaining X86 and AArch64 target implementations plus shared infrastructure |

Crown's remaining **~10k lines** implement its native linker, libraries, platform integrations, and toolchain support. Rust's row excludes `rustc_codegen_*` and `rustc_llvm`; its standard library, Cargo, and external LLVM source are also outside that count. LLVM's row counts `llvm/lib` and `llvm/include`, excluding testing helpers and target implementation directories other than `X86` and `AArch64`. It excludes standalone tools, Clang, and LLD. Shared infrastructure is counted in full, rather than estimating which lines a particular build uses. These are comparisons by role; the projects differ in language features, optimizations, and platform support.

Rounded physical source lines from September 2026 snapshots, including comments and blank lines. Separate test, benchmark, example, fixture, and experimental directories, documentation, and build output are excluded.

## Design goals

A small language reduces what an agent needs to understand and the choices it needs to make. Built-in quality controls give concrete feedback on each change. An implementation that one can understand, modify, and own lets the language itself evolve with the work.

- **Minimal:** keep the language and toolchain small and coherent, with few concepts, consistent rules, and zero third-party package dependencies.
- **Sovereign and malleable:** give agents and users control over the language, compiler, standard library, and development tools, with the freedom to inspect, build, modify, and redistribute them under the [MIT License](LICENSE). Make language rules, code generation, runtime behavior, and linking understandable and open to change.
- **Quality checks built in:** include testing, line and branch coverage, cyclomatic and cognitive complexity checks, limits on code size and structure, duplication detection, and formatting in the toolchain. Give agents and people repeatable checks and machine-readable reports to guide their next change.
- **Memory-safe:** prevent invalid memory access and ownership violations in safe code, with explicit boundaries for unsafe operations and foreign interfaces.
- **Portable:** give the same safe program consistent behavior across supported platforms, with platform differences isolated behind explicit interfaces.

Minimality, sovereignty, memory safety, and portability support the central goal: making it easier to produce reliable software and keep improving it. Crown pursues these goals through explicit ownership, scoped loans and callbacks, value types, resources, interfaces, and generics. These are design goals under active implementation; passing tests and supporting multiple platforms do not establish a complete memory-safety guarantee.

The compiler is written in Crown and supports x86-64 and ARM64 on macOS and Linux. Assembly seeds are distributed as GitHub release assets; the repository contains their pinned SHA-256 checksums. The launcher, build tools, test runner, and release campaigns are also written in Crown. No Rust or Python toolchain is required.

Maintained implementation and test code outside `bootstrap/` is Crown, with six explicit C ABI fixtures as the exception. The three C files in `components/compiler/tests/platform/linux`, two in `components/compiler/tests/fixtures/arm64_macos`, and one in `components/backend/tests/fixtures/windows` independently check C calling conventions, external-object linking, and system-header layouts. They are validation inputs, not compiler or library implementation. The `toolchain_source_language` test checks this boundary; manifests, documentation, reference data, and generated build output are not implementation code.

Crown is under active development. Its language, CLI, manifest format, and generated-code ABI may change as the design improves.

Functions without a result use `-> void` and can exit with a bare `return`. The empty value `()` remains available for generic values such as `Ok(())` in `Result<void, Error>`.

## Requirements

- An x86-64 or ARM64 macOS host, or an x86-64 or ARM64 Linux host using glibc
- For bootstrap only: Xcode command-line tools on macOS, or a C compiler and system assembler/linker on Linux
- The host's standard shell, core utilities, and OS libraries
- For downloading a seed: `curl` and `gzip`, or an offline copy of the release assets

| OS | CPU | Compiler host and bootstrap | Executable target |
| --- | --- | --- | --- |
| macOS | x86-64 | Implemented | Mach-O |
| Linux (glibc) | x86-64 | Implemented | ELF |
| Linux (glibc) | ARM64 / AArch64 | Implemented | ELF |
| macOS | ARM64 / Apple Silicon | Implemented | Mach-O |

All four native host combinations are built and tested in [CI](https://github.com/MashDevel/crown-lang/actions/workflows/test.yml).

Ordinary builds encode machine code and link Mach-O or ELF executables entirely in Crown. The system compiler assembles and links the seed during bootstrap. Crown has no third-party package or LLVM dependency; generated programs use the host's OS libraries, including libSystem on macOS and glibc on Linux. Native-root ownership, supplied-stack threads, coverage instrumentation, and the allocation auditor are implemented in Crown.

## Start

Install the current binary release on macOS or glibc Linux, on x86-64 or ARM64:

```sh
curl -fsSL https://raw.githubusercontent.com/MashDevel/crown-lang/main/install.sh | sh
```

The installer detects the host, downloads the matching compiler with its bundled library sources, verifies the release archive's SHA-256 checksum, and configures PATH. It does not build Crown or require a C compiler. NixOS loader setup is automatic: when needed, the installer obtains `patchelf` through Nix and adjusts the downloaded binary to the native loader. Other Linux distributions and macOS do not need this step.

The default destination is `${XDG_DATA_HOME:-$HOME/.local/share}/crown`. Set `CROWN_INSTALL_DIR` to choose another directory or `CROWN_RELEASE` to select a published release tag. For offline installation, set `CROWN_RELEASE` and `CROWN_RELEASE_ASSETS` to a directory containing the host archive and `SHA256SUMS`. The compiler stays together with the library sources from its release; a source checkout is not required.

PATH setup supports zsh (`${ZDOTDIR:-$HOME}/.zshrc`) and bash (`~/.bashrc` and the first existing login profile, or `~/.bash_profile`). Existing settings are preserved, and repeated installation does not duplicate the entry. Open a new shell, or run the `export PATH=...` command printed by the installer, then run `crown --version`. No manual `CROWN_ROOT` setting is needed. To uninstall, remove the reported PATH entries and installation directory.

You can also download and unpack a host archive from [Releases](https://github.com/MashDevel/crown-lang/releases), then run `sh bootstrap/install` inside it. This uses the archive's compiler directly. From a source checkout, the same command downloads the current binary release. To explicitly build the checkout from its assembly seed instead, with a system C compiler available:

```sh
sh bootstrap/install --source
```

For source development without changing your shell configuration:

```sh
sh bootstrap/fetch
./bootstrap/crown --version
```

`bootstrap/fetch` downloads the host's seed from the release named in `bootstrap/seed-release`, verifies it against `bootstrap/locks/<host>.json`, and installs it into the ignored `bootstrap/<host>` directory. It verifies existing seeds without downloading them again. For offline installation, set `CROWN_BOOTSTRAP_ASSETS` to a directory containing the pinned release assets. A mismatched or partially installed seed is an error; remove that generated host directory before fetching a clean copy.

The launcher builds the current checkout once when its compiler is missing or stale, then caches that compiler. An existing verified compiler can be reused without rebuilding. Use `./bootstrap/crown bootstrap --force` for the full self-rebuild verification used by releases. Save this program as `hello.cwn`:

```crown
fn main() -> u32 {
    print(42)
    return 0
}
```

Run it with `./bootstrap/crown run hello.cwn -o target/hello`; it prints `42`.

The generated compiler lives in `target/bootstrap/crown`. Keep the source tree and `bootstrap` directory together. All `target` directories are disposable build output.

## Commands

```text
./bootstrap/crown parse <sources-or-project>
./bootstrap/crown check [<sources-or-project>] [--max-instances <count>]
./bootstrap/crown compile <output.s> <sources-or-project> [--max-instances <count>]
./bootstrap/crown build [<source-or-project>] [-o <executable>]
./bootstrap/crown run [<source-or-project>] [-- <arguments>]
./bootstrap/crown fmt [<sources-or-project>] [--check]
./bootstrap/crown lint [<sources-or-project>] [--output <metrics.json>]
./bootstrap/crown duplication [<paths>] [--output <clones.json>]
./bootstrap/crown coverage <directories...> [--output <report.json>]
./bootstrap/crown bootstrap [--output <directory>] [--force]
./bootstrap/crown refresh-seed
./bootstrap/crown test [project] [--filter <name>] [--jobs 1..4] [--coverage <directory>]
./bootstrap/crown release [--seed <integer>] [--output <directory>]
./bootstrap/crown benchmark [--runs <count>] [--jobs 1..4]
```

`check`, `build`, and `run` default to the current project. `build` accepts a project or one `.cwn` file; a single file requires `-o`. Project executables default to `target/debug/<package-name>` within the project. `run` forwards arguments after `--`, including empty arguments and paths containing spaces.

`test` without a project runs Crown's compiler suite. `test <project>` builds and runs the Crown test project at `<project>/tests/Crown.toml`. The test executable receives the compiler path, project directory, output directory, filter, coverage directory, and job count after its executable name. It reports test failures through its process exit status. Project test suites can use the shared toolchain and standard library to build fixtures and verify results.

Builds reuse an executable only when its compiler, sources, link inputs, options, and output contents match the build record. A failed compilation preserves the previous executable.

Build records are published by atomic replacement; an existing record symlink is replaced without writing through it. Build tools trust their compiler, source checkout, output directories, environment, and operating-system libraries. Release checksums protect the download against changes relative to the trusted checkout; cache hashes do not authenticate an attacker-controlled compiler and matching metadata.

Build and run accept repeated `--object <path>`, `--framework <name>`, and `--library <name>` options. Crown's native linkers support coverage builds and x86-64 and ARM64 Mach-O and ELF object inputs. Frameworks apply to macOS. `CC` configures bootstrap only; ordinary builds do not invoke it. The default generic instance budget is 128; `--max-instances` accepts a positive unsigned 64-bit integer.

Run `./bootstrap/crown help <command>` for command usage.

## Projects

A project contains `Crown.toml`:

```toml
[package]
name = "hello_crown"
source = "src"
```

Use exactly one of `source = "src"` or `sources = ["src", "shared"]`. These are the project's own relative files or directories; directories expand recursively in stable filename order. Duplicate source files are loaded once. `exclude = ["src/platform"]` removes files or directories from the expansion. Missing sources and empty source sets are errors.

The standard library is available automatically, including in single-file programs. Crown resolves it from its toolchain installation, so a project can live anywhere. The bootstrap launcher selects its checkout; a packaged compiler finds the distribution around its executable, including through PATH or a symlink. Set `CROWN_ROOT` to explicitly select a distribution. Keep the compiler and its bundled library sources together.

Optional toolchain libraries use stable names:

```toml
[toolchain]
libraries = ["platform", "integrations"]
```

`platform` supplies native API bindings. `integrations` supplies audio and Steam integrations and includes `platform`. `toolchain` supplies host tooling for development tools and project test runners. These are bundled source libraries, not downloaded packages. Unknown names and duplicate entries are errors. For standalone files, repeat `--toolchain-library <name>` on `parse`, `check`, `compile`, `build`, `run`, or `lint`.

Build caches include resolved library files and their contents. Library sources are always type-checked, while lint and coverage measure the project's own sources. Library implementation is measured when selected as source in its own project. Workspace duplication scans all included source and test files, including libraries, as one corpus.

Package names contain ASCII letters, digits, `-`, or `_`. Platform-specific link settings use:

```toml
[target.macos]
frameworks = ["AppKit", "Foundation"]
libraries = ["objc"]

[target.linux]
libraries = ["m"]
```

Unknown sections and keys are errors. Source paths may refer to shared sibling directories.

Library and framework names accept ASCII letters, digits, `-`, `_`, `.`, and `+`. Names must be nonempty and cannot be `.` or `..`; paths and loader directives are rejected.

## Layout

| Directory | Contents |
| --- | --- |
| `components/compiler/src` | Crown frontend, ownership checker, AST-to-IR lowering, and compiler driver |
| `components/backend/src` | IR, verification, optimization, profiling, machine-code generation, object formats, and linking |
| `components/backend/tests/unit` | Backend, IR, optimizer, and profiling tests, registered in the shared compiler gate |
| `components/compiler/tests` | Compiler unit programs, language conformance cases, fixtures, and runtime checks |
| `bootstrap/crown` | Source bootstrap launcher |
| `bootstrap/locks` | Pinned release asset checksums for all six hosts |
| `bootstrap/<host>` | Downloaded assembly seed and provenance manifest; ignored by Git |
| `components/toolchain/src` | Crown host services, manifest loading, build caching, CLI, and bootstrap |
| `components/toolchain/tests` | Crown tooling unit and integration tests |
| `components/library` | Shared Crown byte, C-string, and file helpers |

The compiler lowers Crown into the backend's IR. The backend has no dependency on the frontend. The compiler's `Crown.toml` includes the backend component, and the shared test gate runs both components' tests.

## Validation

```sh
./bootstrap/crown test
```

The full gate starts through the bootstrap launcher and runs the Crown test registry. The registry checks the compiler, tests project tooling and compiler algorithms, runs accepted/rejected and runtime fixtures, verifies diagnostics, and tests the shared library. A failed case does not prevent later registered cases from running.

For native platform validation, run `./bootstrap/crown bootstrap --force` before the full gate. Bootstrap checks that successive rebuilds produce identical assembly and executable bytes. Run `./bootstrap/crown test` and `./bootstrap/crown release --seed 20260926`, then use `CC=/unavailable target/bootstrap/crown build hello.cwn -o target/hello` and run `target/hello` to confirm ordinary builds use Crown's own backend and linker. The test output includes `applicability.json`, which records every selected case and identifies tests that require another host.

Before a compiler release, also run the reproducible arithmetic, state-machine, allocation, malformed-source, and syntax-depth campaigns:

```sh
./bootstrap/crown test && ./bootstrap/crown release
```

This runs `./bootstrap/crown test` first and writes stress results, the random seed, and the compiler hash to `target/release/results.json`. The numeric and state-machine expected results are immutable, SHA-256 checked reference tables generated by the former independent Python models. `--seed <integer>` controls reproducible malformed-input mutations.

Focused checks:

```sh
./bootstrap/crown test --filter toolchain_
./bootstrap/crown test --filter ownership
./bootstrap/crown run components/library/tests -- target/library-roundtrip.bin
```

Quality controls are part of the toolchain. `lint` checks file and function length, cyclomatic and cognitive complexity, nesting depth, and parameter count. `duplication` checks repeated code across the supplied paths. Both commands fail when configured limits are exceeded and can emit JSON reports. `fmt --check` checks formatting without rewriting files. Configure structural limits, duplication limits, and formatting in [Crown.toml](Crown.toml).

Run `./bootstrap/crown test --coverage target/coverage` to collect coverage, then `./bootstrap/crown coverage target/coverage --output target/coverage.json` to produce a JSON report with missed lines and branches. The coverage command fails when there are no recorded executions or any reported package falls below 95% line or branch coverage. Together, these commands give agents a repeatable way to check a change, find gaps, and iterate.

Auxiliary tools and their tests are also Crown. Run the Unicode table generator with `./bootstrap/crown run components/library/tools/unicode -- INPUT_DIRECTORY [OUTPUT_DIRECTORY]`. Run the QEMU guest-agent client with `./bootstrap/crown run components/compiler/tests/platform/guest -- --socket SOCKET --execute COMMAND`. The client also accepts `--wait-pid PID`, `--upload FILE --destination PATH`, and `--timeout SECONDS`; execute and wait-pid are mutually exclusive. It preserves binary output and returns the guest command's exit status. Uploads can be combined with execution or used alone.

The normal test gate includes the Unicode generator, guest client, bootstrap digest reader, library layout, and source-language boundary checks. The `synchronization_native_failures` case checks real successful operations and injected failures in optimized and unoptimized code. Native synchronization failures must abort with `synchronization failed` before entering protected code or continuing cleanup.

Compatible unit tests share an executable, while each test still runs in its own process. Compiled tests are cached by compiler contents, sources, target, options, and native link inputs; changing one unit rebuilds its group. Every selected test executes on every invocation. Compiler builds are cached in `target/bootstrap-cache` with separate keys for ordinary builds and verified fixed points. An ordinary build cannot satisfy a verification request; `bootstrap --force` always performs the fixed-point rebuild.

## GitHub Actions and releases

Pushes and pull requests run the full test registry on x86-64 and ARM64 Windows, Linux, and macOS in one native matrix. CI downloads a pinned release compiler, verifies its SHA-256, and builds the checkout once when its compiler cache is stale. It then runs formatting, lint, and tests directly with the prepared compiler. Releases and weekly runs retain the full fixed-point rebuild. CI uses four workers on Linux and Intel macOS, and three on Apple Silicon and Windows.

CI preserves pinned bootstrap assets, compiler builds, and compiled tests between runs, including successfully built artifacts from a failed test run. Caches are separated by host and runner image; Crown verifies individual cached artifacts before reuse. Cache transfers have a five-minute timeout and do not fail validation. Branch runs finish and save their caches before the next run starts; newer pull request runs cancel outdated ones. Weekly runs and the manual coverage option collect coverage and enforce the existing 95% thresholds. Coverage is currently below those thresholds, so those jobs are expected to fail until the gaps are closed.

Linux CI disables automatic crash-report collection and core files for tests that deliberately trap. The full registry still checks their termination status and expected diagnostics, then verifies that no Ubuntu crash reporters remain. Release stress campaigns have a 15-minute step limit; Unix jobs also record process and memory activity every 30 seconds.

Push a version tag such as `v0.1.0`, or dispatch the Release workflow with an existing version tag. Each native job rebuilds the compiler to a fixed point, runs the full registry and release campaigns, refreshes its seed, and tests a packaged compiler with `CC=/unavailable`. Only after all six jobs succeed does the publishing job create and publish the GitHub release.

Each release contains `crown-<host>.tar.gz`, compressed bootstrap assembly, a provenance manifest, a lock file, and `SHA256SUMS`. Compiler archives include the source tree and native seed; extract one, enter its directory, and use `./crown` (`.\crown.exe` in Windows PowerShell). Use `./bootstrap/crown` when developing the compiler so source changes trigger rebuilding. Linux archives target glibc systems compatible with the Ubuntu 24.04 build host. macOS archives are built and tested on macOS 15.

To advance the seed pin, download all six hosts' assets from a successful release, verify `SHA256SUMS`, copy each `crown-bootstrap-<host>.lock.json` to `bootstrap/locks/<host>.json`, and put the release tag in `bootstrap/seed-release`. Commit those small files; assembly and compiler binaries stay in release assets. The `bootstrap-20260930` release supplies verified compiler and assembly seeds for all six hosts, including complete source trees and native Windows executables.

For installer QA, run `sh bootstrap/tests/run` to verify startup-file preservation, repeated installation, shell selection, quoted checkout paths, and failure handling in temporary home directories. Verify release checksum failures, all four host selections, packaged installation without downloads, and the explicit `--source` mode. On NixOS, install outside a development shell with no compiler or patcher on PATH and confirm automatic loader setup. Run the one-command installer with `CC=/unavailable`, open a new terminal, and confirm `crown --version` and `crown run /absolute/path/to/hello.cwn` work outside the checkout without setting `CROWN_ROOT`.

For Windows bootstrap QA, run `bootstrap/tests/windows-assets.ps1` through Windows PowerShell to check both target pins, cache reuse, corrupted assets, installation locks, invalid repository/tag values, and cleanup after failed downloads. After packaging, run `bootstrap/tests/windows-distribution.ps1 -Assets target/dist` to fetch and execute the real compiler from its verified archive.

For bootstrap and release QA, run `sh bootstrap/tests/run`, then fetch a seed into a fresh checkout and run `./bootstrap/crown bootstrap --force` and `./bootstrap/crown test`. Repeat the tests to exercise cache reuse, including after a test failure; every selected test must still execute. Corrupt a downloaded seed and confirm `bootstrap/fetch` rejects it. Verify that a failing matrix job prevents publication and that downloaded archives build and run `bootstrap/tests/fixtures/hello.cwn` without a system compiler. Archive entries must have numeric owner and group zero and contain only tracked source plus the compiler, revision, and host seed.

Run the ordinary launcher twice and check that the second invocation reuses its compiler. After changing a compiler source, the launcher must perform one native build. An explicit `bootstrap --force` must still rebuild and compare successive stages even when an ordinary build is cached. A failed verification must preserve the last usable compiler.

## Platform targets

Windows x86-64 and ARM64 use Crown's code generators, Windows calling conventions, and PE linker. Cross-build with `crown build hello.cwn --target x86_64-windows -o hello.exe` or `--target arm64-windows`. Native Windows CI checks compiler self-hosting, host services, the standard library, and the complete applicable test registry. Source selection supports `.windows.cwn` and architecture-specific Windows suffixes. Normal builds use Windows system DLLs without an external compiler or linker.

Windows checkout bootstrap uses `powershell.exe -NoProfile -ExecutionPolicy Bypass -File bootstrap/crown.ps1`. Assembly seed recovery and fixed-point bootstrap currently require Clang, LLD, and Windows SDK libraries. Windows uses `powershell.exe -NoProfile -ExecutionPolicy Bypass -File bootstrap/fetch.ps1` to fetch and verify its pinned compiler and assembly seed. All six native targets share the same CI matrix, caching, format/lint checks, test registry, optional coverage gate, and release packaging. The registry checks cross-target code generation on all hosts and builds and executes all seventeen PE/ABI fixtures on each native Windows host. The shell installer currently configures macOS and Linux shells; Windows release archives provide `crown.exe` directly.

Linux ARM64 uses Crown’s ARMv8-A instruction encoder, AAPCS64 calling convention, runtime, and ELF linker. It supports ordinary compilation, supplied-stack threads, native-root ownership, coverage, and profiling. Pass `--target arm64-linux` to cross-compile; cross-linking requires the target’s glibc libraries and loader through `CROWN_LINUX_LIBRARY_PATH` and `CROWN_LINUX_INTERPRETER`.

Apple Silicon uses the Darwin ARM64 calling convention, Mach-O object reader and linker, and Crown-generated ad-hoc code signatures. Use `crown build hello.cwn -o target/hello-arm64 --target arm64-macos` on macOS to cross-build; `compile target/hello-arm64.s hello.cwn --target arm64-macos` emits assembly for Apple’s assembler. Linking uses macOS system library metadata. GitHub Actions checks native execution and a self-hosting fixed-point rebuild on both ARM64 platforms. Release publication additionally requires the stress campaigns to pass on every platform.

C foreign declarations can mark a typed variadic tail, for example `fn raw_open(path: RawPtr<u8>, flags: i32, ...mode: u16) -> i32 = "open"`. Calls still supply the declared number and types of arguments. Crown applies C default promotions to the tail and uses each target’s variadic calling convention.

Source selection also accepts `.x86_64.cwn`, `.arm64.cwn`, and combined suffixes such as `.arm64.macos.cwn`.

Linux x86-64 executables are available with `crown build <project-or-source> -o <output> --target x86_64-linux`; `compile output.s` emits assembly instead. Source discovery selects `.linux.cwn` or `.macos.cwn` files for the requested target, and manifests may define `[target.linux] libraries = [...]`. Linux assembly uses ELF sections and unprefixed C symbols, including the coverage runtime.

Native Linux builds discover the dynamic loader from the running compiler, including its Nix store path on NixOS. Cross builds need the target system's shared libraries: set `CROWN_LINUX_LIBRARY_PATH` to their colon-separated directories and `CROWN_LINUX_INTERPRETER` to the loader's absolute path on the target. Crown reads the target libraries to resolve imports and symbol versions; their contents participate in the build cache. Linux support currently targets glibc, not musl.

Bedrock uses the same compiler project and command parser. Inside Bedrock, use `crown check hello.cwn` and `crown build hello.cwn -o hello.elf`; project builds also support their default `target/debug/<package-name>` output. The guest supports `check`, `build`, help, and version reporting. Its native ELF linker lives under `components/backend/src/link/bedrock` and uses `/apps/runtime/crown.elf`. On the development host, `crown build <project-or-source> --target x86_64-bedrock -o <output>` uses the same linker; set `CROWN_BEDROCK_RUNTIME` to the built Bedrock runtime ELF. External linker options and coverage instrumentation are rejected for native Bedrock executable builds.

Run both native linker suites through `./bootstrap/crown test --filter native_linker`. Bedrock is a separate operating-system project; its runtime and guest integration tests are not included in this repository.
