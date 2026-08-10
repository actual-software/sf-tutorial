# Capability map

Changes I want to make to my factory, ranked. Written in L-1 on day one, built from in L-5 on day two.

## The layer each change touches

Naming the layer is most of the thinking, because it decides what file you open.

| Layer | You are changing | Shape of the change |
| --- | --- | --- |
| **Agent** | What an agent knows and how it judges | A prompt template, an `agent.toml` |
| **Formula** | What steps a job has and what they depend on | A `*.formula.toml`, often extending an existing one |
| **Order** | When something happens with no human present | An `order.toml` with a `cooldown`, `cron`, `condition` or `event` trigger |

If a change does not fit any of the three, it is probably a change to your *project* rather than to your factory. Write it down somewhere else.

## The map

| Rank | What I want the factory to do | Layer | Why it does not do this today | How I will know it worked | Cost |
| --- | --- | --- | --- | --- | --- |
| 1 | | | | | |
| 2 | | | | | |
| 3 | | | | | |
| 4 | | | | | |
| 5 | | | | | |

Five to eight rows. Rank honestly rather than ambitiously: one finished change beats three half-finished ones, and L-5 is ninety minutes.

The "how I will know it worked" column is not optional. A change you cannot verify is a change you cannot tell has regressed.

## Where these rows came from

Note the evidence behind each row, so a future you can tell a real finding from a good idea.

- **The gate bounced a bead of mine, and its feedback said:**
- **A reviewer produced an opinion rather than a verdict, because it had nothing to cite:**
- **I read a diff the factory wrote and would have written it differently, because:**
- **Something ran that should not have, or did not run that should have:**

## Out of scope, deliberately

Things you decided not to do, and why. This section stops you re-litigating the same idea in three weeks.

-
