{
  inputs,
  username,
  homeDirectory,
  config,
  lib,
  pkgs,
  ...
}:

{
  imports = [ ../dev/home.nix ];
  targets.genericLinux.enable = true;

  home.username = username;
  home.homeDirectory = homeDirectory;
  home.sessionVariables = {
    SUDO_EDITOR = "$HOME/.nix-profile/bin/hx";
  };

  nixpkgs.config = {
    allowUnfree = true;
    allowUnfreePredicate = (pkg: true);
    users.defaultUserShell = pkgs.zsh;
  };
  nixpkgs.overlays = [
    (final: prev: {
      consoleet-oldschoolpc = prev.stdenvNoCC.mkDerivation {
        pname = "consoleet-oldschoolpc";
        version = "2.2.1";
        src = prev.fetchurl {
          url = "https://inai.de/files/consoleet/consoleet-oldschoolpc-2.2.1.tar.zst";
          hash = "sha256-kYRmOnDnKpP09ipw7TMbxtsz56SZI7NIczDTpGF5/04=";
        };
        nativeBuildInputs = [ prev.zstd ];
        installPhase = ''
          runHook preInstall
          mkdir -p $out/share/fonts/opentype
          cp *.otf $out/share/fonts/opentype/
          runHook postInstall
        '';
      };
    })
  ];
  xdg =
    let
      browserTypes = [
        "text/html"
        "text/xml"
        "application/xhtml+xml"
        "application/pdf"
        "image/svg+xml"
        "image/webp"
        "x-scheme-handler/http"
        "x-scheme-handler/https"
        "x-scheme-handler/about"
        "x-scheme-handler/unknown"
      ];
      makeDefaults = app: types: lib.genAttrs types (_: "${app}.desktop");
    in
    {
      enable = true;
      autostart.enable = true;
      mime.enable = true;
      portal = {
        enable = true;
        extraPortals = [ pkgs.xdg-desktop-portal-hyprland ];
        configPackages = [ pkgs.hyprland ];
      };
      desktopEntries.librewolf = {
        name = "librewolf";
        exec = "/usr/bin/librewolf %u";
        categories = [
          "Network"
          "WebBrowser"
        ];
        mimeType = browserTypes;
      };
      mimeApps = {
        enable = true;
        defaultApplicationPackages = [ pkgs.mpv ];
        defaultApplications = makeDefaults "librewolf" browserTypes;
      };
    };
  fonts.fontconfig.enable = true;
  home.stateVersion = "25.05"; # Please read the comment before changing.
  gtk.gtk4.theme = null;

  home.file.".local/bin/zsh-cycle-jobs" = {
    executable = true;
    text = ''
      #!/bin/sh
      pid=$(cat /tmp/zsh_cycle_pid 2>/dev/null) || exit 0
      echo $$ >| /tmp/zsh_cycle_token
      tpgid=$(ps -o tpgid= -p "$pid" 2>/dev/null | tr -d ' ')
      pgid=$(ps -o pgid= -p "$pid" 2>/dev/null | tr -d ' ')
      [ -n "$tpgid" ] && [ "$tpgid" != "$pgid" ] && kill -TSTP -"$tpgid" 2>/dev/null
      sleep 0.05
      kill -USR1 "$pid" 2>/dev/null
    '';
  };

  home.packages = with pkgs; [
    brightnessctl
    grim
    hyprpicker
    ripdrag
    slurp
    wl-screenrec
    wl-clipboard
    tor-browser
    qbittorrent-enhanced

    android-tools
    binsider
    bluetui
    exiv2
    fastfetch
    go-chromecast
    htop
    libarchive
    mediainfo
    netcat
    tesseract

    consoleet-oldschoolpc
    inter
    nerd-fonts.symbols-only
    nerd-fonts.bigblue-terminal
  ];

  wayland.windowManager.hyprland =
    let
      workspaces = builtins.concatLists (
        map (
          ws:
          let
            wsStr = toString ws;
          in
          [
            "$mod, ${wsStr}, workspace, ${wsStr}"
            "$mod SHIFT, ${wsStr}, movetoworkspace, ${wsStr}"
          ]
        ) (lib.lists.range 1 9)
      );
    in
    {
      enable = true;
      configType = "hyprlang";
      package = pkgs.hyprland;
      systemd.enableXdgAutostart = true;
      systemd.variables = [ "--all" ];
      plugins = [
        #pkgs.hyprlandPlugins.hyprwinwrap
        pkgs.hyprlandPlugins.hypr-dynamic-cursors
      ];
      settings = {
        env = [
          "ELECTRON_OZONE_PLATFORM_HINT,wayland"
          "QT_QPA_PLATFORM,wayland"
        ];
        exec-once = [
          "dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP"
          "waybar"
          "hyprctl setcursor Bibata-Modern-Ice 16"
        ];
        "$mod" = "SUPER";
        bind = [
          "$mod, Escape, exec, /usr/bin/hyprlock"
          "$mod, Q, killactive"
          "$mod, S, exec, kitty"
          "$mod, B, exec, librewolf"
          "$mod, V, exec, kitty --class clipse -e 'clipse'"
          "$mod, P, exec, keepassxc"
          "SUPER_SHIFT, O, exit"
          "SUPER_SHIFT, P, exec, hyprpicker -a"
          ''SUPER_SHIFT, S, exec, grim -g "$(slurp)" - | wl-copy''
          ''SUPER_SHIFT, C, exec, grim -g "$(slurp)" - | tesseract stdin stdout -l rus+eng | wl-copy''
          ''$mod, R, exec, pkill wl-screenrec || wl-screenrec --audio --audio-device "$(pactl get-default-sink)" -f ~/Documents/screenrecord.mp4''
          "$mod, F, fullscreen"
          "$mod, J, movefocus, d"
          "$mod, K, movefocus, u"
          "$mod, H, movefocus, l"
          "$mod, L, movefocus, r"
          "$mod, Tab, changegroupactive, f"
          "$mod CTRL, H, movewindow, l"
          "$mod CTRL, J, movewindow, d"
          "$mod CTRL, K, movewindow, u"
          "$mod CTRL, L, movewindow, r"
        ]
        ++ workspaces;
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
        xwayland = {
          force_zero_scaling = true;
        };
        windowrule = [
          "match:class clipse, float on"
          "match:class clipse, size 622 652"
          "match:class it.catboy.ripdrag, move onscreen cursor -50% -25%"
          "match:title .*Ableton.*, fullscreen on"
          "match:class code, fullscreen_state 0 3"
          "match:class kitty, workspace 1"
          "match:class librewolf, workspace 2"
          "match:class mpv, workspace 3"
          "match:class mpv, fullscreen on"
          "match:class code, workspace 4"
          "match:class ableton live 12 suite.exe, workspace 5"
          "match:class code, group set vscode"
          "match:class org.keepassxc.KeePassXC, match:title (KeePassXC -.*Access Request|Generate Password), float on"
          "match:class org.keepassxc.KeePassXC, match:title (KeePassXC -.*Access Request|Generate Password), center on"
          "match:class org.keepassxc.KeePassXC, match:title KeePassXC -.*Access Request, pin on"
          "match:class org.keepassxc.KeePassXC, match:title KeePassXC -.*Access Request, stay_focused on"
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

  systemd.user =
    let
      KDBX_DIR = "${config.home.homeDirectory}/Documents/keepass";
      pushScript = pkgs.writeShellScript "keepassxc-git-push" ''
        set -euo pipefail
        sleep 1
        git add linux.kdbx
        if ! git diff-index --quiet HEAD --; then
          git commit --amend --no-edit
          git push --force-with-lease
        else
          echo "Working tree clean - skipping empty amend."
        fi
      '';
    in
    {
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
            PassEnvironment = [
              "SSH_AUTH_SOCK"
              "SSH_AGENT_PID"
            ];
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
    helix.settings.theme = "nyxvamp-obsidian";
    ssh = {
      enable = true;
      settings = {
        "*".SetEnv = { TERM = "xterm"; };
      };
    };
    zsh = {
      initContent = ''
        if [[ -n $KITTY_WINDOW_ID ]]; then
          _write_cycle_pid() { echo $$ >| /tmp/zsh_cycle_pid }
          add-zsh-hook precmd _write_cycle_pid
          _write_cycle_pid

          _CYCLE_TOKEN=
          _CYCLE_CURRENT=

          TRAPUSR1() {
            local token=$(</tmp/zsh_cycle_token)
            [[ $token == $_CYCLE_TOKEN ]] && return
            _CYCLE_TOKEN=$token
            _CYCLE_REQUESTED=1
            zle && zle .send-break
          }

          _check_cycle_flag() {
            (( _CYCLE_REQUESTED )) || return
            _CYCLE_REQUESTED=0
            local -a jlist
            jlist=(''${(kon)jobstates})
            (( ''${#jlist} == 0 )) && return
            local next current=''${_CYCLE_CURRENT:-} found=0
            if (( ''${#jlist} == 1 )); then
              next=''${jlist[1]}
            else
              if [[ -z $current ]] || ! (( ''${+jobstates[$current]} )); then
                for j in $jlist; do
                  [[ ''${jobstates[$j]} == *:+:* ]] && { current=$j; break }
                done
              fi
              [[ -z $current ]] && return
              for j in $jlist; do
                (( found )) && { next=$j; break }
                [[ $j == $current ]] && found=1
              done
              [[ -z $next ]] && next=''${jlist[1]}
            fi
            _CYCLE_CURRENT=$next
            zle -I
            fg %$next
          }
          autoload -Uz add-zle-hook-widget
          add-zle-hook-widget line-init _check_cycle_flag
        fi
      '';
      siteFunctions = {
        dr = ''ripdrag -x -a -W 360 -H 160 "$@"'';
      };
      shellAliases =
        let
          cpuMin = "4";
          cpuMax = "15";
        in
        {
          hmu = "nix flake update --flake ~/.config/home-manager && NIXPKGS_ALLOW_UNFREE=1 home-manager switch --flake \"$HOME/.config/home-manager#${username}@linux\" --impure";
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
      settings = {
        keymap.mgr.prepend_keymap = [
          {
            run = ''shell 'ripdrag -x -a -W 360 -H 160 --no-click --target "$@" 2>/dev/null &' --confirm'';
            on = [ "<A-d>" ];
          }
        ];
        opener = {
          img = [
            {
              run = ''exiv2 "$1"; echo "Press enter to exit"; read'';
              block = true;
              desc = "EXIF";
            }
          ];
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
        background = {
          color = "rgb(0, 0, 0)";
        };
        label = [
          {
            text = ''cmd[update:1000] echo "<b><big>$(date +"%H:%M")</big></b>"'';
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
          modules-center = [
            "clock"
            "battery"
          ];
          modules-right = [ "group/right" ];
          "hyprland/workspaces" = {
            "format" = "{name}";
            "on-click" = "activate";
          };
          "clock" = {
            "format-alt" = "{:%H:%M}";
          };
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
            "format-icons" = [
              "󰁺"
              "󰁼"
              "󰁾"
              "󰂀"
              "󰁹"
            ];
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
            "format-icons" = [
              ""
              ""
              ""
              ""
              ""
              ""
              ""
              ""
              ""
              ""
            ];
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
          "tray" = {
            "icon-size" = 12;
            "spacing" = 5;
          };
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
      package = pkgs.kitty.overrideAttrs (old: {
        NIX_CFLAGS_COMPILE = (old.NIX_CFLAGS_COMPILE or "") + " -march=native -mtune=native";
      });
      shellIntegration.enableZshIntegration = true;
      settings = {
        font_family = lib.mkForce "Consoleet EGA 8x14 Smooth";
        font_size = lib.mkForce 14;
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
              name = "alt+${toString i}";
              value = "goto_tab ${toString i}";
            }) (lib.lists.range 1 9)
          );
        in
        {
          "alt+t" = "new_tab";
          "alt+q" = "close_tab";
          "alt+grave" = "launch --type=background ${homeDirectory}/.local/bin/zsh-cycle-jobs";
        }
        // tabs;
    };
    vscode = {
      enable = false;
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
        "containers.containerClient" = "com.microsoft.visualstudio.containers.podman";
        "dev.containers.dockerPath" = "podman";
        "files.trimFinalNewlines" = true;
        "files.insertFinalNewline" = true;
        "terminal.integrated.env.linux" = {
          GIT_EDITOR = "code\\ --wait";
        };
        "terminal.integrated.commandsToSkipShell" = [ "workbench.action.toggleSidebarVisibility" ];
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
        sub-delay = 1.9;
        sub-font = lib.mkForce "Inter Display";
        sub-font-size = 20;
        sub-color = "#66FFFFFF";
        sub-back-color = "#66000000";
        # sub-font-size = 30;
        # sub-color = "#FFFFFFFF";
        # sub-back-color = "#FF000000";
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
        Security = {
          LockDatabaseScreenLock = false;
          LockDatabaseIdle = false;
        };
        SSHAgent = {
          Enabled = true;
          AuthSockOverride = "/run/user/1000/ssh-agent";
        };
      };
    };
  };

  stylix = {
    enable = true;
    targets.kde.enable = false;
    image = pkgs.fetchurl {
      url = "https://images.unsplash.com/photo-1765707886539-6d57024ddc2f";
      hash = "sha256-5B+znuF1860cuLMn5eyob7ZGaSmlgTNATgb3A6xD87U=";
    };
    base16Scheme = "${pkgs.base16-schemes}/share/themes/da-one-ocean.yaml";
    cursor = {
      name = "Bibata-Modern-Ice";
      package = pkgs.bibata-cursors;
      size = 16;
    };
    icons = {
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
        package = (pkgs.iosevka-bin.override { variant = "SGr-IosevkaTermSS10"; });
        name = "Iosevka Term SS10";
      };
    };
    polarity = "dark";
    targets.helix.enable = false;
    targets.hyprlock.enable = false;
  };
}
