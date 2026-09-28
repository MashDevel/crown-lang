The shared library is ordinary Crown source under `module std`. It adds no compiler builtins, package manager, or dependencies. Projects select the files through their existing `Crown.toml` source list; the compiler includes the library this way.

For a project beside `library`, include its sources with:

```toml
sources = ["src", "../library/src"]
```

| Module | Operations |
| --- | --- |
| `std::bytes` | Filled buffers, append, clone, and checked little-endian reads and writes |
| `std::cstr` | NUL validation, UTF-8 byte encoding, and an owning opaque `CString` |
| `std::io` | Opaque files, whole-file byte/text I/O, exact reads, complete writes, explicit close, and named errors |
| `std::map` | Generic hash map with owned keys and values, replacement, removal, and scoped access callbacks |
| `std::sequence` | Borrowed traversal, cloning and appending with an explicit clone callback, equality with a comparator, and in-place heapsort |
| `std::text` | Borrowed UTF-8 comparison, search, joining, splitting, hashing, unsigned parsing, and full-width integer formatting |
| `std::parse` | Borrowed UTF-8 byte cursor, ASCII identifiers and integers, checked spans, and recoverable errors |

`bytes` operates on `Vec<u8>` and borrowed `Slice<u8>` values. Out-of-bounds access follows Crown's checked indexing rules. `cstr::encode` accepts text without NUL bytes, preserves its UTF-8 bytes, and appends one terminator. Empty input is valid. `cstr::is_terminated` instead checks an already-terminated text view and rejects embedded NULs. `cstr::new` encapsulates encoded bytes in a `CString`.

`cstr::as_raw` requires unsafe code. Its pointer stays valid only while the owning `CString` remains alive; callers must preserve its bytes and termination invariant. The same lifetime and bounds responsibilities apply to the unsafe raw I/O helpers. Normal callers use the safe file functions.

`std::dylib::open` requires an explicit unsafe block. Loading a library can execute foreign initializers before the call returns, and dropping the library can execute foreign finalizers. The caller must trust the library and its dependencies, their initialization and finalization behavior, and the loader's search environment. Symbols obtained through `std::dylib::slot` must have the declared calling convention and types, and must not outlive the library.

`io::open` accepts `Mode::Read()` or `Mode::Write()`. Opening for writing truncates the destination. File operations that change the cursor require a writable file loan. Explicit close invalidates the handle even if the host reports a close error; the destructor closes a live handle once. Operations on a closed file return an error. Read/write loops handle short transfers, and whole-file writes report close errors. File input uses the host's seekable-file interface; streams are outside this initial API.

`io::read_file` returns `Result<Vec<u8>, Error>`. `write_file` accepts borrowed bytes and `write_text` accepts borrowed text, including embedded NUL bytes. Error variants distinguish invalid paths, open, seek, read, write, and close failures. No operation prints an error on the caller's behalf.

`map::new` accepts a hash function and an equality function. Equal keys must have the same hash, and their hash/equality behavior must stay stable while stored. `insert` returns the previous value when a key already exists, retaining the original key and destroying the replacement key. `remove` returns the owned value and destroys its key. `clear` destroys all entries. Lookup and insertion have expected constant cost with a suitable hash; collisions can make them linear. Bucket growth moves entries without copying or destroying their payloads. Iteration order is unspecified.

`with_value(map, key, callback)` returns `Option<R>` by calling `scoped fn(read V) -> R` under a loan. `with_value_mut(map, key, callback)` accepts `scoped fn(write V) -> R`. `for_each(map, callback)` supplies read access to every key and value. These callbacks explicitly capture surrounding state with `fn[read input, write output](...)`; no context argument is required. Keys and values may be resources or other move-only types. A general map queries with its key type. `TextMap<V>` supports allocation-free `TextView` queries with `with_text_value`, `with_text_value_mut`, `text_contains`, and `text_remove`; construct it with `new_text` and insert owned keys with `text_insert`.

Use `parse::with_parser(bytes, callback)` to construct and borrow a parser inside the library, or construct `parse::Parser { data: bytes, position: 0 }` locally inside an input loan. The scoped callback may capture surrounding state and return an owned result. The parser owns no input and performs no allocation. Its position counts bytes and can be saved and restored for backtracking. `read_byte`, `expect`, `take_bytes`, `until`, `identifier`, and `unsigned` leave the position unchanged on error. `until` stops before the delimiter; `expect` or `read_byte` can consume it. `unsigned` reads one or more decimal digits and checks `u64` overflow. Identifiers use ASCII letters or `_` initially, followed by letters, digits, or `_`. `skip_space` consumes ASCII space, tab, CR, and LF.

Parsed spans contain byte offsets. `with_span(parser, span, callback)` checks their bounds and passes a `Slice<u8>` to a callback without copying the input. It returns the callback's owned result in `Result<R, Error>`. A span belongs to the input against which it was parsed; it contains no source identity and does not keep the input alive. It may split a UTF-8 scalar. Errors carry a named kind and a byte offset. These primitives support custom grammars without returning or storing loans.

Borrowed access stays inside the receiving call: callbacks cannot be retained and factories cannot return views. Captures borrow whole variables, so unrelated fields of one captured owner can still conflict. Retained parser spans contain offsets only; callers keep the matching source alive. Scoped callback environments do not allocate on the heap.

Run the library checks with `./bootstrap/crown run components/library/tests -- target/library-roundtrip.bin`. The full gate also runs them with the verified compiler. Tests cover empty buffers, endian operations, Unicode and NUL boundaries, binary file round trips, closed-file errors, map collisions and resource cleanup, parser rollback, overflow, and invalid spans.

The text module provides borrowed comparison, slicing, occurrence, and hashing APIs.

Text readers accept `TextView`, including `joined`, `split`, `repeat`, `hash`, and `unsigned`. Owned text and literals borrow directly at calls. `joined`, `split`, and `repeat` return owned output. `signed_decimal` accepts `i64`, including its minimum value; convert narrower signed integers explicitly. `decimal` accepts `u64`. `hex_byte` appends two lowercase ASCII digits without allocating a lookup string. Text slicing counts bytes and retains the existing lossy behavior at split UTF-8 scalars.

`sequence::clone` and `sequence::append` accept a `scoped fn(read T) -> T`; this makes copying move-only values explicit. `sequence::for_each` borrows each element for a scoped callback. `sequence::equal` compares lengths and then pairs of elements using a caller-supplied equality function. `sequence::sort` accepts a writable slice and a scoped comparator returning a negative, zero, or positive `i32`. It uses in-place heapsort with O(n log n) worst-case comparisons and no additional element storage. Sorting is unstable. Arrays, vectors, and subranges use the existing call-scoped slice conversions. Captures obey Crown's usual exclusive-access rules.

Release QA: run `./bootstrap/crown run components/library/tests -- target/library-roundtrip.bin`, then the language's full `./bootstrap/crown test`. The tests exercise empty and unequal sequences, repeated values, captured comparators, cloned owned text, Unicode and embedded NULs, signed 64-bit limits, all hex bytes, and invalid/overflowing unsigned input. The compiler's registered `frontend_text_append_preserves_utf8` regression additionally checks namespace construction and parent extraction through these shared text operations. There is no Gherkin runner in this package.
