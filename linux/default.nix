{ inputs, username, profile ? "admin", ... }:
let
  homeDirectory = "/home/${username}";
  lib = inputs.nixpkgs.lib;
  system = "x86_64-linux";
  pkgs = import inputs.nixpkgs { inherit system; };
  nixgl = inputs.nixgl;

in inputs.home-manager.lib.homeManagerConfiguration {
  inherit pkgs;

  extraSpecialArgs = {
    inherit inputs;
    inherit username;
    inherit homeDirectory;
    inherit nixgl;
  };

  modules = [ inputs.stylix.homeModules.stylix ./${profile}.nix ];
}
