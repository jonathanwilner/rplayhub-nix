{
  description = "rPlayHub 0.1.3 built from source for x86_64-linux and aarch64-linux";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  outputs = { self, nixpkgs }:
    let
      lib = nixpkgs.lib;
      systems = [ "x86_64-linux" "aarch64-linux" ];
      anyPkgs = nixpkgs.legacyPackages.x86_64-linux;

      rplayhubSrc = anyPkgs.fetchFromGitHub {
        owner = "rPlayAI";
        repo = "rPlayHub";
        rev = "dc502aebdedc89667b1139c2c7da2e313aa3f0dc";
        hash = "sha256-xQ+TguD/NcxYzowJviJqcYTXm6KiAqdVimSqeRUoI1I=";
      };

      forAll = f: lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system} system);
      mk = pkgs: pkgs.callPackage ./nix/rplayhub.nix {
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
