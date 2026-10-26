# Running the rPlayHub engine on a Mac, GUI elsewhere

Useful when the phone is plugged into a Mac and you want to drive it from a
Linux desktop. The engine must live next to the phone; the GUI can be anywhere.

## Build the engine on the Mac

The upstream tree assumes a stock clang and Homebrew libraries. Two things in
this environment needed adjusting:

1. **Homebrew is Nix-managed** on this host: `/opt/homebrew/Library/Taps` is a
   read-only store symlink, so `brew install libimobiledevice` cannot work.
   Use Nix for the libraries instead.
2. **Newer clang/SDK** needs `<errno.h>` pulled in before `compat.h` uses
   `errno`, and `<stdarg.h>` for the logging macros.

```sh
git clone --depth 1 https://github.com/rPlayAI/rPlayHub ~/rPlayHub
cd ~/rPlayHub
git clone --branch STABLE-2_2_1_RELEASE https://github.com/lwip-tcpip/lwip.git deps/lwip

# 1. libraries from Nix
nix build --no-link --print-out-paths nixpkgs#libimobiledevice nixpkgs#libimobiledevice.dev
nix build --no-link --print-out-paths nixpkgs#libplist          nixpkgs#libplist.dev
nix build --no-link --print-out-paths nixpkgs#libimobiledevice-glue nixpkgs#libimobiledevice-glue.dev
nix build --no-link --print-out-paths nixpkgs#openssl          nixpkgs#openssl.dev

# assemble one prefix the Makefile can point at
mkdir -p deps/imd/include deps/imd/lib
for s in <libimobiledevice-dev> <libimobiledevice> <libplist-dev> <libplist> \
         <glue-dev> <glue>; do
  cp -RL "$s"/include/. deps/imd/include/ 2>/dev/null || true
  cp -RL "$s"/lib/.     deps/imd/lib/     2>/dev/null || true
done
mkdir -p deps/ssl
cp -RL <openssl-dev>/include deps/ssl/
cp -RL <openssl>/lib        deps/ssl/

# 2. the one source fix
sed -i '' '2a\
#include <errno.h>
' host-c/compat.h

# 3. build
export SDKROOT=$(/usr/bin/xcrun --show-sdk-path)
make -C host-c \
  CC="/usr/bin/clang -include stdarg.h" \
  OPENSSL=$PWD/deps/ssl \
  IMD_PREFIX=$PWD/deps/imd
```

`host-c/cdhost` is the engine. Run it with `sudo` (the tunnel needs a utun).

## Run it, then attach the GUI

Order matters: the GUI must attach close to stream start, otherwise it joins
mid-GOP and logs `Could not find ref with POC …` while it waits for an IDR.

```sh
# on the Mac
sudo ~/rPlayHub/host-c/cdhost &
sleep 8

# on the Linux desktop: forward the engine's three ports, then attach
ssh -N -L 19876:127.0.0.1:9876 \
       -L 19877:127.0.0.1:9877 \
       -L 19878:127.0.0.1:9878 user@mac &
rplayhub -h 127.0.0.1 -A 19876 -p 19877
```

`rplayhub-via MAC` automates the tunnel and the GUI.

Clicks, keyboard and audio work through this path — it is the same engine that
drives the phone over USB, with the GUI on the other machine.

## Run it as a service

`launchd/install.sh` installs `/Library/LaunchDaemons/com.rplay.cdhost.plist`
and starts it. The daemon runs `cdhost` as root (the CoreDevice tunnel needs a
utun), keeps it alive, and writes to `/var/log/rplay-cdhost.log`.

```sh
sudo ./launchd/install.sh                       # default engine path
sudo ./launchd/install.sh /path/to/cdhost       # explicit
sudo launchctl print system/com.rplay.cdhost    # state
sudo launchctl bootout system/com.rplay.cdhost  # stop
```

Attach a GUI from any machine with `rplayhub-via <mac-host>`.
