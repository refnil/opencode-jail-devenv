# opencode-jail-devenv

> **Status:** Alpha - Experimental, may have breaking changes

A devenv module that provides secure sandboxing for the opencode LLM agent using [jail.nix](https://git.sr.ht/~alexdavid/jail.nix). Run AI coding agents safely with restricted filesystem and network access, preventing accidental or malicious system modifications.

Inspired by [How I Run LLM Agents in a Secure Nix Sandbox](https://dev.to/andersonjoseph/how-i-run-llm-agents-in-a-secure-nix-sandbox-1899).

## Dependencies

- [devenv](https://devenv.sh)
- [jail.nix](https://git.sr.ht/~alexdavid/jail.nix)
- [opencode](https://github.com/opencode-ai/opencode)

## Installation

Add to your `devenv.yaml`:

```yaml
inputs:
  opencode:
    url: github:refnil/opencode-jail-devenv
  jail-nix:
    url: sourcehut:~alexdavid/jail.nix

imports:
  - opencode
```

## Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `programs.opencode.enable` | bool | `false` | Enable the opencode module |
| `programs.opencode.addProjetPackages` | bool | `true` | Include `config.packages` in the opencode environment |
| `programs.opencode.basePackages` | list | See below | Base packages available to the agent (curl, git, ripgrep, etc.) |
| `programs.opencode.packages` | list | `[]` | Additional custom packages to add |
| `programs.opencode.opencodePackage` | package | `pkgs.opencode` | The opencode package to use |
| `programs.opencode.baseJailCombinators` | list | See below | Base sandbox permissions |
| `programs.opencode.jailCombinators` | list | `[]` | Additional sandbox permissions |

**Default base packages:** `bashInteractive`, `curl`, `wget`, `jq`, `git`, `which`, `ripgrep`, `gnugrep`, `gawkInteractive`, `ps`, `findutils`, `gzip`, `unzip`, `gnutar`, `diffutils`

**Default jail permissions:** network access, timezone info, no new sessions, tmpfs at `/tmp`, read-write access to `~/.config/opencode`, `~/.local/share/opencode`, `~/.local/state/opencode`, and read-write access to the project root.

## Example Configuration

```nix
# devenv.nix
{ pkgs, ... }: {
  # Standard Rust environment - this compiler is automatically included
  # in the opencode jail through addProjetPackages = true
  languages.rust.enable = true;
  languages.rust.channel = "stable";

  programs.opencode = {
    enable = true;

    # Packages only available inside the jail - analysis and management tools
    packages = with pkgs; [
      cargo-expand     # Expand macros to see generated code
      cargo-edit       # Add/remove dependencies via CLI
      cargo-tree       # Visualize dependency tree
    ];

    # Share cargo registry cache between host and jail for faster builds
    jailCombinators = with pkgs.jail.combinators; [
      (rw-bind "~/.cargo/registry" "~/.cargo/registry")
    ];
  };
}
```
