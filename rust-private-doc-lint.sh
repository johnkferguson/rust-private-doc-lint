# Scans Rust sources for doc comments on private items with the bundled
# ast-grep rule. writeShellApplication adds the shebang and strict mode,
# and sets RULES to the directory that holds sgconfig.yml.

usage() {
    cat <<'EOF'
Usage: rust-private-doc-lint [--ignore <glob>]... [<path>...]

Flags each `///` doc comment on a private Rust item under the given paths,
the current directory by default, and exits 1 when it finds one. Files
that .gitignore lists are skipped.

Options:
  --ignore <glob>  Skip the files the glob matches, such as 'vendor/**'.
                   Repeat it for more globs.
  -h, --help       Print this help.
EOF
}

globs=()
paths=()
while [ $# -gt 0 ]; do
    case "$1" in
        --ignore)
            if [ $# -lt 2 ]; then
                echo "rust-private-doc-lint: --ignore needs a glob" >&2
                exit 2
            fi
            globs+=(--globs "!$2")
            shift 2
            ;;
        --ignore=*)
            globs+=(--globs "!${1#--ignore=}")
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        --)
            shift
            paths+=("$@")
            break
            ;;
        -*)
            echo "rust-private-doc-lint: unknown option $1" >&2
            usage >&2
            exit 2
            ;;
        *)
            paths+=("$1")
            shift
            ;;
    esac
done

if [ "${#paths[@]}" -eq 0 ]; then
    paths=(.)
fi

exec ast-grep scan --config "$RULES/sgconfig.yml" "${globs[@]}" -- "${paths[@]}"
