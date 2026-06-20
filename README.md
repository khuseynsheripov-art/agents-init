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

There are three separate layers:

```text
Maestro CLI                      installed/upgraded by npm
Claude / cc2 / Maestro delegate   configured and smoke-tested as a model route
agents-init Codex skill           installed/upgraded from this git repo
each business/test project         upgraded by the installed skill's init-agents.ps1
```

Maestro is a global CLI:

```powershell
npm install -g maestro-flow
maestro --version
```

Claude is a model route, not part of the skill package. There are two supported paths:

```text
direct cc2                 trusted capturable Claude review path when smoke-tested
Maestro delegate to Claude  preferred later if raw output proves the adapter works
```

Direct `cc2` smoke:

```powershell
cc2 --version
cc2 --safe-mode -p "agents-init Claude smoke. Reply with AGENTSINIT-CC2-SMOKE." --model opus --output-format json --no-session-persistence
```

Continue only when the next question needs the prior Claude context:

```powershell
cc2 --safe-mode -p "<follow-up>" --model opus --output-format json --resume "<session_id>"
```

Maestro delegate config and smoke:

```powershell
maestro config delegate show --json
maestro delegate --to claude --mode analysis --cd "<project>" "Smoke test. Reply with AGENTSINIT-MAESTRO-CLAUDE-SMOKE."
```

Important rules:

- request aliases such as `opus`, not hardcoded dated model names, unless the local tool requires a concrete model;
- record the actual model from raw output in a receipt;
- Maestro `completed` status is not enough. The raw delegate output must contain task-relevant Claude output;
- if roles still map to Codex, Maestro is multi-role but not multi-model by default;
- changing `<project>\.maestro\cli-tools.json` is project-local policy; changing `%USERPROFILE%\.maestro\cli-tools.json` is global policy and needs stronger confirmation;
- if Claude expires, quota fails, or a profile changes, stop and report it. Do not silently switch accounts.

`agents-init` is not an npm package. It is a Codex skill installed under:

```text
%USERPROFILE%\.codex\skills\agents-init
```

From the development repo:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\install-local.ps1
```

This copies `skill/agents-init` to `%USERPROFILE%\.codex\skills\agents-init` after making a timestamped backup of the previous installed copy.

From another local machine or test environment that has cloned this repo:

```powershell
git clone https://github.com/khuseynsheripov-art/agents-init.git
cd agents-init
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\update-from-git.ps1
```

That script fast-forwards the repository from `origin/main`, then installs the skill. It does not touch any business project's `.workflow` state.

For later updates in an existing clone:

```powershell
cd agents-init
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\update-from-git.ps1
```

From any project after the skill is already installed, the installed skill can update itself from GitHub into a local source clone and reinstall:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\skills\agents-init\scripts\update-agents-init.ps1"
```

To update the skill and then non-destructively upgrade one project workflow:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\skills\agents-init\scripts\update-agents-init.ps1" -ProjectPath "<project>"
```

Default source clone:

```text
%USERPROFILE%\.codex\skill-sources\agents-init
```

This pulls `origin/main`, reinstalls `%USERPROFILE%\.codex\skills\agents-init`, then runs `init-agents.ps1 -Mode upgrade` plus `validate-workflow.ps1` only when `-ProjectPath` is supplied.

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

Example for the current Ozon/Canvas test worktree:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\skills\agents-init\scripts\init-agents.ps1" -ProjectPath "E:\ozon-erp\.worktrees\maestro-canvas-v030-lab" -Mode upgrade
powershell -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\skills\agents-init\scripts\recover-agents.ps1" -ProjectPath "E:\ozon-erp\.worktrees\maestro-canvas-v030-lab" -Json
powershell -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\skills\agents-init\scripts\validate-workflow.ps1" -ProjectPath "E:\ozon-erp\.worktrees\maestro-canvas-v030-lab" -Json
powershell -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\skills\agents-init\scripts\doctor-agents.ps1" -ProjectPath "E:\ozon-erp\.worktrees\maestro-canvas-v030-lab" -Json
```

## GitHub Publication Policy

Start private. This project may include local paths, private workflow receipts, and business case studies during active iteration. Public release requires a separate sanitation pass:

- no local account paths;
- no credentials or profile directories;
- no raw model receipts with session ids or costs;
- no private business data;
- case studies generalized or explicitly sanitized.
