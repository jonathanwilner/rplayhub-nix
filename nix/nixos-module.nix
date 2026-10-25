# NixOS integration for rPlayHub.
#
# The GUI has /usr/share/rplayhub/fonts compiled in, so this module publishes
# that path as a stable symlink. Everything else lives in the user's session;
# the engine runs unprivileged and talks to the phone through usbmuxd.
{ self }:
{ config, lib, pkgs, ... }:
let
  cfg = config.programs.rplayhub;
  inherit (lib) mkIf mkOption mkEnableOption types;
in
{
  options.programs.rplayhub = {
    enable = mkEnableOption "rPlayHub, the iPhone mirroring client";

    package = mkOption {
      type = types.package;
      default = self.packages.${pkgs.stdenv.hostPlatform.system}.default;
      defaultText = lib.literalMD "`rplayhub.packages.${pkgs.stdenv.hostPlatform.system}.default`";
      description = "The rPlayHub package to use.";
    };

    usbmuxd = mkOption {
      type = types.bool;
      default = true;
      description = "Enable usbmuxd, the USB daemon the engine talks to.";
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ];

    services.usbmuxd.enable = mkIf cfg.usbmuxd true;

    # Compiled-in asset path.
    systemd.tmpfiles.rules = [
      "L+ /usr/share/rplayhub - - - - ${cfg.package}/share/rplayhub"
    ];
  };
}
