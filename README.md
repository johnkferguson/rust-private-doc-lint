# rust-private-doc-lint

An [ast-grep](https://ast-grep.github.io) lint that flags `///` doc
comments on private Rust items, packaged as a Nix flake.

A doc comment documents an item for code outside its module. On a
private item, use a `//` comment when it explains a non-obvious why, or
delete it. The lint works on the syntax tree, so it doesn't need a
build, and it reads tens of thousands of lines in well under a second.

## What It Flags

A doc comment (`///`, `/** */`, `#[doc = "..."]`, or a `doc = "..."` in
`cfg_attr`) in front of an item no one outside its module can name:

- An item or struct field with no visibility, or with `pub(self)` or
  `pub(in self)`. `pub`, `pub(crate)`, `pub(super)` and `pub(in path)`
  count as public.
- An enum variant, or a field of one, when the enum is private. Variants
  and their fields take the enum's visibility.
- A trait's method, associated type or constant when the trait is
  private. Trait items take the trait's visibility.
- A `macro_rules!` macro that nothing makes visible outside its module.
  `#[macro_export]`, a `pub` `use` of its name later in the same module
  (renamed with `as` or in a braced list too), or `#[macro_use]` on an
  inline module around it each count as public.

The items of a trait impl count as public, and so does an impl block.
The [rule](rules/no-doc-on-private-item.yml) holds these, and its
[test cases](rule-tests/no-doc-on-private-item-test.yml) show each one.

## Known Gaps

- **Macro bodies.** Tree-sitter reads the body of a macro call, such as
  `proptest! { ... }` or `verus! { ... }`, as plain tokens, so the lint
  doesn't check the items inside it.
- **`#[macro_use]` across files.** A macro in a module declared with
  `#[macro_use] mod name;` is visible after that declaration, but the
  lint only sees the macro's own file and flags it.
- **Effective visibility.** The lint reads the visibility written on an
  item, not where it can be reached from. A `pub` item inside a private
  module counts as public.

## Usage

```sh
nix run github:johnkferguson/rust-private-doc-lint -- [--ignore <glob>]... [<path>...]
```

It scans the paths given, the current directory by default, and skips
the files `.gitignore` lists. Each `--ignore` skips the files a glob
matches under a directory argument, such as `--ignore 'vendor/**'`; a
file named as an argument is always scanned. It prints ast-grep's report
and exits 1 when it finds a doc comment on a private item, 2 on a bad
option or a path that doesn't exist, and 0 otherwise.

## Adding It to a Repo

Pin one tag in two places: the devenv input, and the CI job.

In `devenv.yaml`, add the input. Leave out `follows` for its nixpkgs, so
the ast-grep version stays the one this repo's `flake.lock` pins:

```yaml
inputs:
  rust-private-doc-lint:
    url: github:johnkferguson/rust-private-doc-lint/v0.1.0
```

In `devenv.nix`, put the command on the shell's `PATH`:

```nix
{
  pkgs,
  inputs,
  ...
}: {
  packages = [
    inputs.rust-private-doc-lint.packages.${pkgs.stdenv.hostPlatform.system}.default
  ];
}
```

In `lefthook.yml`, run it before each commit that touches Rust:

```yaml
pre-commit:
  commands:
    rust-private-doc-lint:
      glob: "*.rs"
      run: rust-private-doc-lint
```

Call it from the repo's verify script as well:

```sh
rust-private-doc-lint
```

In CI, run it at the same tag:

```yaml
jobs:
  private-doc-lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v7.0.1
      - uses: cachix/install-nix-action@v31.11.5
      - run: nix run github:johnkferguson/rust-private-doc-lint/v0.1.0
```

A repo that holds code it doesn't own, such as a fork, passes its own
crates' paths or `--ignore` globs for the rest in all three places.

## Development

```sh
nix flake check   # the rule's test cases, and the command's exit codes and --ignore
nix fmt           # formats the Nix files with alejandra
```

`ast-grep test --skip-snapshot-tests` in the repo root runs the rule's
test cases alone. CI runs `nix flake check`, the format check, and
`gh actions-lock --verify`. After changing a `uses:` line, run
`gh actions-lock` and commit `.github/workflows/actions.lock`, with the
extension at the version `ci.yml` pins
(`gh extension install github/gh-actions-lock --pin v0.4.1`).
