{
  description = "ytsurf-downloader - search, watch, or download YouTube videos";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    { nixpkgs, ... }:
    {
      overlays.default = final: _: {
        ytsurf-downloader = final.callPackage ./package.nix { };
      };

      packages = nixpkgs.lib.genAttrs nixpkgs.lib.systems.flakeExposed (system: {
        default = nixpkgs.legacyPackages.${system}.callPackage ./package.nix { };
      });
    };
}
