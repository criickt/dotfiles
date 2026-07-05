{
  inputs,
  username,
  ...
}:
inputs.nix-darwin.lib.darwinSystem {
  specialArgs = { inherit inputs username; };
  modules = [
    inputs.home-manager.darwinModules.home-manager
    inputs.nix-homebrew.darwinModules.nix-homebrew
    ./admin.nix
  ];
}
