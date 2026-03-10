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
  claudeStatusLine = pkgs.writeShellScript "claude-statusline" ''
    # Format: dirname | Model | branch | ██░░░░░░░░ 18% of 200k tokens
    IFS= read -r -d "" json_input || true

    current_dir=""
    if [[ "$json_input" =~ \"workspace\"[^}]*\"current_dir\"[[:space:]]*:[[:space:]]*\"([^\"]+)\" ]]; then
      current_dir="''${BASH_REMATCH[1]}"
    fi
    if [[ -z "$current_dir" && "$json_input" =~ \"cwd\"[[:space:]]*:[[:space:]]*\"([^\"]+)\" ]]; then
      current_dir="''${BASH_REMATCH[1]}"
    fi
    [[ -z "$current_dir" ]] && current_dir="$PWD"

    if [[ "$current_dir" == "$HOME" || "$current_dir" == ~* && "''${current_dir#\~}" == "" ]]; then
      dir_name="~"
    else
      dir_name="''${current_dir##*/}"
      [[ -z "$dir_name" ]] && dir_name="/"
    fi

    model_name=""
    if [[ "$json_input" =~ \"model\"[^}]*\"display_name\"[[:space:]]*:[[:space:]]*\"([^\"]+)\" ]]; then
      model_name="''${BASH_REMATCH[1]}"
    fi
    [[ -z "$model_name" ]] && model_name="Claude"

    context_size=0
    context_used=0
    if command -v jq &>/dev/null; then
      context_size=$(echo "$json_input" | jq -r '.context_window.context_window_size // 0' 2>/dev/null)
      context_used=$(echo "$json_input" | jq -r '
        ((.context_window.current_usage.input_tokens // 0)
        + (.context_window.current_usage.cache_creation_input_tokens // 0)
        + (.context_window.current_usage.cache_read_input_tokens // 0))
      ' 2>/dev/null)
      [[ "$context_size" == "null" ]] && context_size=0
      [[ "$context_used" == "null" ]] && context_used=0
    fi

    get_git_branch() {
      local dir="$1"
      [[ "$dir" =~ ^~ ]] && dir="''${dir/#\~/$HOME}"
      local check="$dir"
      while [[ "$check" != "/" ]]; do
        if [[ -f "$check/.git/HEAD" && -r "$check/.git/HEAD" ]]; then
          local hc
          hc=$(<"$check/.git/HEAD")
          if [[ "$hc" =~ ^ref:[[:space:]]*refs/heads/(.+)$ ]]; then
            echo "''${BASH_REMATCH[1]}"
            return 0
          fi
          echo "HEAD"
          return 0
        fi
        check="''${check%/*}"
        [[ -z "$check" ]] && check="/"
      done
    }
    git_branch=$(get_git_branch "$current_dir")

    build_bar() {
      local used=$1 max=$2
      [[ "$max" -eq 0 ]] && return
      local buffer=$(( max * 33 / 1000 ))
      local usable=$(( max - buffer ))
      [[ "$usable" -le 0 ]] && usable=1
      local pct=$(( (used * 100 + usable / 2) / usable ))
      [[ "$pct" -gt 100 ]] && pct=100
      local bar_len=10
      local filled=$(( (pct * bar_len + 50) / 100 ))
      local empty=$(( bar_len - filled ))
      local bar=""
      for ((i=0; i<filled; i++)); do bar+="█"; done
      for ((i=0; i<empty; i++)); do bar+="░"; done
      local max_display
      if [[ "$max" -ge 1000 ]]; then max_display="$(( max / 1000 ))k"; else max_display="$max"; fi
      echo "$bar ''${pct}% of ''${max_display} tokens"
    }

    parts=("$dir_name" "$model_name")
    [[ -n "$git_branch" ]] && parts+=("$git_branch")
    token_bar=$(build_bar "$context_used" "$context_size")
    [[ -n "$token_bar" ]] && parts+=("$token_bar")

    result=""
    for part in "''${parts[@]}"; do
      [[ -z "$result" ]] && result="$part" || result="$result | $part"
    done
    echo "$result"
  '';
  weaveVersion = "0.2.3";
  weavePkg =
    binary: hashes:
    pkgs.stdenv.mkDerivation {
      pname = "weave-${binary}";
      version = weaveVersion;
      src =
        {
          x86_64-linux = pkgs.fetchurl {
            url = "https://github.com/Ataraxy-Labs/weave/releases/download/v${weaveVersion}/weave-${binary}-x86_64-unknown-linux-gnu.tar.gz";
            hash = hashes.x86_64;
          };
          aarch64-linux = pkgs.fetchurl {
            url = "https://github.com/Ataraxy-Labs/weave/releases/download/v${weaveVersion}/weave-${binary}-aarch64-unknown-linux-gnu.tar.gz";
            hash = hashes.aarch64;
          };
        }
        .${pkgs.stdenv.hostPlatform.system};
      sourceRoot = ".";
      nativeBuildInputs = [ pkgs.autoPatchelfHook ];
      buildInputs = [ pkgs.stdenv.cc.cc.lib ];
      installPhase =
        let
          binaryName = if binary == "cli" then "weave" else "weave-${binary}";
        in
        ''
          install -Dm755 ${binaryName} $out/bin/${binaryName}
        '';
    };
  weave = weavePkg "cli" {
    x86_64 = "sha256-xXyRPqxnCJULFQ2miy9+GX8ZzS5f+62Pv5q2eHKd0Gw=";
    aarch64 = "sha256-D2lUqRHoA63RJ57NUh4jzElTs4GUk0OH0r9YZvyKGh8=";
  };
  weaveDriver = weavePkg "driver" {
    x86_64 = "sha256-5LyDQrxAuW1S3qzeEnODNP7TPhc+KzsjW8j84yobhoE=";
    aarch64 = "sha256-HjkAcIJ9/4ulSJsRAhj23FSb2+1viIPV+4/JFTtVNiA=";
  };
in
{
  imports = lib.optional (builtins.pathExists personalFile) personalFile;
  nixpkgs.overlays = [
    (final: prev: {
      ec = prev.ec.overrideAttrs (old: rec {
        version = "0.3.1";
        src = prev.fetchFromGitHub {
          owner = "chojs23";
          repo = "ec";
          rev = "v${version}";
          hash = "sha256-tnOr0AVPwEm9gONa7gl3TzhPC5/1WEAbW7Ew5/mNn5U=";
        };
        vendorHash = "sha256-bV5y8zKculYULkFl9J95qebLOzdTT/LuYycqMmHKZ+g=";
      });
    })
  ];
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
      # Source HM session vars for non-interactive bash scripts (#!/bin/bash)
      BASH_ENV = "$HOME/.nix-profile/etc/profile.d/hm-session-vars.sh";
    };
    shellAliases = {
      g = "git";
      dinit = ''devenv init && printf '%s\n' '#!/usr/bin/env bash' 'export DIRENV_WARN_TIMEOUT=20s' 'eval "$(devenv direnvrc)"' 'use devenv' > .envrc && direnv allow'';
    };
  };

  home.packages =
    with pkgs;
    [
      age
      devenv
      ec
      fd
      fzf
      gibo
      jaq
      (pkgs.writeShellScriptBin "jq" ''exec jaq "$@"'')
      pv
      ripgrep
      tlrc
      tree
      waypipe
      weave
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
    nix-index-database.comma.enable = true;
    claude-code = {
      enable = true;
      # package = pkgs.claude-code.overrideAttrs (old: rec {
      #   version = "2.0.64";
      #   src = pkgs.fetchurl {
      #     url = "https://registry.npmjs.org/@anthropic-ai/claude-code/-/claude-code-${version}.tgz";
      #     hash = "sha256-H75i1x580KdlVjKH9V6a2FvPqoREK004CQAlB3t6rZ0=";
      #   };
      #   packageLock = pkgs.fetchurl {
      #     url = "https://raw.githubusercontent.com/NixOS/nixpkgs/d81147f1f1f508c6a62b7182b991aa1500e48cbe/pkgs/by-name/cl/claude-code/package-lock.json";
      #     hash = "sha256-u3zwMA/I/Np/DD2JDZyoKqByx+gP6c3EZvc+v+c42xA=";
      #   };
      #   npmDepsHash = "sha256-x1YerDQP1+kNS+mdIqSAE1e81fsd855KdJM+VBxaUBQ=";
      #   npmDeps = pkgs.fetchNpmDeps {
      #     inherit src;
      #     name = "${old.pname}-${version}-npm-deps";
      #     hash = npmDepsHash;
      #     postPatch = ''
      #       cp ${packageLock} package-lock.json
      #     '';
      #   };
      #   postPatch = ''
      #     cp ${packageLock} package-lock.json
      #     substituteInPlace cli.js \
      #       --replace-warn '#!/bin/bash' '#!/usr/bin/env bash'
      #   '';
      # });
    };
    delta = {
      enable = true;
      enableGitIntegration = true;
      options = {
        side-by-side = !isTermux;
        hyperlinks = true;
      };
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
      attributes = [ "* merge=weave" ];
      settings = {
        user.email = lib.mkDefault "johndoe@example.com";
        user.name = lib.mkDefault "John Doe";
        column.ui = "auto";
        branch.sort = "-committerdate";
        tag.sort = "version:refname";
        init.defaultBranch = "main";
        diff = {
          algorithm = "histogram";
          colorMoved = "zebra";
          colorMovedWS = "allow-indentation-change";
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
          writeCommitGraph = true;
        };
        transfer.fsckObjects = true;
        help.autocorrect = "prompt";
        commit.verbose = true;
        rerere = {
          enabled = true;
          autoupdate = true;
        };
        merge = {
          conflictStyle = "zdiff3";
          tool = "ec";
          weave = {
            name = "Entity-level semantic merge";
            driver = "${weaveDriver}/bin/weave-driver %O %A %B %L %P";
          };
        };
        mergetool = {
          ec = {
            cmd = ''ec "$BASE" "$LOCAL" "$REMOTE" "$MERGED"'';
            trustExitCode = true;
          };
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
      settings = {
        "*" = {
          AddKeysToAgent = "yes";
          IdentitiesOnly = true;
          HashKnownHosts = true;
          PreferredAuthentications = "publickey";
          StrictHostKeyChecking = "accept-new";
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
      shellWrapperName = "y";
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
      enableCompletion = false;
      autosuggestion.enable = true;
      dotDir = "${config.xdg.configHome}/zsh";
      envExtra = ''
        # global git hooks
        fpath+=($HOME/.nix-profile/share/zsh/site-functions)
        autoload -Uz git
      '';
      localVariables = {
        ZSH_COMPDUMP = "$HOME/.cache/.zcompdump-$HOST";
        ZSH_AUTOSUGGEST_MANUAL_REBIND = "1";
        ZSH_AUTOSUGGEST_USE_ASYNC = "1";
        ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE = "20";
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
          kardanTheme = lib.mkOrder 500 ''
            autoload -U colors && colors
            setopt PROMPT_SUBST

            function git_prompt_info() {
              local ref dirty=""
              ref=$(git symbolic-ref --short HEAD 2>/dev/null) || return
              git diff --quiet 2>/dev/null || dirty="%{$fg[yellow]%}✗%{$reset_color%}"
              echo "($ref$dirty)"
            }
            ${lib.optionalString isTermux ''
              function _prompt_pwd() {
                local dir="''${PWD/#\/data\/data\/com.termux\/files\/home/$HOME}"
                echo "''${dir/#$HOME/~}"
              }
            ''}
            PROMPT='> '
            RPROMPT='${if isTermux then "$(_prompt_pwd)" else "%~"}$(git_prompt_info)'
          '';
          ctrlzToggle = lib.mkOrder 1400 ''
            function fancy-ctrl-z() {
              if [[ $#BUFFER -eq 0 ]]; then
                BUFFER="fg"
                zle accept-line
              else
                zle push-input
                zle clear-screen
              fi
            }
            zle -N fancy-ctrl-z
            bindkey '^Z' fancy-ctrl-z
          '';
          zshConfig = lib.mkOrder 1500 ''eval "$(fzf --zsh| sed -e '/zmodload/s/perl/perl_off/' -e '/selected/s/fc -rl/fc -rlt "%y-%m-%d"/')"'';
        in
        lib.mkMerge [
          kardanTheme
          ctrlzToggle
          zshConfig
        ];
      siteFunctions = {
        gclone = ''gitstrip="''${1#*:}"; gitpath="''${gitstrip%.git}"; git clone "$1" "''${gitpath%.git}"'';
        mkcd = ''mkdir --parents "$1" && cd "$1"'';
        tch = ''mkdir --parents "$(dirname "$@")" && touch "$@"'';
        git = ''${gitHooksWrapper} "$(whence -p git)" "$@"'';
      };
      prezto = {
        enable = true;
        caseSensitive = false;
        editor = {
          dotExpansion = true;
          keymap = "vi";
        };
        pmodules = [
          "environment"
          "terminal"
          "editor"
          "history"
          "directory"
          "spectrum"
          "utility"
          "completion"
          "history-substring-search"
        ];
      };
    };
    zellij = {
      enable = true;
      enableZshIntegration = false;
    };
  };

  home.activation.claudeSettings =
    let
      declarative = pkgs.writeText "claude-settings-declarative.json" (
        builtins.toJSON {
          statusLine = {
            type = "command";
            command = "${claudeStatusLine}";
          };
          attribution = {
            commit = "";
            pr = "";
          };
          permissions.allow = [
            "WebSearch"
            "WebFetch"
          ];
        }
      );
      target = "${homeDirectory}/.claude/settings.json";
    in
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      if [ -f "${target}" ]; then
        cp "${target}" "${target}.bak"
        { cat "${target}"; cat ${declarative}; } | ${pkgs.jaq}/bin/jaq -s '.[0] * .[1]' > "${target}.tmp"
        mv "${target}.tmp" "${target}"
      else
        install -Dm644 ${declarative} "${target}"
      fi
    '';

  manual = {
    html.enable = true;
    json.enable = true;
  };
}
