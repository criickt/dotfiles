{
  inputs = {
    nixpkgs.url = "nixpkgs/bde09022887110deb780067364a0818e89258968";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    stylix = {
      url = "github:danth/stylix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixgl = {
      url = "github:nix-community/nixGL";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs@{ ... }:
    let
      linuxUser = "admin";
      workUser = "work";
      androidUser = "u0_a305";
    in {
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
