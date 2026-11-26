# UNLu infrastructure and CDKE project agent instructions

## Project context

This repository is the UNLu infrastructure course template and the home for the
academic CDKE application, evaluation and GKE deployment. The existing `app/`,
`model/`, `pow/` and `contracts/` directories are course examples. Inspect them
before reuse, and keep the new CDKE application distinct unless an approved
SPEC and PLAN explicitly change that boundary. The reusable local inference
gateway belongs to the separate `cdke-models-api-service` repository.

## Alexandria installation

Alexandria is installed here through `alisd`. Its canonical content is under
`.alisd/`, with skills exposed through `.agents/skills/` and `.claude/skills/`.
Follow the managed block below for bootstrap and relevant standards. Packaged
Git hooks require separate activation.

For substantive SDD work, start with `.alisd/skills/agent-work-discipline/SKILL.md`
and read only the standards and skills relevant to the task.

## Work in this repository

Preserve the course examples, existing documentation and unrelated work. Keep
this project's SPEC, PLAN, CHANGELOG, STATUS, SELF-REVIEW, tests and evidence
under `docs/sdd/changes/<change-id>/` when an SDD change starts. SPEC is the sole
editable acceptance contract. Obtain approval of the actual SPEC and PLAN
before implementing behavior or service configuration.

Use this repository's real Makefile, tests, Terraform, Helm and CI commands for
validation. The README expects Windows development inside WSL2 for its Bash
commands. Installed Alexandria content alone does not validate CDKE. Treat
cloud provisioning, commits, pushes, PRs, tracker updates and publication as
separately scoped actions; review infrastructure changes and costs before
creating billable resources. Keep credentials, model weights and local
persistence outside the repository.

<!-- alisd:begin -->
# Alexandria SDD consumer agent entrypoint

This is a source template for a consuming repository's root `AGENTS.md`. Keep
existing project instructions. If a root file already exists, insert this
Alexandria block near its beginning rather than replacing the file. Review
conflicts with project security and approved change scope before adoption.

## Critical SDD rules

- SPEC is the sole editable source of requirements and acceptance criteria;
  PLAN maps work and validation to its stable AC IDs. Obtain explicit human
  approval of the actual SPEC and PLAN before implementation.
- For executable behavior, use meaningful test-first RED, the unchanged test
  at GREEN and fresh regression checks. Instruction-only work uses a named
  non-executable review with its reason.
- Retain actual evidence for each required AC and check before claiming
  completion. Missing or failed evidence blocks the gate; a template, plan or
  self-review is not an observed result.
- The implementing agent spawns fresh independent QA and CR reviewers through the host with read-only permissions; follow [review independence](.alisd/standards/review-independence.md).
- If independence is unavailable, report the gap; author review, a writable role or another AI cannot substitute.
- Humans perform the final merge. An agent must not merge, enable auto-merge,
  force-push or infer tracker closure from a PR or a check result.

## Resolve canonical content before work

Alexandria reaches a consuming repository only through the `alisd` executable.
Run `alisd self-update` once, then `alisd install` at the repository root.
The update attempt is a warning, not a stop: if no verified update is
available or it is rejected, installation still proceeds from the trusted
current binary. A failed installation reports its stage and preserves prior
and unrelated resources; rerun `alisd install` to reconcile an interrupted
or partial state under its owned-resource rules.

The links below are repository-root-relative and valid when `alisd install`
has materialized the embedded payload at `.alisd/` in the consuming
repository. If `.alisd/` is absent, the content is not installed: run the
commands above or report the missing installation instead of reconstructing
it. Never distribute Alexandria to an agent host by indexing, copying or
symlinking `content/` sources outside the CLI; skill exposure happens only
through the installed `.agents/skills/` and `.claude/skills/` entries that
`alisd install` owns. Do not claim an exposure is loaded or a skill is
active in this host unless the host actually discovered it.

Read the applicable [SDD method](.alisd/standards/sdd-method.md),
[development](.alisd/standards/development.md),
[TDD and evidence](.alisd/standards/tdd-evidence.md),
[engineering quality](.alisd/standards/engineering-quality.md),
[change identity](.alisd/standards/change-identity.md),
[delivery](.alisd/standards/delivery.md),
[PR evidence](.alisd/standards/pr-evidence.md) and
[publication hygiene](.alisd/standards/publication-hygiene.md) standards
before relevant work. For backend work, read
[backend standards](.alisd/standards/backend.md); for frontend work, read
[frontend standards](.alisd/standards/frontend.md) and applicable design
guidance. Select engineering packs from the
[catalog](.alisd/rules/engineering/README.md) only for the actual task.

Use the relevant source skills from the reviewed content revision:
[plan ticket](.alisd/skills/plan-ticket/SKILL.md),
[execute task train](.alisd/skills/execute-task-train/SKILL.md),
[QA](.alisd/skills/qa-ticket/SKILL.md),
[code review](.alisd/skills/pr-code-review/SKILL.md),
[resolve findings](.alisd/skills/resolve-review-findings/SKILL.md) and
[write PR report](.alisd/skills/write-pr-report/SKILL.md). Follow the
project's actual tracker profile and available commands. Never present a
source skill as an installed slash command without verified exposure.

## Change identity and planning gate

Resolve a stable project-defined change ID from the accepted work item or
tracker. Never derive it from the branch slug or a description. If an input
such as a bare number is ambiguous, use the consuming project's ticket policy
before creating paths. Read the parent and exposed child work items before
planning; map in-scope child behavior to SPEC ACs or record a blocker. An
administrative child does not become a requirement by implication. Follow
[change identity](.alisd/standards/change-identity.md) and the selected
[work-item lifecycle](.alisd/standards/work-item-lifecycle.md).

Keep the canonical change workspace at `docs/sdd/changes/{change-id}/`. Create
or reconcile SPEC, PLAN, CHANGELOG, STATUS and SELF-REVIEW under the
[planning initialization gate](.alisd/standards/sdd-method.md#planning-initialization-gate).
SPEC owns the editable acceptance contract. PLAN references each AC ID and
names destinations, dependencies, applicable test/review method, expected
RED or baseline, required evidence and stop conditions. Do not create a second
editable AC list, a generated companion spec or a claimed runtime result.
Read actual tools and commands before listing them as runnable.

Present the complete SPEC and PLAN for explicit human approval before editing
implementation code or configuration. Record the approved input identities
and scoped delivery delegation. Reuse unchanged approval when resuming;
material changes return to the
[freeze rule](.alisd/standards/sdd-method.md#approved-spec-and-plan-freeze).
For an accepted story train, use one anchor PLAN and branch while keeping
separate member SPECs and AC evidence. Start each member only after its
predecessor's local gate and, where applicable, its own tracker admission.

## Repository discovery and surface rules

Inspect repository structure, local instructions, architecture, ADRs, glossary,
API contracts and actual build/test scripts before editing. Keep a change
limited to the approved destinations. For a backend API change, follow the
[backend standard](.alisd/standards/backend.md), including the applicable
OpenAPI contract obligation. For frontend or visual work, follow the
[frontend standard](.alisd/standards/frontend.md) and
[design-system standard](.alisd/standards/design-system.md); inspect a root
`DESIGN.md` when present or record the missing design source as a gap.
Cross-surface work reads each matching standard. A selected engineering pack
adds its exact obligation IDs and validation impact; available packs are not
automatically active.

Preserve local project policy and human-owned files. Existing root instructions
may add stricter security, workflow, tracker and repository constraints. Resolve
any material conflict with the approved change authority before acting; do not
silently replace local policy with a generic starter.

## Execution, validation and evidence

Implement one approved step at a time. For behavior changes and bug fixes,
record a behavior-specific failing test before implementation, the same test
passing afterward and a fresh regression check. A syntax, fixture, import or
missing-runner error is not a qualifying RED. Pure refactoring needs a named
passing characterization before and after. Record actual command/method,
observer, UTC time, outcome, exit code and input identity. Do not relabel an
unexecuted example as evidence.

Append factual work, failures and corrections to CHANGELOG; never rewrite
earlier entries. STATUS is a current snapshot, not proof. Map every required
SPEC AC to actual implementation and validation evidence with Covered,
Partial or Not Covered. Unresolved required ACs block successful completion.
The author keeps SELF-REVIEW separate from the independent QA and CR reports.
Follow [PR evidence](.alisd/standards/pr-evidence.md) and the
[QA skill](.alisd/skills/qa-ticket/SKILL.md) at their actual gates.

Before sharing evidence, commits or a PR, apply
[publication hygiene](.alisd/standards/publication-hygiene.md). Keep secrets,
private paths, unrelated work and generated runtime state out of shared
artifacts. Record sanitized-view and original integrity when redaction is
authorized; a later cleanup does not erase earlier published history.

## Delivery and handoff

Follow the [delivery standard](.alisd/standards/delivery.md) and project
branch/commit/PR skills only within explicit scope. Preserve staged and
unstaged work, required signing, hooks and configured identity. Do not reset,
clean, silently unstage, force-push or rewrite history to pass a gate. A plan
approves delivery operations only when its delegation section lists them.

Prepare the PR in the active consumer template with actual changes, qualified
AC coverage, observed checks and CI, real commits, selected pack IDs and
pending gates. Missing active template blocks report generation. A checked
command or CI item needs a matching current observation; configured workflows
and local checks do not prove remote success. Reconcile review findings with
fresh QA/CR as required. Hand human reviewers the residual risks and leave
merge and final tracker closure to their separate gates.

## Simplifications and local context

When a deliberate bounded simplification has a real ceiling, record its scope
and concrete upgrade trigger in the relevant code or change evidence. A debt
note does not waive an AC, test, security or review obligation.
Use `sdd-simplification: <bounded shortcut> - upgrade path: <concrete trigger
or replacement>` when this marker is part of the approved change; do not add
it to describe an accidental omission. Consult local
`DESIGN.md`, architecture notes, ADRs, glossary, API contracts and scripts when
they exist. Keep code, comments, docs, branch descriptions and commit/PR text
in English under this workflow.

Preserve project-specific architecture, security, API contracts, build/test
commands and local instructions. Resolve conflicts under the approved change
and project rules; do not overwrite a human-owned root file with this template.

---
Template/content source baseline: 0.1.0-dev.0 (unreleased), adapted from
kathy-sdd-kit 0.7.0 saved inputs. Alexandria consumer distribution runs
through the `alisd` executable; this template does not install anything by
itself.
<!-- alisd:end -->
