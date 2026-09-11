# Provisioning the LLM contributor host

`ucore-llm.bu` describes a headless, ssh-only Fedora CoreOS host for running
LLM agents as hive contributors. It provisions exactly one login user
(`dbaggett`, keys only), rootless-podman subid ranges, a short work root, and
the memory/inotify limits that agent workloads actually hit.

The image side lives in `../recipes/recipe.yml`; this side is install-time
configuration and is **not** baked into the image.

## Render

```
./render.sh                      # injects ~/.ssh/id_ed25519.pub
./render.sh ~/.ssh/other.pub     # or a specific key
```

This writes `ucore-llm.ign`, which is gitignored — it contains your public key
and there is no reason to commit it.

## Install into a libvirt VM

Grab a stock Fedora CoreOS qcow2, then boot it with the Ignition config
attached via `fw_cfg`:

```
virt-install \
  --name ucore-llm \
  --vcpus 6 \
  --memory 16384 \
  --os-variant fedora-coreos-stable \
  --import --graphics none \
  --disk size=120,backing_store=/var/lib/libvirt/images/fedora-coreos.qcow2 \
  --qemu-commandline="-fw_cfg name=opt/com.coreos/config,file=$PWD/ucore-llm.ign"
```

Then rebase onto the custom image:

```
sudo bootc switch ghcr.io/danathar/ublue-ucore-llm:latest
sudo systemctl reboot
```

That switch cannot enforce the signature policy, because the policy ships
inside the image (`ublue-os-signing`) and is not on a stock FCOS install yet.
Once you have booted the image, switch again to enforce it:

```
sudo bootc switch --enforce-container-sigpolicy ghcr.io/danathar/ublue-ucore-llm:latest
sudo systemctl reboot
```

If you would rather have the VM rebase itself on first boot, add a oneshot
unit to the `systemd:` section of the `.bu` rather than doing it by hand.

## Sizing

The agents are API-backed, so no memory goes to model weights. It goes to the
agent CLIs (node, roughly 300 MB–1.5 GB each once contexts get long), to
whatever those agents build and test, and to page cache. Budget about
`concurrent agents × 2 GB` plus build headroom: 16 GB is comfortable for four
Go-building contributors, 8 GB will thrash under `go test ./...`.

Give the VM fixed memory rather than ballooning — the balloon driver
interacting with a compile spike is a bad time.

## Agent CLIs are installed per-user, not in the image

Claude Code, Codex CLI and Antigravity CLI all authenticate per-user and
update themselves, and `/usr` is read-only on a bootc system -- an in-image
copy could never update itself, and every release would mean an image rebase.
They install into `~/.local/bin`, which sits under `/var/home` and survives a
rebase along with their credentials.

The image ships an installer for all three:

```bash
llm-agents-install              # claude, codex and agy
llm-agents-install claude agy   # or just the ones you want
```

Note that `agy` (Antigravity) is a native Go binary from Google's own
installer. Hive's docs say `brew install --cask antigravity-cli`, but that is
macOS-only -- Homebrew casks do not exist on Linux.

### Logging in over ssh with no browser

Subscription (Pro/Max/Plus) logins all want a browser, which this host does
not have:

- **Claude Code** — `claude setup-token` is the headless path. The interactive
  `/login` also works: it prints a URL you open on your workstation and paste
  the code back.
- **Codex CLI** — its login uses a **localhost callback on port 1455**, so you
  need `ssh -L 1455:localhost:1455 dbaggett@ucore-llm` before starting it, or
  the flow just hangs.
- **Gemini CLI** — browser handoff with a paste-the-code fallback.

With no desktop there is no keyring, so these fall back to plaintext
credential files under `~/.claude`, `~/.codex` and `~/.config`. That works,
but it means snapshots of this VM's disk contain live credentials — treat them
accordingly, and give the host its own GitHub identity rather than forwarding
an agent or reusing a personal key.

## Two Ignition traps worth remembering

**Ignition will not overwrite a file that already exists.** It aborts the
entire config with `A file exists there already and overwrite is false` and
drops the machine into an emergency shell — a single colliding path takes down
everything, including user creation. If you must touch a file FCOS already
ships, use `append:` or set `overwrite: true` deliberately.

**Do not hand-write `/etc/subuid` and `/etc/subgid`.** FCOS's `useradd`
allocates subid ranges for Ignition-created users on its own (verified:
`dbaggett:589824:65536` appears without any help). Adding your own range does
not replace that one, it stacks with it — `podman unshare cat /proc/self/uid_map`
then shows both, which works but is not what anyone intended.

## Why `/var/w`

hive's `src/pkg/agent` tmux-socket tests overflow `sockaddr_un.sun_path` when
the checkout sits at a deep path, and the failure reads like a genuine
upstream break rather than a path-length problem. `/var/w` keeps clones short.
