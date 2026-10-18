# Fork notes

This is a fork of [ethanhq/cc-fleet](https://github.com/ethanhq/cc-fleet) with one patch:

- **slim subagents get a shell tool on Windows.** A headless `claude -p` on Windows can
  expose `PowerShell` instead of `Bash`, and `claude` silently drops a `--tools` name it
  does not have, so upstream's slim profiles (Bash only) ended up with no shell. Here
  `PowerShell` is accepted in the tool whitelist and, on Windows, asked for next to `Bash`
  by default. Other platforms are unchanged. Branch: `windows-powershell-slim`.

## Install (Windows)

```powershell
irm https://raw.githubusercontent.com/KuroIVeko/cc-fleet/main/install-fork.ps1 | iex
```

Installs the latest fork release's binary only (the Claude Code plugin still comes from
upstream). The previous binary is kept once as `cc-fleet.exe.upstream-bak`.

## Following upstream

`main` here is upstream's `main` plus the patch plus these fork-only files
(`FORK.md`, `install-fork.ps1`, `.github/workflows/fork-build.yml`), none of which exist
upstream, so merging cleanly is the norm:

```bash
git fetch upstream
git merge upstream/main          # resolve only if upstream touched slimprompt.go
git tag fork-<upstream version>-ps1 && git push origin main fork-<upstream version>-ps1
```

Pushing a `fork-*` tag builds the Windows zips and publishes the release. The tag must
not start with `v`, or upstream's `release.yml` (which needs upstream's signing key) fires.
