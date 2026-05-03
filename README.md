# Th3Moog-Kali

Kali Linux configuration for offensive security work — zsh prompt with
network/target tracking, engagement directory scaffolding, listener helpers, vim
config, and an installer to configure a fresh Kali install for my prefered baseline.

## What's in here

```
Th3M00g-Kali/
├── install.sh              symlink dotfiles into $HOME, configure git, restore pipx tools
├── README.md               this file
├── docs/
│   ├── installation.gif                   installation demonstration
│   ├── engagement_scaffold_setup.gif      engagement scaffold setup demonstration
│   ├── listener_setup.gif                 listener setup demonstration
│   └── wipe_reset.gif                     wipe history demonstration   
└── src/
    ├── zshrc               zsh config: prompt, helpers, aliases
    ├── vimrc               vim config: line numbers, 80-char marker, sane defaults
    ├── inputrc             readline config (affects bash, python REPL, gdb, etc.)
    ├── zshrc.local.example template for machine-specific overrides
    └── pipx-tools.txt      list of pipx tools to restore on fresh setup
```

## Quick install

![Installation Demo:](./%20docs/installation.gif)

On a fresh Kali machine:

```bash
git clone https://github.com/Th3M00g/Th3M00g-Kali.git ~/Th3M00g-Kali
cd ~/Th3M00g-Kali
chmod +x ./install.sh
./install.sh
```

Then open a new shell (or `exec zsh`) and you're set up.

To preview what `install.sh` will do without making changes:

```bash
./install.sh -n
```

## What `install.sh` does for you automatically

- **Symlinks dotfiles** from `src/` into `$HOME` (`~/.zshrc`, `~/.vimrc`, `~/.inputrc`)
- **Backs up** any existing dotfiles to `~/.dotfiles-backup-<timestamp>/` before overwriting
- **Creates required directories** (`~/.vim/undo` for persistent undo, `~/.config`)
- **Sets git basics**: `user.name`, `user.email`, `init.defaultBranch=main`,
  `push.autoSetupRemote=true`
- **Restores pipx tools** listed in `src/pipx-tools.txt` (skipped if pipx isn't installed)

Re-running the script is safe — it skips files that are already correctly
linked. Use `-f` to force re-link.

## What you need to configure manually

A few things are intentionally not automated because they're end-user specific
or sensitive:

### 1. Edit `install.sh` git identity

Open `install.sh` and change these two lines to your actual values:

```bash
GIT_NAME="your-name"
GIT_EMAIL="your-email@example.com"
```

### 2. Set up `~/.zshrc.local` for private values

The committed `zshrc` is sanitized — any aliases or paths pointing to private
repos, internal tools, or machine-specific locations live in a separate
`~/.zshrc.local` file that is sourced at the end of `zshrc`.

To populate it:

```bash
cp ~/Th3M00g-Kali/src/zshrc.local.example ~/.zshrc.local
vim ~/.zshrc.local
```

Uncomment and edit the examples for whatever applies to you. Common uses:

- Aliases pointing into private playbook/tool repos
- `PATH` additions for vendor or custom tools
- `ENGAGEMENTS_DIR` override if you keep engagements outside `~/Engagements`

`~/.zshrc.local` is **not** symlinked or committed — it stays on the local
machine only.

### 3. Populate `pipx-tools.txt` with your actual tools

The committed `pipx-tools.txt` has examples but no active entries. To capture
what's currently installed on your machine:

```bash
pipx list --short | awk '{print $1}' >> ~/Th3M00g-Kali/src/pipx-tools.txt
```

## Features

### Custom zsh prompt

I designed this zsh prompt to give me at-a-glance situational awareness of network interfaces of consequence during engagements as well as provide some useful helper functions to decrease setup time.  

```
┌──(user㉿host)-[IF - eth0:192.168.1.10]-[VPN - tun0:10.10.14.5]-[LIG - ]-[~]
└─$
```

- **`[IF - iface:ip]`** — interfaces you own (eth, wlan, etc.).
- **`[VPN - iface:ip]`** — accessed VPN tunnels (`tun*`).
- **`[LIG - iface]`** — ligolo interfaces , supports IPv4, IPv6-only or no-IP states.
- **`[VPN - ]` / `[LIG - ]`** — dimmed placeholder when nothing connected.
- **`>>>[TGT=ip]`** — current target (hidden when unset).

Network state refreshes on every prompt redraw — connect/disconnect a VPN and
the next prompt reflects it. Manually triggering a redraw is sometimes required.

### Engagement scaffolding

![Engagment Scaffold Demo:](./%20docs/engagement_scaffold_setup.gif)

Two engagement types (Standalone and Active Directory), organized in phase directories:

```bash
new_engagement standalone <name>                       # single box
new_engagement ad <name> <host1> <host2> [host3 ...]   # AD set
```

Creates a directory tree under `~/Engagements/<name>/` (override with
`$ENGAGEMENTS_DIR`):

```
<name>/
├── 00_admin/                  scope, notes, hosts list
│   ├── notes.md               phase-structured running log
│   ├── scope.md
│   └── hosts.txt               (AD only)
├── 01_recon/                  per-host subdirs for AD; flat for standalone
│   └── screenshots/
├── 02_access/
│   └── screenshots/
├── 03_privesc/
│   └── screenshots/
├── 04_loot/
│   ├── creds.md
│   └── hashes.md
├── 05_proof/
│   └── screenshots/
└── 06_domain/                 (AD only)
    ├── bloodhound.md
    └── screenshots/
```

`notes.md` is pre-seeded with a phase-structured template ready to fill in as
you work. Designed as source material for a SysReptor (or similar) report at
the end of the engagement.

### Target helpers

```bash
tgt 10.10.11.5     # validate IPv4, set $TGT and zsh [TGT=] prompt.
untgt              # clear $TGT
```

`tgt` validates the IP shape and octet ranges before exporting to zsh prompt.

### Listener helper

![Listener Demo](./%20docs/listener_setup.gif)

```bash
listener up [interface||ip] [port]   # set $KALI_IP / $LPORT (default: tun0:1337)
listener down                        # clear vars
listener status                      # show current config
listener start                       # launch sudo rlwrap -cAr nc -nvlp $LPORT
listener help                        # full help
```

Auto-detects IPv4 from interface name, or takes a literal IP for
`0.0.0.0`-style binds.

### History wipe

![wipe-history Demo:](./%20docs/wipe_reset.gif)

End-of-engagement cleanup for shell and common tool histories:

```bash
wipe-history       # prompt before wiping
wipe-history -y    # skip confirmation
wipe-history -n    # dry run
```

Wipes `~/.zsh_history`, `~/.bash_history`, `~/.python_history`, `~/.viminfo`,
`~/.lesshst`, and several database client histories. Files are truncated, not
deleted, so tools that expect them to exist don't break.

## Vim config highlights

- Line numbers (relative + absolute current)
- 80-character vertical marker
- Persistent undo across sessions (in `~/.vim/undo/`)
- Filetype-specific indentation (Python, Go, C, Bash, YAML, JSON, Markdown)
- Trailing whitespace stripped on save (except Markdown)
- Sensible leader mappings (`<Space>w` to save, `<Space>q` to quit, etc.)
- `Ctrl-h/j/k/l` window navigation
- `Alt-j/k` to move lines up/down

No plugins required — pure vanilla vim that works on any fresh install.

## Layout philosophy

- **`src/`** holds anything that gets symlinked or read on install
- **Sensitive values live in `*.local` files** (gitignored) and are sourced
  from the committed Th3M00g-Kali via `[[ -f ~/.zshrc.local ]] && source ~/.zshrc.local`
- **`*.example` files** in `src/` show the pattern; users copy them to
  `~/.<file>.local` and edit
- **`install.sh` is idempotent** — safe to re-run after pulling updates

## Updating

After pulling changes from the repo:

```bash
cd ~/Th3M00g-Kali
git pull
./install.sh        # re-link any new files; existing links untouched
exec zsh            # reload shell to pick up zshrc changes
```

## Caveats

- **Kali-tested only.** Should work on Debian/Ubuntu derivatives but I havent 
validated it there.
- **zsh required.** Bash users would need a separate `.bashrc`.
- **Some helpers assume `tun0` for VPN.** If your VPN uses a different 
interface name pattern, edit the prompt-building loops in `src/zshrc`.

## License

[LICENSE](LICENSE)