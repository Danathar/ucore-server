# ublue-ucore-llm &nbsp; [![bluebuild build badge](https://github.com/Danathar/ucore-server/actions/workflows/build.yml/badge.svg)](https://github.com/Danathar/ucore-server/actions/workflows/build.yml)

A custom [uCore](https://github.com/ublue-os/ucore) image for a headless,
ssh-only host that runs LLM agents as hive contributors.

The agents are API-backed — nothing infers locally — so this is a *workspace*
image, not a compute one. Its job is to have every command-line tool an agent
reaches for already present, because a missing tool costs a whole turn of
flailing.

- **Image side** — [`recipes/recipe.yml`](recipes/recipe.yml) layers the
  toolchain onto `ghcr.io/ublue-os/ucore:stable`.
- **Host side** — [`ignition/`](ignition/) holds the Butane config for the
  single ssh-only user, rootless-podman subid ranges, memory and inotify
  limits, and the notes on logging agent CLIs in without a browser.

uCore already provides tailscale, tmux, podman, docker, distrobox, rclone,
cockpit, zfs and the rest; the recipe deliberately does not re-add them.

## Installation

Fresh installs go through Ignition — see [`ignition/README.md`](ignition/README.md)
for the `virt-install` and rebase sequence.

To rebase an existing atomic Fedora installation to the latest build, unsigned
first so the signing policy lands, signed after:

```bash
sudo bootc switch --enforce-container-sigpolicy=false \
  ostree-unverified-registry:ghcr.io/danathar/ublue-ucore-llm:stable
sudo systemctl reboot
```

```bash
sudo bootc switch ostree-image-signed:docker://ghcr.io/danathar/ublue-ucore-llm:stable
sudo systemctl reboot
```

The `stable` tag follows uCore's stable stream. That build still uses the
Fedora version specified in `recipe.yml`, so you will not be accidentally
updated to the next major version.

## ISO

You can generate an offline ISO with the instructions available
[here](https://blue-build.org/learn/universal-blue/#fresh-install-from-an-iso).
These ISOs cannot be distributed on GitHub for free due to their size.

## Verification

These images are signed with [Sigstore](https://www.sigstore.dev/)'s
[cosign](https://github.com/sigstore/cosign). Download `cosign.pub` from this
repo and run:

```bash
cosign verify --key cosign.pub ghcr.io/danathar/ublue-ucore-llm
```

The `cosign` binary is **not** on the image. Verifying a signed rebase does not
use it — `ostree-image-signed:` goes through `containers-policy.json` and the
`ublue-os-signing` policy — and it is a 141 MB static binary to carry for a
command you normally run from your workstation. If an agent on the host needs
it, `golang` is installed:

```bash
go install github.com/sigstore/cosign/v2/cmd/cosign@latest
```

To put it back in the image instead, add to `recipe.yml`:

```yaml
- type: copy
  from: ghcr.io/sigstore/cosign/cosign:v3.1.3
  src: /ko-app/cosign
  dest: /usr/bin/
```
