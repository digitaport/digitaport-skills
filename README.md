# Digitaport Skills

Reusable GitHub Copilot skill definitions for common engineering workflows. This repository packages focused skills with their supporting references, templates, scripts, and assets so they can be reused across projects instead of rewriting operational guidance from scratch.

## Included Skills

| Skill | Purpose | Key Assets |
|---|---|---|
| `acquire-codebase-knowledge` | Maps an existing codebase into a documented set of architecture, structure, testing, integration, and concern notes grounded in repository evidence. | Documentation templates, investigation references, `scripts/scan.py` |
| `cloud-design-patterns` | Provides a catalog of technology-agnostic cloud architecture patterns for distributed system design and review. | Pattern references grouped by reliability, performance, messaging, security, deployment |
| `secret-scanning` | Guides GitHub secret scanning setup, push protection, custom patterns, and alert remediation. | Secret scanning references for alerts, patterns, and push protection |
| `security-review` | Runs structured codebase security reviews with dependency checks, secrets review, data flow analysis, and patch proposals. | Language patterns, vulnerability categories, report format, package watchlists |
| `webapp-testing` | Supports browser-driven testing and debugging of local web applications with Playwright. | Playwright helper asset in `assets/test-helper.js` |

## Repository Layout

```text
.
├── README.md
├── agents/
├── instructions/
└── skills/
	├── acquire-codebase-knowledge/
	├── cloud-design-patterns/
	├── secret-scanning/
	├── security-review/
	└── webapp-testing/
```

Each skill lives in its own directory and is anchored by a `SKILL.md` file. Supporting materials stay adjacent to the skill that uses them:

- `references/` holds domain guidance that the skill loads on demand.
- `assets/` holds templates, helper scripts, or reusable supporting files.
- `scripts/` holds executable tooling used by the skill workflow.

The top-level `agents/` and `instructions/` directories are present for repository expansion but are currently empty.

## How To Use This Repository

Use this repository as a source of reusable skill packages for Copilot or other agent-driven workflows:

1. Choose the skill directory that matches the task.
2. Read the skill's `SKILL.md` for the trigger conditions, workflow, and required outputs.
3. Load the referenced files only when the workflow calls for them.
4. Keep updates local to the relevant skill folder so references and assets stay in sync.

## Skill Design Conventions

The current skills follow a consistent packaging pattern:

- YAML frontmatter defines the skill name, description, and metadata.
- The body describes when the skill should be used, how to execute it, and what output is required.
- Reference material is split into focused files instead of embedding everything into one long prompt.
- Assets are stored with the skill so the workflow remains portable.

## Local Requirements

Most skills are documentation-only, but some include tool expectations:

- `acquire-codebase-knowledge` requires Python 3.8+ and `git` to run `scripts/scan.py`.
- `webapp-testing` expects Node.js and access to a running local web application.
- The security-focused skills assume access to the target repository, dependency manifests, and configuration files being reviewed.

## Maintaining The Catalog

When adding or updating skills:

1. Keep `SKILL.md` as the canonical entry point.
2. Add supporting references instead of overloading the main skill prompt.
3. Prefer explicit output contracts and step-by-step workflows.
4. Update this README when the skill catalog or repository layout changes.

## Team Installation

The repository now includes an idempotent installer at `scripts/install.sh`.

What it does:

- Clones this repository into a managed local cache at `~/.digitaport/skills/digitaport-skills`
- Links each skill folder into `~/.agents/skills`
- Tracks which links belong to Digitaport so stale links can be cleaned up on later updates
- Installs a real update command named `digitaport-skills-update` in `~/.local/bin`
- Reuses the same script for install and update

### Recommended Team Command

If the repository is public or otherwise accessible through GitHub raw content:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/digitaport/digitaport-skills/main/scripts/install.sh)
```

If the repository is private, use GitHub CLI so engineers can authenticate with their existing GitHub session:

```bash
DIGITAPORT_SKILLS_REPO_URL=git@github.com:digitaport/digitaport-skills.git \
bash <(gh api repos/digitaport/digitaport-skills/contents/scripts/install.sh --jq '.content' | base64 --decode)
```

### Installer Options

```bash
./scripts/install.sh --help
./scripts/install.sh --ref v1.0.0
./scripts/install.sh --repo-url git@github.com:digitaport/digitaport-skills.git
./scripts/install.sh --force
```

Use `--ref` to pin engineers to a release tag. Omit it to track the latest commit on `main`.
The installer persists the chosen source URL and ref in `~/.agents/.digitaport-skills/metadata.env`, so later updates reuse the same channel unless an engineer overrides it.

## Update Strategy

The installer is also the updater. After the first install, engineers can update in place with:

```bash
digitaport-skills-update
```

If `~/.local/bin` is not already on an engineer's `PATH`, they should add it in their shell config before using the command directly.

Recommended rollout process:

1. Treat `main` as the integration branch for skill authors.
2. Cut Git tags such as `v1.0.0`, `v1.1.0`, and `v1.2.0` for team-approved releases.
3. Tell engineers to install with `--ref <tag>` if you want controlled rollout, or with the default branch if you want them always on the latest version.
4. Announce updates in Slack or your engineering changelog with the exact update command.

Suggested release policy:

- Patch release for copy edits, reference fixes, and non-breaking clarifications
- Minor release for new skills or workflow changes
- Major release only if you rename or remove skills, or materially change expected behavior

This gives you two supported modes:

- `latest`: engineers re-run the installer and pick up the newest approved `main`
- `pinned`: engineers stay on a tag until you ask them to move
