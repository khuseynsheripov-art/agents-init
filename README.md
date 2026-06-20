# Agents Init

maestro 的强势外挂，目标是会用 Codex App 多会话 + Maestro 智能 + 多 CLI 非交互大模型。

This repository is the source of truth for the `agents-init` skill. The installed runtime copy lives under the user's Codex skills directory, for example:

```text
%USERPROFILE%\.codex\skills\agents-init
```

## What It Is

`agents-init` helps a main Codex agent adopt a project into a recoverable workflow:

- fuzzy requirement clarification;
- context recovery after long tasks or compression;
- PM/FDE/UX/workflow/risk review gates;
- Codex App worker receipts;
- Maestro delegate and knowledge routing;
- Claude second-view review with receipts;
- UI, sample, generated-image, and product-direction human gates;
- old-project salvage and insertion planning.

It is not a command menu and not a product-direction decider. The main agent remains responsible for judgment and user gates.

## Repository Layout

```text
skill/agents-init/        installable Codex skill
scripts/                 repo-level install/update helpers
docs/                    sanitized design notes
```

Local runtime state such as `.workflow/`, `.tmp/`, and `maestro-knowledge-base/` is intentionally ignored by git.

## Install Or Update Locally

From this repo:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\install-local.ps1
```

This copies `skill/agents-init` to `%USERPROFILE%\.codex\skills\agents-init` after making a timestamped backup of the previous installed copy.

From another local machine or test environment that has cloned this repo:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\update-from-git.ps1
```

That script fast-forwards the repository from `origin/main`, then installs the skill. It does not touch any business project's `.workflow` state.

## Project Adoption

After the skill is installed, a project can be adopted non-destructively:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\skills\agents-init\scripts\init-agents.ps1" -ProjectPath "<project>" -Mode auto
```

Each business project keeps its own `.workflow` state. Do not store project runtime state in this repo unless it is a sanitized test fixture.

For an already-adopted project, run upgrade mode after installing a newer skill:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\skills\agents-init\scripts\init-agents.ps1" -ProjectPath "<project>" -Mode upgrade
```

Upgrade mode only creates missing v2 workflow files and updates known workflow templates. It does not decide product direction or overwrite project-owned docs.

## GitHub Publication Policy

Start private. This project may include local paths, private workflow receipts, and business case studies during active iteration. Public release requires a separate sanitation pass:

- no local account paths;
- no credentials or profile directories;
- no raw model receipts with session ids or costs;
- no private business data;
- case studies generalized or explicitly sanitized.
