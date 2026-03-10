{
  inputs = {
    nixpkgs.url = "nixpkgs/98a8e5122ef525c9651afe7fdbe9c313b3ccc026";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    stylix = {
      url = "github:danth/stylix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    sshf = {
      url = "github:theoborealis/sshf";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{ ... }:
    let
      linuxUser = "admin";
      workUser = "work";
      androidUser = "u0_a305";
    in
    {
      homeConfigurations = {
        "${androidUser}@android" = import ./android {
          inherit inputs;
          username = androidUser;
        };
        "${linuxUser}@linux" = import ./linux {
          inherit inputs;
          username = linuxUser;
          profile = "admin";
        };
        "${workUser}@linux" = import ./linux {
          inherit inputs;
          username = workUser;
          profile = "work";
        };
      };
    };
}
