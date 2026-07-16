{
  inputs = {
    nixpkgs.url = "nixpkgs/f165e44f135784a494bca3d4ab4834c139f0b37d";
    nix-darwin = {
      url = "github:nix-darwin/nix-darwin/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-homebrew.url = "github:zhaofengli/nix-homebrew";
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
      darwinUser = "admin";
    in
    {
      darwinConfigurations."mac" = import ./darwin {
        inherit inputs;
        username = darwinUser;
      };

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
