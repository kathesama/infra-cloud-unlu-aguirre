# Claude Code project instructions

Load this repository's shared agent instructions:

@AGENTS.md

The installed Alexandria content and bootstrap rules are referenced from
`AGENTS.md`. This file does not activate Git hooks or create cloud resources.

<!-- alisd:begin -->
# Alexandria SDD consumer Claude entrypoint

@AGENTS.md

Read the consuming repository's root [AGENTS.md](AGENTS.md) before SDD work.
It owns the Alexandria approval, SPEC/PLAN, TDD, evidence, independent QA/CR
and human merge rules. Keep project-specific Claude instructions here without
copying that policy. If `AGENTS.md` is absent or its referenced Alexandria
content is unavailable, report the missing source instead of inventing an
installation or command.

This is a source template. Preserve an existing consumer `CLAUDE.md` and add
only the needed pointer after reviewing local instructions. The installer
adapts this template inside the kit-owned marker region;
consumer edits outside it are preserved and a file without the region is
left for human resolution.

---
Template/content source baseline: 0.1.0-dev.0 (unreleased), adapted from
kathy-sdd-kit 0.7.0 saved inputs. Alexandria consumer CLI ships with the
0.1.0 distribution train; this template is installed by `alisd install`.
<!-- alisd:end -->
