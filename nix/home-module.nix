# Home Manager integration for rPlayHub.
#
# User-level only: the package, the desktop entry and the DDI helper. On a
# non-NixOS host the GUI still expects /usr/share/rplayhub for its fonts; the
# host's system bootstrap must point that at the package, exactly as NixOS does
# with a tmpfiles rule.
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

    desktopEntry = mkOption {
      type = types.bool;
      default = true;
      description = "Install a desktop entry for the GUI.";
    };
  };

  config = mkIf cfg.enable {
    home.packages = [ cfg.package ];

    xdg.desktopEntries.rplayhub = mkIf cfg.desktopEntry {
      name = "rPlayHub";
      comment = "Mirror and control an iPhone";
      exec = "${cfg.package}/bin/rplayhub";
      icon = "rplayhub";
      terminal = false;
      categories = [ "Utility" ];
      settings.Keywords = "iphone;ios;mirror;device hub;phone;";
    };

    xdg.dataFile = mkIf cfg.desktopEntry {
      "icons/hicolor/128x128/apps/rplayhub.png".source =
        "${cfg.package}/share/icons/hicolor/128x128/apps/rplayhub.png";
    };
  };
}
