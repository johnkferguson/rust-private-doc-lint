{
  description = "An ast-grep lint that flags doc comments on private Rust items";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = {
    self,
    nixpkgs,
  }: let
    systems = ["x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin"];
    forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});

    # The rule, its test cases and the sgconfig.yml that names them.
    rules = nixpkgs.lib.fileset.toSource {
      root = ./.;
      fileset = nixpkgs.lib.fileset.unions [
        ./sgconfig.yml
        ./rules
        ./rule-tests
      ];
    };
  in {
    packages = forAllSystems (pkgs: let
      rust-private-doc-lint = pkgs.writeShellApplication {
        name = "rust-private-doc-lint";
        runtimeInputs = [pkgs.ast-grep];
        runtimeEnv.RULES = rules;
        text = builtins.readFile ./rust-private-doc-lint.sh;
      };
    in {
      inherit rust-private-doc-lint;
      default = rust-private-doc-lint;
    });

    checks = forAllSystems (pkgs: let
      lint = self.packages.${pkgs.stdenv.hostPlatform.system}.default;
    in {
      # Every case in rule-tests/ matches the rule as it says.
      rule-tests = pkgs.runCommand "rule-tests" {nativeBuildInputs = [pkgs.ast-grep];} ''
        cd ${rules}
        ast-grep test --skip-snapshot-tests
        touch $out
      '';

      # The command passes a clean tree, fails a flagged one with exit 1,
      # and skips what --ignore names.
      command = pkgs.runCommand "command" {nativeBuildInputs = [lint];} ''
        mkdir -p tree/src tree/vendor
        printf '/// Public.\npub fn public() {}\n' > tree/src/clean.rs
        printf '/// Private.\nfn private() {}\n' > tree/vendor/flagged.rs
        cd tree

        rust-private-doc-lint src

        status=0
        rust-private-doc-lint >/dev/null || status=$?
        if [ "$status" -ne 1 ]; then
          echo "expected exit 1 on a flagged file, got $status" >&2
          exit 1
        fi

        rust-private-doc-lint --ignore 'vendor/**'
        rust-private-doc-lint --ignore=vendor/flagged.rs .
        touch $out
      '';
    });

    formatter = forAllSystems (pkgs: pkgs.alejandra);
  };
}
