{
  description = "rPlayHub 0.1.3 built from source for x86_64-linux and aarch64-linux";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  outputs = { self, nixpkgs }:
    let
      lib = nixpkgs.lib;
      systems = [ "x86_64-linux" "aarch64-linux" ];

      # pymobiledevice3 7.7.0 (needed for the wireless RemotePairing path) has one
      # broken dependency in nixpkgs: pyimg4 pins asn1<3.0.0 while nixpkgs ships
      # asn1 3.2.0. Build the older pure-Python asn1 and override it in.
      pmd3For = pkgs:
        let
          py = pkgs.python313Packages;
          asn127 = py.buildPythonPackage rec {
            pname = "asn1";
            version = "2.7.0";
            format = "setuptools";
            src = pkgs.fetchurl {
              url = "https://files.pythonhosted.org/packages/2a/9f/9a45cbf77edbf85006bbd6d0067cc87b6a9291e12b2c958d818132e7e04d/asn1-2.7.0.tar.gz";
              hash = "sha256-RMD8PSjGqSbk1JWf+8G8zzf69NygdSC6LpsbWzb+C9o=";
            };
            doCheck = false;
          };
          pyimg4Fixed = py.pyimg4.override { asn1 = asn127; };
        in
        py.pymobiledevice3.override { pyimg4 = pyimg4Fixed; };
      forAll = f: lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system} system);
      mk = pkgs:
        let
          # Fetched with this system's own pkgs: a source derivation pinned to
          # x86_64-linux cannot be built on aarch64.
          rplayhubSrc = pkgs.fetchFromGitHub {
            owner = "rPlayAI";
            repo = "rPlayHub";
            rev = "dc502aebdedc89667b1139c2c7da2e313aa3f0dc";
            hash = "sha256-xQ+TguD/NcxYzowJviJqcYTXm6KiAqdVimSqeRUoI1I=";
          };
        in
        pkgs.callPackage ./nix/rplayhub.nix {
          inherit rplayhubSrc;
          ffmpeg-rvra = pkgs.callPackage ./nix/ffmpeg-rvra.nix { inherit rplayhubSrc; };
        };
    in
    {
      packages = forAll (pkgs: _: {
        default = mk pkgs;
      });

      nixosModules.default = import ./nix/nixos-module.nix { inherit self; };
      nixosModules.rplayhub = self.nixosModules.default;

      homeManagerModules.default = import ./nix/home-module.nix { inherit self; };
      homeManagerModules.rplayhub = self.homeManagerModules.default;

      formatter = forAll (pkgs: _: pkgs.nixpkgs-fmt);
    };
}
