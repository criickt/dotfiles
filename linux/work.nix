{
  lib,
  pkgs,
  username,
  homeDirectory,
  ...
}:
{
  imports = [ ../dev/home.nix ];

  nixpkgs.config = {
    users.defaultUserShell = pkgs.zsh;
  };
  targets.genericLinux = {
    enable = true;
    gpu.enable = false;
  };

  home = {
    inherit username homeDirectory;
    stateVersion = "25.05";
    sessionVariables = {
      TERM = "xterm-256color";
      SUDO_EDITOR = "$HOME/.nix-profile/bin/hx";
    };
    shellAliases = {
      hmu = "NIXPKGS_ALLOW_UNFREE=1 home-manager switch --flake 'path:${homeDirectory}/.config/home-manager#work@linux' --impure";
    };
  };

  home.packages = with pkgs; [
    fastfetch
  ];

  systemd.user = {
    enable = true;
    systemctlPath = "/usr/bin/systemctl";
    startServices = "sd-switch";
  };

  services = {
    home-manager.autoExpire = {
      enable = true;
      frequency = "weekly";
      timestamp = "-7 days";
      store.cleanup = true;
    };
  };

  programs = {
    helix.settings.theme = lib.mkForce "nyxvamp-obsidian";
    zsh = {
      enable = true;
      initContent = lib.mkBefore ''
        ZSH_DISABLE_COMPFIX=true
      '';
    };
  };

  stylix = {
    enable = true;
    base16Scheme = "${pkgs.base16-schemes}/share/themes/da-one-ocean.yaml";
    polarity = "dark";
  };
}
