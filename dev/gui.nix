{
  config,
  lib,
  pkgs,
  ...
}:
let
  isDarwin = pkgs.stdenv.hostPlatform.isDarwin;
  mod = if isDarwin then "cmd" else "alt";
  closeBind = if isDarwin then "cmd+w" else "alt+q";

  consoleet = pkgs.stdenvNoCC.mkDerivation {
    pname = "consoleet-darwin";
    version = "20211008";
    src = pkgs.fetchurl {
      url = "https://inai.de/files/consoleet/consoleet-darwin-20211008.tar.zst";
      hash = "sha256-OStyp7CfiXnxdhn4rYDQnySy+o1lLCRTm+ExTaJ+lz0=";
    };
    nativeBuildInputs = [ pkgs.zstd ];
    installPhase = ''
      runHook preInstall
      mkdir -p $out/share/fonts/opentype
      cp *.otf $out/share/fonts/opentype/
      runHook postInstall
    '';
  };

  # Darwin covers only Latin-1; Terminus-16 Bold Smooth shares its 12/4 pixel grid and 2px strokes and takes
  # every other glyph it has (kitty patched to fall through when a symbol_map font lacks the glyph)
  consoleet-terminus = pkgs.stdenvNoCC.mkDerivation {
    pname = "consoleet-terminus-16";
    version = "4.49.1";
    src = pkgs.fetchurl {
      url = "https://inai.de/files/consoleet/consoleet-terminus-4.49.1.tar.zst";
      hash = "sha256-IH+1gnJYRCm5uD3NIXBslFIs+vg2dq2uUjZkqWpp8SE=";
    };
    nativeBuildInputs = [ pkgs.zstd ];
    installPhase = ''
      runHook preInstall
      mkdir -p $out/share/fonts/opentype
      cp consoleet_ter16bv.otf $out/share/fonts/opentype/
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
  xdg.configFile."kitty/shaders/crt.pipeline".text = "startgroup\n    shaders crt\nendgroup\n";
  home.packages = [
    consoleet
    consoleet-terminus
  ];

  programs = {
    kitty = {
      enable = true;
      package = pkgs.kitty.overrideAttrs (old: {
        NIX_CFLAGS_COMPILE =
          (old.NIX_CFLAGS_COMPILE or "")
          + (if isDarwin then " -mcpu=native -mtune=native" else " -march=native -mtune=native");
        patches = (old.patches or [ ]) ++ [ ./kitty.patch ] ++ lib.optional isDarwin ../darwin/kitty-darwin.patch;
      });
      shellIntegration.enableZshIntegration = true;
      extraConfig = lib.mkIf (config.stylix.enable or false) (
        lib.mkAfter (
          with config.lib.stylix.colors.withHashtag;
          ''
            tab_bar_background ${base00}
            inactive_tab_background ${base00}
            active_tab_background ${base00}
            inactive_tab_foreground ${base02}
          ''
        )
      );
      settings = {
        font_family = lib.mkForce "Consoleet Darwin Smooth";
        font_size = lib.mkForce (if isDarwin then 24 else 14);
        symbol_map = "U+0100-U+10FFFF Consoleet Terminus-16 Smooth";
        tab_bar_edge = "top";
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
        custom_shaders = "crt";
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
          "${mod}+shift+t" = "new_tab_with_cwd";
          "${closeBind}" = "remote_control close-tab";
          "${mod}+," = "move_tab_backward";
          "${mod}+." = "move_tab_forward";
          "ctrl+tab" = "next_tab";
          "ctrl+shift+tab" = "previous_tab";
        }
        // lib.optionalAttrs isDarwin {
          "cmd+opt+left" = "previous_tab";
          "cmd+opt+right" = "next_tab";
        }
        // tabs;
    };
  };
}
