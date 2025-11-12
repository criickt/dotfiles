{ inputs, username, ... }:
let
  homeDirectory = "/home/${username}";
  lib = inputs.nixpkgs.lib;
  system = "aarch64-linux";
  pkgs = import inputs.nixpkgs { inherit system; };

in inputs.home-manager.lib.homeManagerConfiguration {
  inherit pkgs;

  extraSpecialArgs = {
    inherit inputs;
    inherit username;
    inherit homeDirectory;
  };

  modules = [ inputs.stylix.homeModules.stylix ./home.nix ];
}
