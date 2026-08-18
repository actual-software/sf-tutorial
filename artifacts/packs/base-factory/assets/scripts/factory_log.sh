#!/usr/bin/env bash
# Shared by both orders in this pack: resolve the log path and make sure the
# file exists with its header. Sourced, not run.
#
# GC_RIG_ROOT is set by the controller for a rig-scoped order and is the rig's
# working copy. Both orders here are rig-scoped, so an unset value means the
# pack was imported at city scope and the right move is to fail loudly rather
# than write the log somewhere nobody will look for it.

factory_log_path() {
    : "${GC_RIG_ROOT:?base-factory orders are rig-scoped; import with gc import add --rig <rig-name>}"
    printf '%s/FACTORY_LOG.md' "$GC_RIG_ROOT"
}

factory_log_init() {
    local log="$1"
    [ -s "$log" ] && return 0
    cat > "$log" <<'HEADER'
# Factory log

Written by the two orders in the `base-factory` pack, so that one file shows
both trigger styles at once. Lines starting with `pulse` come from
`factory-pulse`, which runs on a clock. Lines starting with `closed` come from
`bead-closed-log`, which runs when the factory closes a bead.

Nothing reads this file. It exists so you can watch the orders work.

HEADER
}
