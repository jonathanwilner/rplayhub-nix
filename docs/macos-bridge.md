# Running the phone window on a Linux desktop (the Mac bridge)

Goal: sit at the Linux desktop and use the iPhone there — mirror, mouse, keyboard —
without giving up on the hosts that already work.

## Why a bridge exists

Everything on the Linux side ran into the same wall: Apple only lets a Mac perform
wireless control of an iPhone. Measured in this project, on real hardware:

| Attempt on Linux | Result |
| --- | --- |
| rPlay AirPlay touch injection | clicks received, `iap_re_enable_assistive_touch: skipped (auth not yet ok)`, zero `send_touch` |
| rPlay classic Bluetooth HID | SDP registered, vendor never emits button reports; `send_touch rc=-1` |
| Custom BLE HID peripheral (BlueZ, `rplay-hid`) | registers and advertises (verified on air), iOS answers **"pairing unsuccessful"** |
| Wireless CoreDevice via `pymobiledevice3` | iOS does not advertise `_remotepairing-manual-pairing._tcp` to a Linux host |

Two findings worth keeping:

1. **The wireless pairing credential is not a file.** After a successful wireless
   pairing on the Mac there is nothing under
   `~/Library/Containers/com.apple.CoreDevice.remotepairingd/.../RemotePairing/`,
   nothing in `/var/db`, and no keychain item by name. It is held by the login
   keychain / Secure Enclave. No disassembly can extract it, so the transplant
   idea (copy the record to Linux) is impossible by construction.
2. **iOS pairs HID peripherals from AssistiveTouch, not from Settings → Bluetooth.**
   With AssistiveTouch on: *Settings → Accessibility → Touch → AssistiveTouch →
   Devices → Bluetooth Devices*. Any future Linux HID attempt should pair there;
   pairing from the Bluetooth settings screen is not the same code path.

So the working arrangement puts the phone-facing work on the Mac and uses the
Linux machine as screen and input:

```
armstrong screen
└── TigerVNC window → dropshot desktop
    ├── iPhone Mirroring   wireless, clicks and keyboard, no cable
    └── rPlayHub           engine on the Mac, HEVC stream, device panel
```

iPhone Mirroring is the only path in this project that is wireless *and* accepts
input. rPlayHub on the Mac still needs the USB cable for video, so prefer iPhone
Mirroring when the cable is not acceptable.

## Setting up the bridge

On the Mac (macOS 27):

```sh
# Screen Sharing on. Remote Management (ARD) must stay OFF: with ARD enabled,
# plain VNC clients are rejected with "Authentication failed: Management
# application is open."
sudo launchctl load -w /System/Library/LaunchDaemons/com.apple.screensharing.plist

# The bridge dies if the Mac sleeps.
sudo pmset -a sleep 0 disksleep 0 standby 0 powernap 0 displaysleep 15
```

`launchctl enable system/com.apple.screensharing` is not enough on current macOS;
the job above is what actually opens port 5900. Verify with `nc -z 127.0.0.1 5900`.

On the Linux desktop:

```sh
# One-time: store the Mac account password in vncpasswd format (mode 0600).
vncpasswd -f > ~/.vnc/dropshot.passwd <<< 'the-mac-account-password'
./scripts/dropshot-vnc            # connects and reuses the stored password
```

macOS Screen Sharing authenticates with the **account password**, so the stored
file is that password in vncpasswd's obfuscated (not encrypted) format. Keep it
mode 0600, never commit it, and delete it if the password changes.

## Operating notes

- Clicking inside the phone window needs no special mode; the wheel scrolls.
- Mac-level shortcuts (Cmd+…) act on the Mac, not the phone.
- Closing the iPhone Mirroring window ends the session. Leave it open.
- The added latency is one LAN VNC hop. Input still travels
  Linux → Mac → wireless → phone, so it is one hop more than using the Mac directly.
- Video quality is what the Mac renders; VNC re-encodes it. For maximum sharpness
  run iPhone Mirroring on the Mac directly.

## Evidence

- Bridge live, iPhone Mirroring on armstrong's screen:
  https://debug.thewilners.com/#shot=20261026T184252Z-armstrong-superdevice-bridge-b4ae061163-13a90367
- Input reaching the Mac through the bridge (Photos opened from armstrong):
  https://debug.thewilners.com/#shot=20261026T184111Z-armstrong-superdevice-bridge-dbf2ef5824-3977ffe4
