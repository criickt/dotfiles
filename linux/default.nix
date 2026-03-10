{ inputs, username, profile ? "admin", ... }:
let
  homeDirectory = "/home/${username}";
  lib = inputs.nixpkgs.lib;
  system = "x86_64-linux";
  pkgs = import inputs.nixpkgs {
    inherit system;
    overlays = [ ];
  };
in inputs.home-manager.lib.homeManagerConfiguration {
  inherit pkgs;

  extraSpecialArgs = {
    inherit inputs;
    inherit username;
    inherit homeDirectory;
  };

  modules = [ inputs.stylix.homeModules.stylix inputs.nix-index-database.homeModules.nix-index ./${profile}.nix ];
}
