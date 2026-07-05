{
  inputs,
  username,
  lib,
  pkgs,
  ...
}:
with pkgs;
let
  appFullscreen =
    appName:
    writeShellScript "fullscreen-${appName}" ''
      open -a "${appName}"
      for _ in $(seq 1 20); do
        if /usr/bin/osascript -e 'tell application "System Events" to tell process "${appName}" to set value of attribute "AXFullScreen" of window 1 to true' 2>/dev/null; then
          exit 0
        fi
        sleep 0.2
      done
    '';

  toMpvConf =
    attrs:
    lib.concatStringsSep "\n" (
      lib.mapAttrsToList (
        k: v:
        let
          val =
            if lib.isList v then
              lib.concatStringsSep "," (map toString v)
            else if lib.isBool v then
              (if v then "yes" else "no")
            else if lib.isString v then
              ''"${v}"''
            else
              toString v;
        in
        "${k}=${val}"
      ) attrs
    );
in
{
  nixpkgs = {
    hostPlatform = "aarch64-darwin";
    config.allowUnfree = true;
  };

  nix = {
    settings.experimental-features = "nix-command flakes";
    gc = {
      automatic = true;
      interval = [
        {
          Weekday = 7;
          Hour = 3;
          Minute = 15;
        }
      ];
      options = "--delete-older-than 7d";
    };
    optimise = {
      automatic = true;
      interval = [
        {
          Weekday = 7;
          Hour = 4;
          Minute = 15;
        }
      ];
    };
  };

  networking = {
    hostName = "mac";
    computerName = "mac";
  };

  users.users.${username} = {
    name = username;
    home = "/Users/${username}";
  };

  environment.systemPackages = [
    htop
    sing-box
    lima
    (runCommand "gnu-coreutils-bins" { } ''
      mkdir -p $out/bin
      for b in timeout nproc sha1sum sha224sum sha256sum sha384sum sha512sum md5sum; do
        ln -s ${coreutils}/bin/$b $out/bin/$b
      done
    '')
  ];

  launchd.daemons.sing-box = {
    script = ''
      exec ${sing-box}/bin/sing-box run -c /etc/sing-box/config.json
    '';
    serviceConfig = {
      UserName = "root";
      GroupName = "wheel";
      KeepAlive = true;
      RunAtLoad = true;
      ProcessType = "Interactive";
      StandardOutPath = "/var/log/sing-box.log";
      StandardErrorPath = "/var/log/sing-box.error.log";
    };
  };

  nix-homebrew = {
    enable = true;
    user = username;
    autoMigrate = true;
    enableRosetta = false;
  };

  homebrew = {
    enable = true;
    enableZshIntegration = true;
    onActivation = {
      autoUpdate = true;
      upgrade = true;
      cleanup = "none";
    };
    casks = [
      "keepassxc"
      "librewolf"
    ];
  };

  services.skhd = {
    enable = true;
    skhdConfig = ''
      rcmd - b : ${appFullscreen "LibreWolf"}
      rcmd - l : ${appFullscreen "kitty"}
    '';
  };

  security.pam.services.sudo_local.touchIdAuth = true;

  system = {
    stateVersion = 6;
    primaryUser = username;
    defaults = {
      NSGlobalDomain = {
        AppleInterfaceStyle = "Dark";
        AppleShowAllExtensions = true;
        NSWindowResizeTime = 0.001;
        KeyRepeat = 2;
        InitialKeyRepeat = 15;
        ApplePressAndHoldEnabled = false;
        NSAutomaticDashSubstitutionEnabled = false;
        NSAutomaticQuoteSubstitutionEnabled = false;
      };
      universalaccess = {
        reduceTransparency = true;
        reduceMotion = true;
      };
      finder = {
        AppleShowAllFiles = true;
        AppleShowAllExtensions = true;
        ShowPathbar = true;
        ShowStatusBar = true;
        _FXShowPosixPathInTitle = true;
        FXPreferredViewStyle = "Nlsv";
        FXDefaultSearchScope = "SCcf";
        FXEnableExtensionChangeWarning = false;
        QuitMenuItem = true;
        FXRemoveOldTrashItems = true;
      };
      trackpad = {
        Clicking = false;
        TrackpadThreeFingerDrag = false;
      };
      screencapture = {
        target = "clipboard";
        type = "png";
        disable-shadow = true;
      };
      loginwindow = {
        GuestEnabled = false;
      };
      CustomUserPreferences = {
        "com.apple.finder" = {
          ShowSidebar = true;
        };
        "com.apple.desktopservices" = {
          DSDontWriteNetworkStores = true;
          DSDontWriteUSBStores = true;
        };
        # Kept here (not under system.defaults.dock) so nix-darwin does NOT `killall Dock`
        # on every switch — that restart blanks the wallpaper for ~1s. These apply at next
        # login; run `killall Dock` manually if you change one and want it immediately.
        "com.apple.dock" = {
          mru-spaces = false;
          launchanim = false;
          mineffect = "scale";
        };
        "com.apple.AppleMultitouchTrackpad" = {
          TrackpadThreeFingerVertSwipeGesture = 2;
          TrackpadThreeFingerHorizSwipeGesture = 2;
        };
        "com.apple.driver.AppleBluetoothMultitouch.trackpad" = {
          TrackpadThreeFingerVertSwipeGesture = 2;
          TrackpadThreeFingerHorizSwipeGesture = 2;
        };
      };
    };
  };

  home-manager = {
    useUserPackages = true;
    extraSpecialArgs = {
      inherit inputs username;
      homeDirectory = "/Users/${username}";
    };
    users.${username} =
      {
        pkgs,
        inputs,
        config,
        mpvSettings,
        ...
      }:
      let
        kdbxDir = "${config.home.homeDirectory}/Documents/keepass";
        keepassxcSync = pkgs.writeShellScript "keepassxc-git-push" ''
          set -euo pipefail
          export PATH=${pkgs.git}/bin:${pkgs.openssh}/bin:$PATH
          sleep 1
          cd ${kdbxDir}
          git add mac.kdbx
          if ! git diff-index --quiet HEAD --; then
            git commit --amend --no-edit
            git push --force-with-lease
          else
            echo "Working tree clean - skipping empty amend."
          fi
        '';
      in
      {
        imports = [
          inputs.stylix.homeModules.stylix
          inputs.nix-index-database.homeModules.nix-index
          ../dev/home.nix
          ../dev/gui.nix
        ];

        home.stateVersion = "26.11";
        nixpkgs.config.allowUnfree = true;

        home.sessionVariables.SUDO_EDITOR = "$HOME/.nix-profile/bin/hx";
        home.shellAliases.hmu = "nix flake update --flake ~/.config/home-manager && sudo darwin-rebuild switch --impure --flake \"$HOME/.config/home-manager#mac\"";
        home.file.".hushlogin".text = "";
        home.packages = with pkgs; [
          # apple/container: Nix profiles don't link /libexec, so pin
          # CONTAINER_INSTALL_ROOT to $out or the apiserver can't find its plugins.
          (container.overrideAttrs (old: {
            nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ makeWrapper ];
            postFixup = (old.postFixup or "") + ''
              for b in container container-apiserver; do
                wrapProgram "$out/bin/$b" --set CONTAINER_INSTALL_ROOT "$out"
              done
            '';
          }))
          htop
          iina
          qbittorrent-enhanced
          rapidraw
          xz
        ];

        xdg.configFile."mpv/mpv.conf".text = toMpvConf (mpvSettings // { sub-font-size = 20; }) + "\n";

        targets.darwin.defaults."com.colliderli.iina" = {
          enableAdvancedSettings = true;
          useUserDefinedConfDir = true;
          userDefinedConfDir = "${config.xdg.configHome}/mpv/";
        };

        programs = {
          helix.settings.theme = lib.mkForce "nyxvamp-obsidian";
          kitty.settings = {
            startup_session = toString (
              pkgs.writeText "kitty-fullscreen.session" "os_window_state fullscreen\n"
            );
            macos_option_as_alt = "yes";
          };
        };

        launchd.agents.keepassxc-sync = {
          enable = true;
          config = {
            ProgramArguments = [ "${keepassxcSync}" ];
            WatchPaths = [ kdbxDir ];
            WorkingDirectory = kdbxDir;
            EnvironmentVariables.GIT_SSH_COMMAND = "ssh -i ${config.home.homeDirectory}/.ssh/backup.pub";
            StandardOutPath = "/tmp/keepassxc-sync.log";
            StandardErrorPath = "/tmp/keepassxc-sync.log";
          };
        };

        stylix = {
          enable = true;
          autoEnable = false;
          base16Scheme = "${pkgs.base16-schemes}/share/themes/da-one-ocean.yaml";
          polarity = "dark";
          targets = {
            kitty.enable = true;
            yazi.enable = true;
            fzf.enable = true;
            gitui.enable = true;
            zellij.enable = true;
          };
        };
      };
  };
}
