# rPlayHub for Linux — Nix flake, built from source

[rPlayHub](https://github.com/rPlayAI/rPlayHub) is a CoreDevice host: it mirrors and controls an
iPhone over USB, without Xcode, and without installing anything on the phone. This flake builds
the Linux client and engine from the upstream GPL-3.0 source for **x86_64-linux** and
**aarch64-linux**, and ships NixOS and Home Manager modules.

The upstream project publishes an amd64 `.deb` only. Building from source is what makes arm64
possible: the engine and GUI are portable C and C++, and the two native dependencies — FFmpeg with
the RVRA patch and the libimobiledevice stack — build cleanly on both architectures.

## What is built

| Component | Source | Notes |
|---|---|---|
| `cdhost` | `host-c/` | the engine: talks to the phone, serves `127.0.0.1:9876` / `:9877` |
| `rplayhub` | `client-c/` | the GUI: SDL2 + Dear ImGui |
| FFmpeg 8.1.2 + RVRA | `nix/ffmpeg-rvra.nix` | stock FFmpeg garbles the phone's mid-stream resolution changes |
| libimobiledevice stack | nixpkgs | libimobiledevice 1.4, libplist, glue, libtatsu, libusbmuxd |
| lwIP 2.2.1, ImGui 1.91.8, json 3.11.3 | pinned in `nix/rplayhub.nix` | exactly the versions `scripts/` pin upstream |

## Use

```sh
nix run github:jonathanwilner/rplayhub-nix

# NixOS
inputs.rplayhub.url = "github:jonathanwilner/rplayhub-nix";
imports = [ inputs.rplayhub.nixosModules.default ];
programs.rplayhub.enable = true;

# Home Manager (non-NixOS hosts need the /usr/share/rplayhub font path, see below)
programs.rplayhub.enable = true;
```

Then, once per phone reboot:

```sh
rplayhub-fetch-ddi      # Apple's Developer Disk Image -> ~/.local/share/rplayhub/iOS_DDI
```

Plug the phone in, unlock, tap Trust, then:

```sh
rplayhub-engine         # the engine; unprivileged, userspace TCP/IP
rplayhub                # the GUI
```

## The compiled-in font path

The GUI loads its fonts from `/usr/share/rplayhub/fonts`. On NixOS the module publishes that path
with a tmpfiles rule. On other hosts create the same link once:

```sh
sudo ln -sfn "$(readlink -f "$(command -v rplayhub)" | xargs dirname | xargs dirname)/share/rplayhub" /usr/share/rplayhub
```

Without it the GUI still starts and falls back to a default font.

## Licence

Upstream is GPL-3.0; this packaging follows it.
