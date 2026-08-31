#!/usr/bin/env bash
# ai-factory local CI pre-runner (L3 resource of the issue-fix skill).
#
# Best-effort mirror of the repository's checks inside the sandbox before a
# push. It is environment-dependent: the sandbox is a generic dev image and may
# not match the repo's toolchain. Every inferred step probes for its tool first
# and SKIPS it (with a note) when the tool is missing — this script never hard-
# runs a check that must fail for lack of environment.
#
# Usage: run from the repository checkout (CWD = repo root), or set
# AI_FACTORY_WORKDIR and run from anywhere. The repo root is resolved from
# AI_FACTORY_WORKDIR if set, otherwise from the current directory — never from
# this script's own path (it ships with the plugin, not inside the target repo).
#
# Priority:
#   1. Task-specific commands injected by the controller (AI_FACTORY_CI_COMMANDS,
#      semicolon-separated) — the most authoritative; the controller knows the
#      environment, so these run as given.
#   2. Inferred from the repo's own tooling, tool-probed (go/npm/make).
#   3. CI-file mirroring is left to the model per SKILL.md priority 3.
#
# Exit: 0 if nothing FAILED (steps may be skipped for missing toolchains);
#       1 if any tool-present step failed (fix it, or note it and move on).

set -u
# Repo root = $AI_FACTORY_WORKDIR if set, else the current directory.
if [ -n "${AI_FACTORY_WORKDIR:-}" ]; then
    cd "$AI_FACTORY_WORKDIR" || exit 1
fi
failed=0

run_probed() {
    local tool="$1" desc="$2"
    shift 2
    if ! command -v "$tool" >/dev/null 2>&1; then
        printf '==> skip: %s (tool %s not installed in this sandbox)\n' "$desc" "$tool"
        return 0
    fi
    printf '\n==> %s\n' "$desc"
    if ! "$@" >/tmp/local-ci-step.log 2>&1; then
        echo "FAILED: $desc"
        tail -20 /tmp/local-ci-step.log >&2
        failed=1
    else
        echo "ok: $desc"
    fi
}

# 1) Injected commands (authoritative; the controller knows the environment).
if [ -n "${AI_FACTORY_CI_COMMANDS:-}" ]; then
    IFS=';' read -ra cmds <<<"$AI_FACTORY_CI_COMMANDS"
    for c in "${cmds[@]}"; do
        printf '\n==> injected: %s\n' "$c"
        if ! bash -lc "$c" >/tmp/local-ci-step.log 2>&1; then
            echo "FAILED: injected: $c"
            tail -20 /tmp/local-ci-step.log >&2
            failed=1
        else
            echo "ok: injected: $c"
        fi
    done
fi

# 2) Infer from the repo's own tooling, only when the toolchain is present.
if [ -f go.mod ]; then
    run_probed go    "go build ./..." go build ./...
    run_probed go    "go test ./..."  go test ./...
    run_probed gofmt "gofmt -l ."     bash -c 'test -z "$(gofmt -l .)"'
elif [ -f package.json ]; then
    run_probed npm "npm test" npm test
elif [ -f Makefile ] || [ -f makefile ]; then
    run_probed make "make test" make test
else
    printf '\n==> no go.mod/package.json/Makefile found; nothing inferred. '
    echo 'Model: mirror cheap CI steps per SKILL.md priority 3, tool-probed.'
fi

exit "$failed"
