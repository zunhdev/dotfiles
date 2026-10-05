# Dotfiles

Personal configuration for a small, terminal-focused toolset, with a mostly
[Kansō](https://github.com/webhooked/kanso.nvim)-inspired colour scheme.
The repository is arranged as a collection of
[GNU Stow](https://www.gnu.org/software/stow/) packages, so each top-level
directory mirrors the paths it manages beneath the home directory.

## What's included

| Package | Configuration |
| --- | --- |
| `ghostty` | Ghostty settings using Kansō Ink and CommitMono Nerd Font |
| `helix` | Editor preferences and Kansō theme variants |
| `herdr` | Herdr theme, key bindings, plugin settings, and `install-plugins.sh` |
| `lazygit` | Lazygit UI colours and preferences |
| `yazi` | Yazi theme plus Ink, Mist, Pearl, and Zen flavour variants |

## Installation

The applications you want to configure must already be installed. GNU Stow is
also required; on macOS it can be installed with Homebrew:

```sh
brew install stow
```

Clone the repository, then stow any or all packages into your home directory:

```sh
git clone https://github.com/zunhdev/dotfiles.git ~/dotfiles
cd ~/dotfiles
stow --no-folding --target="$HOME" ghostty helix herdr lazygit yazi
```

`--no-folding` makes Stow link individual managed files instead of replacing an
entire application directory with a symlink. This distinction matters for
applications such as Herdr and Lazygit, which write logs, sockets, sessions,
recent repositories, and other machine-local state beside their configuration.
That runtime state stays in `~/.config` while files such as
`~/.config/helix/config.toml` point back into this repository.
Package-local Stow ignore lists provide an additional safeguard for generated
Herdr and Lazygit files that may already exist during a restow.

If a destination already exists, move or back it up before running Stow.
Packages can be installed individually by naming only the ones you need.

The Ghostty configuration expects `CommitMono Nerd Font` to be available. The
included Helix and Yazi themes do not require separate theme repositories.

### Herdr plugins

The Herdr config relies on three plugins (`numbered.ports`, `herdr.auto-title`
and `hhdebb.herdr-radar`) that Herdr keeps outside this repository, so stowing
the package alone leaves the sidebar, tab bar and ports keybinding inert. With
Herdr running, install them with:

```sh
sh herdr/install-plugins.sh
```

The script reports missing prerequisites (`jq`, `go`, Node 18+) rather than
installing them, installs whichever plugins are absent, and starts the
herdr-radar daemon. Pass `--check` to only report prerequisites. herdr-radar
installs its icon font and writes the Ghostty codepoint map itself; the map is
already tracked in the `ghostty` package.

The herdr-radar sidebar block in `config.toml` carries two hand-added Spaces
rows (`$portlist`, and `branch` with `git_status`). The plugin regenerates that
block on its `configure` and `view-native` actions, so re-add the rows after
running either.

## Updating and removing

Pull changes and re-stow the packages after files are added or reorganised:

```sh
cd ~/dotfiles
git pull
stow --restow --no-folding --target="$HOME" ghostty helix herdr lazygit yazi
```

To remove a package's symlinks without deleting its files from the repository:

```sh
stow --delete --no-folding --target="$HOME" helix
```

## Notes

- These settings are tailored to a personal setup; review them before use.
- Herdr and Lazygit runtime files are deliberately excluded from Git. The
  repository tracks `config.toml` and `config.yml`, respectively.
- Local edits to managed configuration files modify this repository through
  their file-level symlinks, making them easy to review with `git diff`.
