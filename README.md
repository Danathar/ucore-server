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

To rebase an existing atomic Fedora installation to the latest build:

```bash
sudo bootc switch ghcr.io/danathar/ublue-ucore-llm:latest
sudo systemctl reboot
```

`bootc` takes a **plain image reference**. The `ostree-unverified-registry:`
and `ostree-image-signed:docker://` prefixes are `rpm-ostree` syntax and
`bootc` rejects them with `invalid reference format`; `--enforce-container-sigpolicy`
is a bare flag, not `=false`.

### Enforcing the signature policy

This is a second step on purpose, not a two-stage ritual carried over from
`rpm-ostree`. The policy that trusts this image — the `policy.json` entry for
`ghcr.io/danathar/ublue-ucore-llm` and its `registries.d` file — is installed
**by the image itself**, via `ublue-os-signing`. Until you have booted it once,
there is nothing on the machine that could verify the signature, so the first
switch cannot enforce one.

Once you are running the image:

```bash
sudo bootc switch --enforce-container-sigpolicy ghcr.io/danathar/ublue-ucore-llm:latest
sudo systemctl reboot
```

`bootc status` then reports the target as
`ostree-image-signed:docker://ghcr.io/danathar/ublue-ucore-llm:latest` — that
signed form is bootc's own bookkeeping, not something you ever type.

Note the tag. `image-version: stable` in the recipe selects uCore's *stable
stream as the base*; it does not create a `stable` tag on the output. BlueBuild
publishes `latest`, a date tag (`20260911`), a Fedora major tag (`44`), and
`<date>-<major>`. Pin to the major tag if you want to be sure a rebase never
carries you across a Fedora release:

```bash
sudo bootc switch ghcr.io/danathar/ublue-ucore-llm:44
```

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
