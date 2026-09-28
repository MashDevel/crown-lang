# Unicode tables

The generated Crown tables implement Unicode 16.0.0 printable and Grapheme_Extend classifications. They contain sorted transition boundaries with binary lookup; invalid Unicode scalars return false.

Generator input files:

- `printable.rs` — SHA-256 `29836734466bfec58fd8735cc58659e8369814ffa2090c2239854d500439b59a`
- `unicode_data.rs` — SHA-256 `09ee4cd2dc94a0a88ae423640adce08a2ec7ae1760918d45dd9372cc25929b8b`

Regenerate with `./bootstrap/crown run components/library/tools/unicode -- INPUT_DIRECTORY` from the repository root. Add an optional output directory to generate candidate tables without changing the checked-in files. The Crown generator reads the files listed above in their singleton/range compression and offset-run formats. It does not fetch Unicode data or depend on a host Unicode implementation.

The generator tests run in the normal compiler gate as `library_unicode_generator`. They also run directly with `./bootstrap/crown run components/library/tools/unicode/tests`; success exits with status 42.

Focused assertion sources are in `components/library/tests/unicode.cwn` and registered with the library source suite. They cover printable/hidden ASCII, accented and CJK characters, combining marks, supplementary planes, range edges, surrogates and invalid scalars. Regeneration with the pinned inputs above has been verified to reproduce both checked-in tables byte for byte.
