# The digest, on the days there is one

Post a digest only when the pass produced at least one finding that warrants operator visibility: a structural-fix bead the operator should know was minted, an operator-decision item, or a delta worth their attention. Zero such findings means post nothing. The silent pass is the common case and the correct one.

### Where it goes

Read `SELF_IMPROVEMENT_DIGEST_CHANNEL` from your `.env`. If it names a channel and your factory has a chat helper, post there as one top-level message rather than a threaded reply, so each day's digest starts a conversation the operator can answer.

If the variable is unset, or your factory has no chat transport, file the digest with `bd human` instead and stop. That is a supported outcome rather than a degraded one: `bd human` is stock, so the pass reaches a person on a factory with no chat integration at all.

### Shape

- An opening line naming the pass and its date: `Daily introspection — <YYYY-MM-DD> (UTC).`
- One bullet per finding, each verb-led and in plain language. Write for someone who does not have your factory's vocabulary: name what happened and what it means, not the internal term for it.
- A closing line, whatever `SELF_IMPROVEMENT_DIGEST_CLOSER` is set to. Leave it unset and there is no closer.

On work-item ids in the digest: they are fine here, because this channel is your operator's own window into the factory. They are not fine in anything that leaves it, where a reader cannot resolve one.
