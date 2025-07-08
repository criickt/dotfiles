{ inputs, username, homeDirectory, config, lib, pkgs, nixgl, ... }:

{
  imports = [ ../dev/home.nix ];
  nix = {
    package = pkgs.nix;
    settings.experimental-features = [ "nix-command" "flakes" ];
  };
  targets.genericLinux = {
    enable = true;
    nixGL = {
      packages = nixgl.packages;
      defaultWrapper = "mesa";
      installScripts = [ "mesa" ]; # "nvidiaPrime" ];
      # vulkan.enable = true; # causes glibcxx ver mismatch
      # offloadWrapper = "nvidiaPrime";
    };
  };

  home.username = username;
  home.homeDirectory = homeDirectory;
  home.sessionVariables = {
    BUILDAH_FORMAT = "docker";
    DOCKER_CONFIG = "$HOME/.config/docker";
    SUDO_EDITOR = "$HOME/.nix-profile/bin/hx";
  };

  nixpkgs.config = {
    allowUnfree = true;
    allowUnfreePredicate = (pkg: true);
    users.defaultUserShell = pkgs.zsh;
  };
  nixpkgs.overlays =
    [ (final: prev: { hyprland = config.lib.nixGL.wrap prev.hyprland; }) ];
  xdg = let
    schemeAppTuples = [
      # browser & PDF
      {
        mime = "text/html";
        app = "librewolf";
      }
      {
        mime = "x-scheme-handler/http";
        app = "librewolf";
      }
      {
        mime = "x-scheme-handler/https";
        app = "librewolf";
      }
      {
        mime = "x-scheme-handler/about";
        app = "librewolf";
      }
      {
        mime = "x-scheme-handler/unknown";
        app = "librewolf";
      }
      {
        mime = "application/pdf";
        app = "librewolf";
      }
      # video
      {
        mime = "video/mp4";
        app = "mpv";
      }
      {
        mime = "video/webm";
        app = "mpv";
      }
      {
        mime = "video/mkv";
        app = "mpv";
      }
      {
        mime = "video/x-matroska";
        app = "mpv";
      }
      {
        mime = "video/quicktime";
        app = "mpv";
      }
      {
        mime = "video/x-msvideo";
        app = "mpv";
      }
      {
        mime = "video/mpeg";
        app = "mpv";
      }
      # audio
      {
        mime = "audio/mpeg";
        app = "mpv";
      }
      {
        mime = "audio/mp4";
        app = "mpv";
      }
      {
        mime = "audio/flac";
        app = "mpv";
      }
      {
        mime = "audio/ogg";
        app = "mpv";
      }
      {
        mime = "audio/x-wav";
        app = "mpv";
      }
      {
        mime = "audio/x-aiff";
        app = "mpv";
      }
    ];
    mimeMap =
      lib.foldl' (acc: { mime, app }: acc // { "${mime}" = "${app}.desktop"; })
      { } schemeAppTuples;
    mimesFor = wantedApp:
      map ({ mime, app }: mime)
      (lib.filter ({ mime, app }: app == wantedApp) schemeAppTuples);
  in {
    enable = true;
    autostart.enable = true;
    mime.enable = true;
    portal = {
      enable = true;
      extraPortals = [ pkgs.xdg-desktop-portal-hyprland ];
      configPackages = [ pkgs.hyprland ];
    };
    desktopEntries = {
      librewolf = {
        name = "librewolf";
        exec = "/usr/bin/librewolf %u";
        categories = [ "Network" "WebBrowser" ];
        mimeType = mimesFor "librewolf";
      };
      mpv = {
        name = "mpv";
        exec = "${pkgs.mpv}/bin/mpv %u";
        categories = [ "AudioVideo" "Player" ];
        mimeType = mimesFor "mpv";
      };
    };
    mimeApps = {
      enable = true;
      defaultApplications = mimeMap;
    };
  };
  fonts.fontconfig.enable = true;
  home.stateVersion = "25.05"; # Please read the comment before changing.

  home.packages = with pkgs; [
    brightnessctl
    dconf # for stylix
    grim
    hyprpicker
    ripdrag
    slurp
    wl-screenrec
    wl-clipboard
    tor-browser

    android-tools
    binsider
    bluetui
    exiv2
    go-chromecast
    fastfetch
    libarchive
    mediainfo
    netcat
    tesseract
    podman-compose

    inter
    nerd-fonts.symbols-only
    nerd-fonts.bigblue-terminal
  ];

  wayland.windowManager.hyprland = let
    workspaces = builtins.concatLists (map (ws:
      let wsStr = toString ws;
      in [
        "$mod, ${wsStr}, workspace, ${wsStr}"
        "$mod SHIFT, ${wsStr}, movetoworkspace, ${wsStr}"
      ]) (lib.lists.range 1 9));
  in {
    enable = true;
    package = pkgs.hyprland;
    systemd.enableXdgAutostart = true;
    systemd.variables = [ "--all" ];
    plugins = [
      #pkgs.hyprlandPlugins.hyprwinwrap
      pkgs.hyprlandPlugins.hypr-dynamic-cursors
    ];
    settings = {
      env =
        [ "ELECTRON_OZONE_PLATFORM_HINT,wayland" "QT_QPA_PLATFORM,wayland" ];
      exec-once = [
        "dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP"
        "waybar"
        "hyprctl setcursor Bibata-Modern-Ice 16"
      ];
      "$mod" = "SUPER";
      bind = [
        "$mod, Q, killactive"
        "$mod, O, exit"
        "$mod, L, exec, /usr/bin/hyprlock"
        "$mod, T, exec, kitty"
        "$mod, B, exec, librewolf"
        "$mod, V, exec, kitty --class clipse -e 'clipse'"
        "$mod, P, exec, hyprpicker -a"
        ''SUPER_SHIFT, S, exec, grim -g "$(slurp)" - | wl-copy''
        ''
          SUPER_SHIFT, C, exec, grim -g "$(slurp)" - | tesseract stdin stdout -l rus+eng | wl-copy''
        ''
          $mod, R, exec, pkill wl-screenrec || wl-screenrec --audio --audio-device "$(pactl get-default-sink)" -f ~/Documents/screenrecord.mp4''
        "$mod, F, fullscreen"
        "$mod, J, movefocus, d"
        "$mod, K, movefocus, u"
        "$mod, H, movefocus, l"
        "$mod, L, movefocus, r"
        "$mod, Tab, changegroupactive, f"
      ] ++ workspaces;
      bindl = [ ",switch:Lid Switch, exec, /usr/bin/hyprlock" ];
      bindel = [
        "$mod SHIFT, right, resizeactive, 15% 0"
        "$mod SHIFT, left, resizeactive, -15% 0"
        "$mod SHIFT, up, resizeactive, 0 -15%"
        "$mod SHIFT, down, resizeactive, 0 15%"
        ",XF86AudioRaiseVolume, exec, wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"
        ",XF86AudioLowerVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"
        ",XF86AudioMute, exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"
        ",XF86AudioMicMute, exec, wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"
        ",XF86MonBrightnessUp, exec, brightnessctl s 10%+"
        ",XF86MonBrightnessDown, exec, brightnessctl s 10%-"
      ];
      input = {
        touchpad.natural_scroll = true;
        kb_layout = "us,ru";
        kb_options = "grp:win_space_toggle";
      };
      general = {
        gaps_in = 1;
        gaps_out = 0;
        border_size = 0;
      };
      animations.enabled = false;
      decoration = {
        rounding = 0;
        blur.enabled = false;
        shadow.enabled = false;
      };
      xwayland = { force_zero_scaling = true; };
      windowrulev2 = [
        "float,class:(clipse)"
        "size 622 652,class:(clipse)"
        "move onscreen cursor -50% -25%, class:it.catboy.ripdrag"
        "fullscreen, title:.*Ableton.*"
        "fullscreenstate 0 3, class:code"
        "workspace 1, class:kitty"
        "workspace 2, class:librewolf"
        "workspace 3, class:code"
        "workspace 4, class:ableton live 12 suite.exe"
        "group set vscode, class:code"
      ];
      group.groupbar.enabled = false;
      misc = {
        disable_autoreload = true;
        vfr = true;
      };
      "plugin:dynamic-cursors" = {
        enabled = true;
        mode = "stretch";
        stretch.limit = 5000;
        shake = {
          enabled = true;
          threshold = 5.0;
          timeout = 600;
        };
        hyprcursor.nearest = false;
      };
      # plugins = {
      #  hyprwinwrap = {
      #    class = "kitty-bg";
      #  };
      # };
    };
  };

  systemd.user = let
    KDBX_DIR = "${config.home.homeDirectory}/Documents/keepass";
    pushScript = pkgs.writeShellScript "keepassxc-git-push" ''
      set -euo pipefail
      sleep 1
      git add *.kdbx
      if ! git diff-index --quiet HEAD --; then
        git commit -a --amend --no-edit
        git push --force-with-lease
      else
        echo "Working tree clean - skipping empty amend."
      fi
    '';
  in {
    enable = true;
    systemctlPath = "/usr/bin/systemctl";
    startServices = "sd-switch";
    paths = {
      "kdbx-watch" = {
        Install.WantedBy = [ "graphical-session.target" ];
        Path = {
          PathModified = "${KDBX_DIR}";
          Unit = "keepassxc-sync.service";
        };
        Unit.Description = "Watch KeePassXC database for changes";
      };
    };
    services = {
      keepassxc-autostart = {
        Unit = {
          Description = "KeePassXC autostart";
          After = [ "graphical-session.target" ];
          PartOf = [ "graphical-session.target" ];
        };
        Service = {
          ExecStart = "${pkgs.keepassxc}/bin/keepassxc";
          Restart = "on-failure";
          RestartSec = 3;
        };
        Install.WantedBy = [ "graphical-session.target" ];
      };
      keepassxc-sync = {
        Unit = {
          Description = "Auto-commit & push KeePassXC database";
          After = [ "keepassxc-autostart.target" ];
        };
        Service = {
          Type = "oneshot";
          PassEnvironment = [ "SSH_AUTH_SOCK" "SSH_AGENT_PID" ];
          Environment = [ "GIT_SSH_COMMAND='ssh -i ~/.ssh/backup.pub'" ];
          WorkingDirectory = KDBX_DIR;
          ExecStart = "${pushScript} %f";
          RestartSec = 3; # prevents "start request repeated too quickly"
        };
      };
    };
  };

  services = {
    clipse = {
      enable = true;
      allowDuplicates = false;
      imageDisplay.type = "kitty";
    };
    home-manager.autoExpire = {
      enable = true;
      frequency = "weekly";
      timestamp = "-7 days";
      store.cleanup = true;
    };
    hyprpolkitagent.enable = true;
    podman = {
      enable = true;
      settings.storage = {
        storage.options.overlay = { ignore_chown_errors = "true"; };
      };
    };
    ssh-agent.enable = true;
    # wluma = { # depends on vulkan
    #   enable = true;
    #   systemd.enable = true;
    #   settings = {
    #     als.time.thresholds = {
    #       "0" = "night";
    #       "4" = "dark";
    #       "5" = "dim";
    #       "6" = "normal";
    #       "8" = "bright";
    #       "16" = "normal";
    #       "18" = "dark";
    #       "20" = "night";
    #     };
    #     output.backlight = [{
    #       name = "eDP-1";
    #       path = "/sys/class/backlight/intel_backlight";
    #       capturer = "wayland";
    #     }];
    #     keyboard = [{
    #       name = "keyboard-thinkpad";
    #       path =
    #         "/sys/bus/platform/devices/thinkpad_acpi/leds/tpacpi::kbd_backlight";
    #     }];
    #   };
    # };
  };

  programs = {
    home-manager.enable = true;
    claude-code.enable = true;
    ssh = {
      enable = true;
      matchBlocks = { "*".extraOptions.SetEnv = "TERM=xterm"; };
    };
    git.enable = true;
    helix.enable = true;
    zsh = {
      siteFunctions = { dr = ''ripdrag -x -a -W 360 -H 160 "$@"''; };
      shellAliases = let
        cpuMin = "4";
        cpuMax = "15";
      in {
        hmu =
          "nix flake update --flake ~/.config/home-manager && NIXPKGS_ALLOW_UNFREE=1 home-manager switch --flake ~/.config/home-manager#${username}@linux --impure";
        sd = "sudo shutdown now";
        rb = "sudo reboot now";
        cputoggle = ''
          function _cputoggle() {
            local state="off"
            for i in {${cpuMin}..${cpuMax}}; do
                if [[ $(cat /sys/devices/system/cpu/cpu$i/online) -eq 1 ]]; then
                    state="on"
                    break
                fi
            done

            if [[ "$state" == "on" ]]; then
                for i in {${cpuMin}..${cpuMax}}; do
                    echo 0 | sudo tee /sys/devices/system/cpu/cpu$i/online > /dev/null
                done
                echo "Cores ${cpuMin}-${cpuMax}: OFF"
            else
                for i in {${cpuMin}..${cpuMax}}; do
                    echo 1 | sudo tee /sys/devices/system/cpu/cpu$i/online > /dev/null
                done
                echo "Cores ${cpuMin}-${cpuMax}: ON"
            fi
          }; _cputoggle
        '';
      };
    };
    yazi = {
      enable = true;
      enableZshIntegration = true;
      settings = {
        keymap.mgr.prepend_keymap = [{
          run = ''
            shell 'ripdrag -x -a -W 360 -H 160 --no-click --target "$@" 2>/dev/null &' --confirm'';
          on = [ "<A-d>" ];
        }];
        opener = {
          img = [{
            run = ''exiv2 "$1"; echo "Press enter to exit"; read'';
            block = true;
            desc = "EXIF";
          }];
        };
      };
    };
    hyprlock = {
      # !! install from native package manager
      # otherwise it wont accept any password
      enable = true;
      settings = {
        "$font" = "Inter Display";
        "$text_color" = "rgb(255, 255, 255)";
        general = {
          hide_cursor = true;
          ignore_empty_input = true;
          immediate_render = true;
        };
        animations.enabled = false;
        background = { color = "rgb(0, 0, 0)"; };
        label = [
          {
            text =
              ''cmd[update:1000] echo "<b><big>$(date +"%H:%M")</big></b>"'';
            color = "$text_color";
            font_size = 190;
            font_family = "$font";
            position = "1%, 10%";
            halign = "left";
            valign = "bottom";
          }
          {
            text = "$LAYOUT";
            color = "$text_color";
            font_size = "16";
            font_family = "$font";
            position = "1%, -1%";
            halign = "left";
            valign = "top";
          }
        ];
        input-field = {
          size = "200, 50";
          outline_thickness = 0;
          dots_size = 0.25;
          dots_spacing = 0.3;
          dots_center = true;
          dots_rounding = -1;
          inner_color = "rgba(0, 0, 0, 0)";
          font_color = "rgba(255, 255, 255, 0.3)";
          fail_color = "rgba(255, 60, 60, 0.2)";
          fade_on_empty = false;
          fade_timeout = 200;
          placeholder_text = "";
          fail_text = "Wrong password ($ATTEMPTS)";
          hide_input = false;
          rounding = -1;
          position = "0, -200";
          halign = "center";
          valign = "center";
        };
      };
    };
    waybar = {
      enable = true;
      settings = {
        mainBar = {
          layer = "top";
          height = 16;
          modules-left = [ "hyprland/windowcount" ];
          modules-center = [ "clock" "battery" ];
          modules-right = [ "group/right" ];
          "hyprland/workspaces" = {
            "format" = "{name}";
            "on-click" = "activate";
          };
          "clock" = { "format-alt" = "{:%H:%M}"; };
          "group/right" = {
            "orientation" = "inherit";
            "modules" = [
              "hyprland/language"
              "backlight"
              "network"
              "bluetooth"
              # "wireplumber"
              "tray"
            ];
          };
          "battery" = {
            "format" = "{capacity}%";
            "format-charging" = "{capacity}%";
            "format-icons" = [ "󰁺" "󰁼" "󰁾" "󰂀" "󰁹" ];
          };
          "hyprland/language" = {
            "format" = "{}";
            "format-en" = "en";
            "format-ru" = "ru";
            position = "top";
          };
          "wireplumber" = {
            "format" = "{percent} 󰕿";
            "tooltip" = false;
            "format-muted" = "󰖁";
          };
          "wireplumber#mic" = {
            "format" = "{format_source}";
            "format-source" = "";
            "format-source-muted" = "";
            "tooltip" = false;
          };
          "backlight" = {
            "format" = "{icon}";
            "format-icons" = [ "" "" "" "" "" "" "" "" "" "" ];
          };
          "network" = {
            "format" = "{icon}";
            "format-wifi" = "󰤨";
            "format-ethernet" = "󰈁";
            "format-disconnected" = "󰖪";
            "format-linked" = "󰈁";
            "tooltip" = false;
          };
          "bluetooth" = {
            "format-on" = "";
            "format-off" = "󰂲";
            "format-disabled" = "";
            "format-connected" = "";
            "tooltip" = false;
          };
          "tray" = { "icon-size" = 12; };
        };
      };
      style = ''
        * {
          font-family: 'Symbols Nerd Font', 'Inter Display', sans-serif;
          font-size: 13px;
          border: none;
          border-radius: 0px;
          box-shadow: none;
          text-shadow: none;
        }

        window#waybar {
          border-radius: 0px;
        }

        #window {
          padding: 2px 10px;
          margin: 4px 2px 4px 4px;
          border-radius: 10px;
        }

        #workspaces {
          margin: 4px 4px;
          border-radius: 10px;
        }

        #workspaces button {
          padding: 0px 4px;
          margin: 4px 4px;
        }

        #control-center {
          padding: 0px 8px;
          margin: 8px 4px;
          border-radius: 10px;
        }

        #bluetooth,
        #network,
        #backlight,
        #tray {
          padding: 0px 0 0 5px;
        }

        #language {
          padding: 0px 3px 2px 0px;
        }
      '';
    };
    kitty = {
      enable = true;
      shellIntegration.enableZshIntegration = true;
      settings = {
        tab_bar_edge = "top";
        confirm_os_window_close = 0;
        enable_audio_bell = 0;
        tab_bar_style = "separator";
        tab_separator = " | ";
        tab_title_max_length = 23;
        input_delay = 0;
        cursor_trail = 1;
        cursor_trail_decay = "0.07 0.15";
        sync_to_monitor = false;
      };
      keybindings = let
        tabs = builtins.listToAttrs (map (i: {
          name = "alt+${toString i}";
          value = "goto_tab ${toString i}";
        }) (lib.lists.range 1 9));
      in {
        "alt+t" = "new_tab";
        "alt+q" = "close_tab";
      } // tabs;
    };
    vscode = {
      enable = true;
      profiles.default.userSettings = {
        "editor.fontLigatures" = "'calt' 0, 'HSKL' 1";
        "telemetry.telemetryLevel" = "off";
        "update.mode" = "manual";
        "window.titleBarStyle" = "custom";
        "window.dialogStyle" = "custom";
        "window.menuBarVisibility" = "compact";
        "window.restoreFullscreen" = true;
        "window.newWindowDimensions" = "maximized";
        "window.customTitleBarVisibility" = "windowed";
        "workbench.layoutControl.enabled" = false;
        "workbench.colorTheme" = lib.mkForce "Omni";
        "terminal.integrated.fontSize" = lib.mkForce 15;

        "containers.containerClient" =
          "com.microsoft.visualstudio.containers.podman";
        "dev.containers.dockerPath" = "podman";
        "files.trimFinalNewlines" = true;
        "files.insertFinalNewline" = true;
        "terminal.integrated.env.linux" = { GIT_EDITOR = "code\\ --wait"; };
        "terminal.integrated.commandsToSkipShell" =
          [ "workbench.action.toggleSidebarVisibility" ];
      };
    };
    mpv = {
      enable = true;
      scripts = [ pkgs.mpvScripts.webtorrent-mpv-hook ];
      config = {
        alang = [ "en" ];
        slang = [ "en" ];
        embeddedfonts = "no";
        sub = "yes";
        sub-delay = 1;
        sub-font = lib.mkForce "Inter Display";
        sub-font-size = 20;
        sub-color = "#66FFFFFF";
        sub-back-color = "#66000000";
        sub-border-style = "background-box";
        sub-border-size = 0;
        sub-pos = 5;
        sub-ass-override = "strip";
      };
    };
    keepassxc = {
      enable = true;
      autostart = true;
      settings = {
        Browser = {
          Enabled = true;
          UpdateBinaryPath = false;
        };
        FdoSecrets.Enabled = true;
        GUI = {
          AdvancedSettings = true;
          ApplicationTheme = "dark";
          CheckForUpdates = false;
          HidePasswords = true;
          ShowTrayIcon = true;
          TrayIconAppearance = "monochrome-light";
          MinimizeOnClose = true;
          MinimizeOnStartup = true;
        };
        PasswordGenerator = {
          AdvancedMode = true;
          Length = 24;
          Logograms = true;
          Punctuation = true;
          Quotes = true;
        };
        Security.LockDatabaseScreenLock = false;
        SSHAgent = {
          Enabled = true;
          AuthSockOverride = "/run/user/1000/ssh-agent";
        };
      };
    };
    rtorrent = { enable = true; };
  };

  stylix = {
    enable = true;
    image = pkgs.fetchurl {
      url =
        "https://upload.wikimedia.org/wikipedia/commons/b/b8/A_right_front_view_of_an_SR-71B_Blackbird_strategic_reconnaissance_training_aircraft%2C_silhouetted_on_the_runway_at_sundown_DF-ST-89-06278.jpg";
      hash = "sha256-p52wW/aW7n/udv6XIWVHEtAVbjUIMGQflPEUFwL9na0=";
    };
    base16Scheme = "${pkgs.base16-schemes}/share/themes/da-one-ocean.yaml";
    cursor = {
      name = "Bibata-Modern-Ice";
      package = pkgs.bibata-cursors;
      size = 16;
    };
    iconTheme = {
      enable = false;
      package = pkgs.papirus-icon-theme;
      dark = "Papirus-Dark";
      light = "Papirus-Light";
    };
    fonts = {
      serif = config.stylix.fonts.sansSerif;
      sansSerif = {
        package = pkgs.noto-fonts-cjk-sans;
        name = "Noto Sans";
      };
      emoji = {
        package = pkgs.noto-fonts-color-emoji;
        name = "Noto Color Emoji";
      };
      monospace = {
        package =
          (pkgs.iosevka-bin.override { variant = "SGr-IosevkaTermSS10"; });
        name = "Iosevka Term SS10";
      };
    };
    polarity = "dark";
    targets.helix.enable = false;
    targets.hyprlock.enable = false;
  };
}
