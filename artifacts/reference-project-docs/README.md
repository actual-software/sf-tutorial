# Reference project docs: Fired Up Pizza

> **Demonstration only.** These documents belong to a theoretical reference project, Fired Up Pizza (online ordering for a small pizza restaurant). They show what the templates in [`../docs/`](../docs/) look like once filled in for one project. Use them as a worked example of the shape and level of detail, not as a spec to build, a factory configuration to copy, or a description of your own factory.

The docs came from a single run of the tutorial's `base-factory` against this project. Bead IDs (`fup-…`), commit hashes and dates in them refer to that run and won't resolve anywhere else.

## What's here

| File | Filled in from | What it shows |
| --- | --- | --- |
| [`PROJECT_OVERVIEW.md`](PROJECT_OVERVIEW.md) | [`PROJECT_OVERVIEW.template.md`](../docs/PROJECT_OVERVIEW.template.md) | The loose brief written before the manifest |
| [`PROJECT_MANIFEST.md`](PROJECT_MANIFEST.md) | [`PROJECT_MANIFEST.template.md`](../docs/PROJECT_MANIFEST.template.md) | The structured manifest generated from the brief |
| [`SOFTWARE_FACTORY_MANIFEST.md`](SOFTWARE_FACTORY_MANIFEST.md) | the `manifest-generator` skill | The *intended* six-agent pipeline with two human gates |
| [`current/coordination-channels.md`](current/coordination-channels.md) | [`coordination-channels.template.md`](../docs/coordination-channels.template.md) | How work actually moved between the mayor, polecats, architect and refinery |
| [`current/capability-map.md`](current/capability-map.md) | [`capability-map.template.md`](../docs/capability-map.template.md) | A ranked list of changes that would close the gap between the factory that ran and the one the factory manifest describes, with evidence for each |
| [`current/architecture.md`](current/architecture.md) | written by the factory | The architecture map the factory kept up to date as it built the MVP |
| [`decision-records/`](decision-records/) | written by the factory | ADRs 0000–0007 from the planning pass |

## Reading them

The manifests describe the factory the project *wanted*. The coordination-channels doc describes the factory that *ran*, and the capability map is the bridge between the two. Read them in that order to see how the Day 2 docs build on the Day 1 ones.
