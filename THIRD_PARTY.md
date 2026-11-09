# Third-party notices

## Argon2 reference implementation

`Sources/CArgon2` vendors the portable reference implementation from
[P-H-C/phc-winner-argon2](https://github.com/P-H-C/phc-winner-argon2), tag `20190702`.
Only the public header, portable C core, encoding, threading header/source, and required Blake2 files are included.
It is compiled with `ARGON2_NO_THREADS` and statically linked. Upstream code has not been modified.

Source archive SHA-256:
`daf972a89577f8772602bf2eb38b6a3dd3d922bf5724d45e7f9589b5e830442c`

Upstream offers CC0 1.0 or Apache License 2.0. The complete upstream license is preserved in
`Sources/CArgon2/LICENSE` and copied into the app bundle as `Argon2-LICENSE.txt`.

## Compatibility fixtures

`Tests/QuickAuthCoreTests/Fixtures` contains synthetic data generated with CryptoJS 4.2.0
and argon2-browser 1.18.0, the same encryption families used by Authenticator Extension.
These JavaScript packages are used only to generate test data and are not bundled with Quick Auth.
The test password and secrets are intentionally public and must never be used for real accounts.

Authenticator Extension's published backup schemas and source were consulted for interoperability.
The application's Swift importer is an independent implementation of those formats.
