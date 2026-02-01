{
  inputs,
  username,
  homeDirectory,
  config,
  lib,
  pkgs,
  ...
}:

let
  personalFile = "${homeDirectory}/.config/personal.nix";
  gitHooksPath = "~/.config/git/hooks";
  gitHooksWrapper = pkgs.writeShellScript "git-hooks-wrapper" ''
    GIT="$1"; shift
    case "$1" in
      commit|merge|push|pull|checkout|switch|rebase|am|cherry-pick|revert)
        export GIT_CONFIG_PARAMETERS="'core.hooksPath=${gitHooksPath}'"
        ;;
    esac
    exec "$GIT" "$@"
  '';
  isTermux =
    pkgs.stdenv.hostPlatform.isAarch64
    && !config.systemd.user.enable
    && !config.targets.genericLinux.gpu.enable;
in
{
  imports = lib.optional (builtins.pathExists personalFile) personalFile;
  nix = {
    package = pkgs.nix;
    settings.experimental-features = [
      "nix-command"
      "flakes"
    ];
  };

  home = {
    preferXdgDirectories = true;
    sessionVariables = {
      CARGO_HOME = "$HOME/.cache/cargo";
      GRADLE_USER_HOME = "$HOME/.cache";
      BUILDAH_FORMAT = "docker";
      DOCKER_CONFIG = "$HOME/.config/docker";
    };
    shellAliases = {
      jq = "jaq";
    };
  };

  home.packages =
    with pkgs;
    [
      age
      devenv
      fzf
      jaq
      ripgrep
      tlrc
      tree
      witr
    ]
    ++ lib.optionals (!isTermux) [ podman-compose ];

  services.podman = lib.mkIf (!isTermux) {
    enable = true;
    settings.storage = {
      storage.options.overlay = {
        ignore_chown_errors = "true";
      };
    };
  };


  programs = {
    home-manager.enable = true;
    claude-code = {
      enable = true;
      package = pkgs.claude-code.overrideAttrs (old: rec {
        version = "2.0.64";
        src = pkgs.fetchurl {
          url = "https://registry.npmjs.org/@anthropic-ai/claude-code/-/claude-code-${version}.tgz";
          hash = "sha256-H75i1x580KdlVjKH9V6a2FvPqoREK004CQAlB3t6rZ0=";
        };
        packageLock = pkgs.fetchurl {
          url = "https://raw.githubusercontent.com/NixOS/nixpkgs/d81147f1f1f508c6a62b7182b991aa1500e48cbe/pkgs/by-name/cl/claude-code/package-lock.json";
          hash = "sha256-u3zwMA/I/Np/DD2JDZyoKqByx+gP6c3EZvc+v+c42xA=";
        };
        npmDepsHash = "sha256-x1YerDQP1+kNS+mdIqSAE1e81fsd855KdJM+VBxaUBQ=";
        npmDeps = pkgs.fetchNpmDeps {
          inherit src;
          name = "${old.pname}-${version}-npm-deps";
          hash = npmDepsHash;
          postPatch = ''
            cp ${packageLock} package-lock.json
          '';
        };
        postPatch = ''
          cp ${packageLock} package-lock.json
          substituteInPlace cli.js \
            --replace-warn '#!/bin/bash' '#!/usr/bin/env bash'
        '';
      });
    };
    delta = {
      enable = true;
      enableGitIntegration = true;
    };
    git = {
      enable = true;
      package = pkgs.symlinkJoin {
        name = "git-with-hooks";
        paths = [ pkgs.git ];
        postBuild = ''
          rm $out/bin/git
          ln -s ${pkgs.writeShellScript "git-wrapper" ''
            exec ${gitHooksWrapper} ${pkgs.git}/bin/git "$@"
          ''} $out/bin/git
        '';
      };
      ignores = [
        "*.env"
        "/env/"
        ".devenv*"
        ".direnv/"
        ".devcontainer/"
        ".pre-commit-config.yaml"
      ];
      lfs.enable = true;
      settings = {
        user.email = lib.mkDefault "johndoe@example.com";
        user.name = lib.mkDefault "John Doe";
        column.ui = "auto";
        branch.sort = "-committerdate";
        tag.sort = "version:refname";
        init.defaultBranch = "main";
        diff = {
          algorithm = "histogram";
          mnemonicPrefix = true;
          renames = true;
        };
        push = {
          default = "simple";
          autoSetupRemote = true;
          followTags = true;
        };
        fetch = {
          prune = true;
          pruneTags = true;
          all = true;
        };
        help.autocorrect = "prompt";
        commit.verbose = true;
        rerere = {
          enabled = true;
          autoupdate = true;
        };
        rebase = {
          autoSquash = true;
          autoStash = true;
          updateRefs = true;
        };
      };
      includes = [ ];
    };
    gitui.enable = true;
    ssh = {
      enable = true;
      enableDefaultConfig = false;
      matchBlocks = {
        "*" = {
          addKeysToAgent = "yes";
          identitiesOnly = true;
          hashKnownHosts = true;
          extraOptions = {
            PreferredAuthentications = "publickey";
            StrictHostKeyChecking = "accept-new";
          };
        };
      };
    };
    helix = {
      enable = true;
      defaultEditor = true;
      settings = {
        editor = {
          auto-format = true;
          bufferline = "multiple";
          cursor-shape = {
            insert = "bar";
            normal = "block";
            select = "underline";
          };
          trim-trailing-whitespace = true;
          trim-final-newlines = true;
        };
        keys.normal = {
          "C-s" = ":w";
          "A-e" = "insert_mode";
          "A-tab" = ":buffer-next";
        };
        keys.insert = {
          "C-s" = ":w";
          "A-e" = "normal_mode";
          "A-tab" = ":buffer-next";
        };
        keys.select = {
          "A-tab" = ":buffer-next";
        };
      };
      languages = {
        language = [
          {
            name = "nix";
            auto-format = true;
            formatter.command = "${pkgs.nixfmt}/bin/nixfmt";
          }
          {
            name = "json";
            formatter.command = "${pkgs.jaq}/bin/jaq";
          }
        ];
      };
    };
    direnv = {
      enable = true;
      enableZshIntegration = true;
      nix-direnv.enable = true;
    };
    yazi = {
      enable = true;
      enableZshIntegration = true;
      settings = {
        mgr = {
          show_hidden = true;
        };
      };
      initLua = ''
        Status:children_add(function()
        	local h = cx.active.current.hovered
        	if not h or ya.target_family() ~= "unix" then
        		return ""
        	end

        	return ui.Line {
        		ui.Span(ya.user_name(h.cha.uid) or tostring(h.cha.uid)):fg("magenta"),
        		":",
        		ui.Span(ya.group_name(h.cha.gid) or tostring(h.cha.gid)):fg("magenta"),
        		" ",
        	}
        end, 500, Status.RIGHT)
      '';
    };
    zsh = {
      enable = true;
      enableCompletion = true;
      autosuggestion.enable = true;
      dotDir = "${config.xdg.configHome}/zsh";
      envExtra = ''
        # global git hooks
        fpath+=($HOME/.nix-profile/share/zsh/site-functions)
        autoload -Uz git
      '';
      localVariables = {
        ZSH_COMPDUMP = "$HOME/.cache/.zcompdump-$HOST";
      };
      history = {
        share = false;
        append = true;
        saveNoDups = true;
        ignoreAllDups = true;
        ignoreSpace = true;
        extended = true;
      };
      initContent =
        let
          zshConfig = lib.mkOrder 1500 ''eval "$(fzf --zsh| sed -e '/zmodload/s/perl/perl_off/' -e '/selected/s/fc -rl/fc -rlt "%y-%m-%d"/')"'';
        in
        lib.mkMerge [ zshConfig ];
      siteFunctions = {
        gclone = ''gitstrip="''${1#*:}"; gitpath="''${gitstrip%.git}"; git clone "$1" "''${gitpath%.git}"'';
        mkcd = ''mkdir --parents "$1" && cd "$1"'';
        tch = ''mkdir --parents "$(dirname "$@")" && touch "$@"'';
        git = ''${gitHooksWrapper} "$(whence -p git)" "$@"'';
      };
      prezto = {
        enable = false;
        caseSensitive = false;
        editor.keymap = "vi";
      };
      oh-my-zsh = {
        enable = true;
        plugins = [
          "git"
          "fzf"
        ];
        theme = "kardan";
      };
    };
    zellij = {
      enable = true;
      enableZshIntegration = false;
    };
  };

  manual = {
    html.enable = true;
    json.enable = true;
  };
}
