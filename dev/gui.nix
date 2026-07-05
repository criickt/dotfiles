{
  lib,
  pkgs,
  ...
}:
let
  isDarwin = pkgs.stdenv.hostPlatform.isDarwin;
  mod = if isDarwin then "cmd" else "alt";
  closeBind = if isDarwin then "cmd+w" else "alt+q";

  consoleet = pkgs.stdenvNoCC.mkDerivation {
    pname = "consoleet-oldschoolpc";
    version = "2.2.1";
    src = pkgs.fetchurl {
      url = "https://inai.de/files/consoleet/consoleet-oldschoolpc-2.2.1.tar.zst";
      hash = "sha256-kYRmOnDnKpP09ipw7TMbxtsz56SZI7NIczDTpGF5/04=";
    };
    nativeBuildInputs = [ pkgs.zstd ];
    installPhase = ''
      runHook preInstall
      mkdir -p $out/share/fonts/opentype
      cp *.otf $out/share/fonts/opentype/
      runHook postInstall
    '';
  };

  mpvSettings = {
    alang = [ "en" ];
    slang = [ "en" ];
    embeddedfonts = "no";
    sub = "yes";
    sub-delay = 1.9;
    sub-border-style = "background-box";
    sub-border-size = 0;
    sub-color = "#66FFFFFF";
    sub-back-color = "#66000000";
    sub-pos = 5;
    sub-ass-override = "strip";
  };
in
{
  _module.args.mpvSettings = mpvSettings;
  home.packages = [ consoleet ];

  programs = {
    kitty = {
      enable = true;
      package = pkgs.kitty.overrideAttrs (old: {
        NIX_CFLAGS_COMPILE =
          (old.NIX_CFLAGS_COMPILE or "")
          + (if isDarwin then " -mcpu=native -mtune=native" else " -march=native -mtune=native");
      });
      shellIntegration.enableZshIntegration = true;
      settings = {
        font_family = lib.mkForce "Consoleet EGA 8x14 Smooth";
        font_size = lib.mkForce (if isDarwin then 18.5 else 14);
        tab_bar_edge = "top";
        confirm_os_window_close = 0;
        enable_audio_bell = 0;
        tab_bar_style = "separator";
        tab_separator = " | ";
        tab_title_max_length = 23;
        input_delay = 0;
        repaint_delay = 2;
        sync_to_monitor = false;
        wayland_enable_ime = false;
        cursor_trail = 0;
        cursor_trail_decay = "0.07 0.15";
        wheel_scroll_multiplier = 5;
        touch_scroll_multiplier = 5;
      };
      keybindings =
        let
          tabs = builtins.listToAttrs (
            map (i: {
              name = "${mod}+${toString i}";
              value = "goto_tab ${toString i}";
            }) (lib.lists.range 1 9)
          );
        in
        {
          "${mod}+t" = "new_tab";
          "${closeBind}" = "close_tab";
          "${mod}+left" = "previous_tab";
          "${mod}+right" = "next_tab";
          "${mod}+," = "move_tab_backward";
          "${mod}+." = "move_tab_forward";
        }
        // tabs;
    };
  };
}
