# The workflow

How the tools in this repo fit together, and a three-week plan to make them muscle memory.
Inside Zellij, **`Alt /`** shows the one-page cheat sheet
([`cheatsheet.txt`](home/.config/zellij/cheatsheet.txt)).

## The picture

```
Ghostty (one window, no tabs, no splits)
└── ssh desktop ──▶ Zellij session "main"         home base: scratch shells, dotfiles, admin
                    Zellij session "nvim-config"  ┐
                    Zellij session "my-project"   ┘ one session per project, made by `dev`
                    ├── tab 1 "code"   nvim  (git: Space gg, files: Space e / Space ff)
                    ├── tab 2 "run"    build/server shell │ scratch shell
                    └── floating       lazygit (Alt g), yazi (Alt y), quick shell (Alt f)
```

Every layer has one job:

| Layer | Job | Rule of thumb |
|---|---|---|
| **Ghostty** | draws the screen, sends keys, carries the clipboard (OSC 52) | never use its tabs or splits; Zellij does that and survives disconnects |
| **Zellij session** | one project, with everything still running | switch projects with `Alt s`, not by `cd` |
| **Zellij tab** | one activity: editing, running | two tabs is normal; past four, make a new session |
| **Zellij pane** | something you watch while you work | a server, a test watcher, a log |
| **Neovim** | editing, plus everything code-aware: LSP, git hunks, tests, tasks | if it needs to know about your code, do it here |
| **shell** | everything else | `z`, `y`, fzf keys make it as fast as the editor |

## Who owns which keys

This is the core rule. Once it clicks, nothing collides:

| Keys | Owner | Examples |
|---|---|---|
| `Space` … | **Neovim** | `Space ff` find file, `Space gg` lazygit, `Space rr` run task |
| `Ctrl h/j/k/l` | **everyone**: move to the split/pane in that direction | works the same across Neovim splits and Zellij panes, and past the screen edge to the next tab |
| `Alt h/j/k/l` | **everyone**: resize | same in both |
| `Alt` + other letter | **Zellij** | `Alt n` pane, `Alt f` float, `Alt z` zoom, `Alt 1..9` tabs, `Alt s` sessions |
| `Ctrl g` | **Zellij, rarely** | unlocks the rest of Zellij's keys (rename a tab, detach, scroll mode). The bottom bar shows them. `Ctrl g` again to lock. |

Zellij stays **locked**, so every key reaches whatever runs in the pane, except the few listed
above. You almost never need `Ctrl g`.

> Shell users: `Alt f` and `Alt b` (word forward/back) are taken by Zellij. Use `Ctrl →` / `Ctrl ←`
> instead, which `.zshrc` binds.

## A day

1. **Open Ghostty, `ssh desktop`.** You land in `main`, exactly as you left it.
2. **`dev`** → pick a project (fuzzy list of the folders you visit most), or `dev nvim-config` directly.
   You get that project's session: nvim in tab 1, shells in tab 2. Again tomorrow, same session,
   still running.
   - Started from inside Zellij (e.g. from `main`), `dev` makes the session in the background:
     press `Alt s` and pick it.
3. **Edit** in tab 1. Jump with `Space ff` (files), `Space sg` (grep), `gd` (definition).
4. **Build/run:** `Space rr` for a build whose errors you want to jump to (overseer → quickfix).
   For a server or a watcher, `Alt 2` and start it in the left pane, then `Alt 1` back.
   Or just `Ctrl l` past the right edge of nvim to reach tab 2.
5. **Quick look at something:** `Alt f` opens a floating shell over everything. Check, then `Alt f`
   again to hide it (it keeps running, so it's there next time).
6. **Git:** `Space gg` in nvim. Stage hunks with `Space ghs` as you go; commit and push in lazygit.
7. **Another project needs you:** `Alt s`, pick it. Everything in this one keeps running.
8. **Done for the day:** close the laptop. Nothing to save, nothing to detach.

### Where should a command run?

| Situation | Where |
|---|---|
| one-off, glance at the output | `Ctrl /` (terminal inside nvim) or `zr <cmd>` (floating pane) |
| long-running: dev server, `cargo watch`, `bacon`, logs | tab 2, left pane |
| a build whose errors you want to jump to | `Space rr` (overseer), errors land in quickfix (`Space xq`) |
| tests | `Space tt` nearest, `Space tf` file, `Space tw` watch |
| poke around then come straight back | `Alt f` floating shell |
| browse files visually | `Space e` in nvim, `Alt y` / `y` (yazi) elsewhere |

## Three weeks to make it stick

Immersion means removing the old exits, not adding more tools. Each week adds a few keys and one rule.
Don't learn ahead; use only that week's keys until they're automatic.

### Week 1: one door in

**Rule:** every coding session starts with `ssh desktop` → `dev`. No Ghostty tabs or splits, no
second terminal app. If you need another shell, it's `Alt n` or `Alt f`.

**Keys:** `Ctrl h/j/k/l`, `Alt n`, `Alt f`, `Alt z`, `Alt 1/2`, `Alt s`, `Alt /`.

**Drill (2 min a day):** open `dev`, make three panes with `Alt n`, visit each with `Ctrl h/j/k/l`,
zoom one (`Alt z`), close two (`exit`), float a shell (`Alt f`), hide it, switch to `main` and back
with `Alt s`.

### Week 2: stay in the editor

**Rule:** while editing, don't leave nvim for anything nvim can do. No `git` on the command line
(use `Space gg`), no `ls`/`cd` to find files (`Space ff`, `Space e`), no rerunning builds by hand
(`Space rr`, then `Space ra` → restart).

**Keys:** `Space ff`, `Space sg`, `Space e`, `Space gg`, `Space ghs` (stage hunk), `]h` / `[h` (next /
previous hunk), `Space rr`, `Space xq`, `Ctrl /`.

**Drill:** make one small change entirely without leaving nvim: find the file, edit, run the test,
stage the hunk, commit, push.

### Week 3: a fast shell

**Rule:** no typing long paths. Use `z`, `zi`, `y`, `Ctrl t`, `Alt c`. No retyping old commands
either: use `Ctrl r`.

**Keys:** `z foo`, `zi`, `y`, `Ctrl r`, `Ctrl t`, `Alt c`, `Ctrl x Ctrl e`, `zr <cmd>`, `Alt g`, `Alt y`.

**Drill:** from `main`, open three different projects with `dev`, without typing a full path once.

### Every week: the friction log

The single habit that makes a setup *yours*:

1. Whenever you reach for the mouse, forget a key, or do something three times by hand, write one
   line in a note (`Space .` opens a scratch buffer in nvim; or keep `~/friction.md`).
2. On Friday, fix **one** line: add a keymap, an alias or a layout tweak in `~/dotfiles`, commit,
   push. The other machine gets it with `git pull`.

After three weeks, read the log again. Most of it will already feel ancient.

## Customizing

| Want to… | Edit |
|---|---|
| change the project layout (add a tab, a log pane, …) | [`home/.config/zellij/layouts/dev.kdl`](home/.config/zellij/layouts/dev.kdl) |
| add or change an `Alt` key | [`home/.config/zellij/config.kdl`](home/.config/zellij/config.kdl), and the cheat sheet next to it |
| change how `dev` picks projects or names sessions | `dev()` in [`home/.zshrc`](home/.zshrc) |
| a layout just for one project | put a `.kdl` file in `layouts/`, run `zellij --layout <name>` in that folder |
| Neovim keys | [nvim-config](https://github.com/Kelvinyu1117/nvim-config): `lua/config/keymaps.lua` or the plugin's `keys = {...}` |

## Troubleshooting

- **`Ctrl h/j/k/l` doesn't leave nvim / Zellij asks for permissions:** the first time, Zellij asks to
  allow the navigator plugin: focus that pane and press `y`.
- **`Alt` keys type odd characters on the Mac:** Ghostty needs `macos-option-as-alt = true` (already
  set). Restart Ghostty after linking the config.
- **A key does nothing in Zellij:** you may be unlocked (the bottom bar says NORMAL, not LOCKED);
  `Ctrl g` or `Esc` locks again.
- **The colors look wrong over SSH:** don't set `TERM` in `~/.zshrc.local`; Ghostty installs its
  terminfo on the server for you.
- **Need to end a session for good:** `Alt s`, select it, `Ctrl x`. (`Ctrl q` is unbound on purpose,
  so a stray keypress can't kill a session full of running work.)
