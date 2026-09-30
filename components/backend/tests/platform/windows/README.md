# Windows backend validation

This project generates native x86-64 and ARM64 Windows executable fixtures with Crown's code generators and PE linker. The shared native matrix rebuilds Crown on each Windows runner and runs host, standard-library, and full-registry tests. Native execution remains required before claiming complete support.

From a supported Crown host, build and run the generator:

```sh
./bootstrap/crown build components/backend/tests/platform/windows -o target/windows/generate
target/windows/generate target/windows/images
```

Inspect the files with a PE-aware binary inspection tool. Confirm their respective AMD64 and ARM64 machine types, PE32+ headers, section permissions and alignment, `KERNEL32.dll!ExitProcess` imports, and base relocations. The CRT fixture also imports `msvcrt.dll!_scprintf`.

Run every `x86_64-windows*.exe` file on native x64 Windows and every `arm64-windows*.exe` file on native ARM64 Windows. The generator produces fifteen files for each architecture; The native registry test adds two compiled from Crown source. The supplied-stack language program must exit with status 0; the other sixteen must exit with status 42 within 30 seconds. The native matrix checks the host architecture before the registry executes its matching fixtures.

The fixtures cover process exit, mixed integer/floating-point calls, variadic calls, four-, sixteen-, and twenty-four-byte aggregate arguments and returns, large stack frames and outgoing copies, 128-bit integer arguments and returns, and a variadic Windows CRT call. The capture fixture keeps twelve scalar parameters live across an indirect aggregate capture to detect scratch-register corruption. Aggregate callees mutate their local argument; the caller verifies its original value is preserved. The CRT fixture formats an integer and a floating-point value through the system DLL, checking interoperability independently of Crown's own callee implementation.

The shared test registry also checks PE headers, import thunks, call and absolute relocations, malformed input rejection, and relocation boundaries. Run it with `./bootstrap/crown test --filter windows_pe_`. Run `./bootstrap/crown test --filter windows_abi` for ABI classification, stack-probe encoding, aggregate reclassification, invalid layouts, and executable call tests on the current host architecture.

Windows builds now use the Windows ABI and PE linker, with UTF-8 argument conversion, binary standard streams, CRT exit, thread and lock helpers, Unicode file and DLL APIs, and native host services. Coverage and profiling use native Windows file mappings. Import-library ingestion, compiler-generated unwind metadata, Windows distribution packaging, and successful execution of the complete native registry remain outstanding.

The COFF fixture links a Clang-generated native function which calls back into Crown code. Its `.pdata` record must appear in the PE exception directory; x86-64 also carries `.xdata`, while the ARM64 fixture uses packed unwind data. The source and object files are in `../../fixtures/windows`. Regenerate them with `clang --target=x86_64-pc-windows-msvc -c -O1 native.c -o native-x86_64.obj` and `clang --target=aarch64-pc-windows-msvc -c -O1 native.c -o native-arm64.obj`.

The lock fixture exercises mutex and shared/exclusive reader-writer operations against Windows SRW locks. The thread fixture starts four CRT-managed threads, performs 4,000 mutex-protected increments, joins every thread, and verifies each pointer result. Run `./bootstrap/crown test --filter windows_platform_runtime` for the generated helper IR, API failure cases, and executable mock tests on the current host.

The ownership fixture registers a root, rejects an incompatible type, acquires the correct type, closes the root while a lease is live, and verifies destruction is deferred until release. It then rejects the stale token. Its destructor and deallocation probe use the Windows calling convention. Run `./bootstrap/crown test --filter windows_root_runtime` for the host-executable regression.

The supplied-stack fixture executes a callback on a separate stack and verifies that its local storage lies in that buffer and the thread stack bounds are restored. The Crown-source fixture checks Unicode and empty arguments, vector allocation, builtin printing, typed variadic `printf`, and process exit. Its stdout must be `4950\n-8 1.5 ok 2147483648\n`. The formatter tests exercise empty, mixed integer/floating-point/pointer, and stack-passed argument lists against generated UCRT mocks. Host-service tests cover Unicode paths and environment variables, directory enumeration, file replacement and locking, child argument quoting, redirected streams, and timeouts.

The foreign output-pointer and scalar-write conformance cases use standard C `strtod` and `frexp`, so the same pointer-passing assertions run on all six native targets. The `foreign_realpath_default_version` case is explicitly limited to Unix hosts because it verifies the POSIX `realpath` symbol, which Windows does not provide. Its host applicability is recorded in the registry report.

The formatter regression also uses placeholder foreign imports and indirect calls, matching frontend lowering. Verify zero, two, and eight promoted arguments; changing the wrapper back to the placeholder signature must fail. Run `crown test --filter toolchain_project_libraries` to check executable discovery through PATH, including a nonexecutable candidate before the compiler and automatic `.exe` selection on Windows. Run `crown test --filter native_host_services` and `crown test --filter toolchain_build_cache` to check Unicode directory links, rejected link paths, link cycles, and safe cache-record replacement through ordinary and dangling links.

Run `crown test --filter windows_platform_runtime` for instrumentation startup, Unicode output filenames, random-name collisions, retry exhaustion, API failures, handle cleanup, bitmap word boundaries, and saturating profile counters. Run `crown test --filter toolchain_cli_coverage` and `crown test --filter toolchain_cli_optimization` on each native Windows architecture to verify actual file mappings, counter collection after an abort, concurrent counters, and initialization failures before application entry. Instrumentation must not import POSIX file or mapping functions.

Run `crown test --filter platform_guest_tools` for the guest protocol over native local sockets. Windows uses Winsock AF_UNIX streams with UTF-8 paths and millisecond timeouts; the tests establish a real listener/client connection and exercise framed transfers, closed peers, and invalid paths. Run `crown test --filter toolchain_auxiliary_cli` to verify that the guest tool builds through the public compiler command.

Run `crown test --filter benchmark_reports` to verify native benchmark workers, persisted exit statuses and timings, descendant CPU usage, missing commands, and timeouts. Unix collects usage from the specific child with `wait4`; Windows queries the child's job object. Compiler measurements use response files so complete source lists fit Windows process limits. Run `crown test --filter native_toolchain_tests_build_bootstrap` to check that saved compiler stages preserve and execute native binary bytes.

## Windows bootstrap and recovery

Use `powershell.exe -NoProfile -ExecutionPolicy Bypass -File bootstrap/crown.ps1 --version` from a checkout with a verified native seed. The launcher checks the seed SHA-256 and cache provenance before rebuilding the current checkout. Normal builds use Crown's native backend and PE linker. Assembly seed recovery and fixed-point verification currently require Clang, LLD, and the Windows SDK libraries. The assembly bootstrap uses standard static CRT startup to initialize the memory routines before entering Crown.

On each native Windows architecture, run `target/windows/crown.exe refresh-seed`, then `target/windows/crown.exe bootstrap --force`. Require identical assembly and executable bytes across successive rebuilds. Run `powershell.exe -NoProfile -ExecutionPolicy Bypass -File bootstrap/tests/windows-host.ps1 -Expected x86_64-windows` (use `arm64-windows` on ARM64) to check both supported host selections and rejection of unsupported systems and architectures.

Run the registry filters `windows_coff_assembly`, `native_toolchain_tests_build_bootstrap`, `native_toolchain_tests_build_refresh`, `toolchain_cli_bootstrap_metadata`, and `toolchain_cli_recovery`. Check cold startup, corrupted and stale binaries, invalid metadata, seed tampering, paths containing spaces, and isolation from a configured global cache. The PowerShell launcher uses UTF-8 JSON response files to preserve empty and Unicode arguments and avoid the Windows command-line size limit.

Run `bootstrap/tests/windows-metadata.ps1` through Windows PowerShell to check known SHA-256 values for nonempty and empty files, missing input files, accepted cache records, malformed metadata, missing records, and changed compiler bytes. Host detection reads the native processor through CIM so an emulated PowerShell process cannot select a different architecture.

Run `crown test --filter windows_native_images` on native Windows to generate and execute all seventeen PE/ABI fixtures through the shared registry. The test checks timeouts, exit statuses, stderr, and the Unicode/empty-argument language fixture output. Windows has no separate prerequisite CI build job.
