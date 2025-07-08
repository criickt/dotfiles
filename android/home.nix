{ inputs, username, homeDirectory, config, lib, pkgs, ... }:

{
  imports = [ ../dev/home.nix ];
  nix = {
    package = pkgs.nix;
    settings.experimental-features = [ "nix-command" "flakes" ];
  };
  targets.genericLinux = {
    enable = true;
    gpu.enable = false;
  };

  home.username = username;
  home.homeDirectory = homeDirectory;

  nixpkgs.config = { users.defaultUserShell = pkgs.zsh; };
  home.stateVersion = "25.05"; # Please read the comment before changing.

  home.sessionVariables = {
    SSH_ASKPASS = "termux-ssh-askpass";
    SSH_ASKPASS_REQUIRE = "force";
    SSH_AUTH_SOCK = "$PREFIX/var/run/ssh-agent.socket";
  };
  home.packages = with pkgs; [
    fastfetch
    iconv # needed for zsh
  ];
  home.file = {
    "termux-ssh-askpass" = {
      source = ./termux-ssh-askpass;
      target = ".local/bin/termux-ssh-askpass";
      executable = true;
    };
    # taken from nix-on-droid stylix integration
    # it wont work as intended bc you log in to vanilla termux, and this is symlink to prooted nix path
    # therefore you should manually create regular file without .lnk after each change
    ".termux/colors.properties.lnk".text = lib.concatStringsSep "\n" [
      "background = #${config.lib.stylix.colors.base00}"
      "foreground = #${config.lib.stylix.colors.base05}"
      "cursor = #${config.lib.stylix.colors.base05}"
      "# normal"
      "color0 = #${config.lib.stylix.colors.base00}"
      "color1 = #${config.lib.stylix.colors.base08}"
      "color2 = #${config.lib.stylix.colors.base0B}"
      "color3 = #${config.lib.stylix.colors.base0A}"
      "color4 = #${config.lib.stylix.colors.base0D}"
      "color5 = #${config.lib.stylix.colors.base0E}"
      "color6 = #${config.lib.stylix.colors.base0C}"
      "color7 = #${config.lib.stylix.colors.base05}"
      "# bright"
      "color8 = #${config.lib.stylix.colors.base02}"
      "color9 = #${config.lib.stylix.colors.base08}"
      "color10 = #${config.lib.stylix.colors.base0B}"
      "color11 = #${config.lib.stylix.colors.base0A}"
      "color12 = #${config.lib.stylix.colors.base0D}"
      "color13 = #${config.lib.stylix.colors.base0E}"
      "color14 = #${config.lib.stylix.colors.base0C}"
      "color15 = #${config.lib.stylix.colors.base07}"
    ];
  };

  programs = {
    home-manager.enable = true;
    claude-code.enable = true;
    zsh = {
      initContent = let
        localBin = lib.mkOrder 1500 ''export PATH="$HOME/.local/bin:$PATH"'';
      in lib.mkMerge [ localBin ];
      shellAliases = {
        hmu =
          "nix flake update --flake ~/.config/home-manager && NIXPKGS_ALLOW_UNFREE=1 home-manager switch --flake ~/.config/home-manager#${username}@android --impure";
      };
    };

  };
  gtk.enable = false;
  systemd.user.enable = false;
  qt.enable = false;
  xdg.portal.enable = false;

  stylix = {
    enable = true;
    autoEnable = false;
    targets = {
      fzf.enable = true;
      gitui.enable = true;
      yazi.enable = true;
      zellij.enable = true;
    };
    base16Scheme = "${pkgs.base16-schemes}/share/themes/da-one-ocean.yaml";
    polarity = "dark";
  };
}
