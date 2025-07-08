{ inputs, username, homeDirectory, config, lib, pkgs, ... }:

let
  personalFile =
    "${config.home.homeDirectory}/.config/home-manager/personal.nix";
  personal = if builtins.pathExists personalFile then
    import personalFile
  else {
    ssh_match_blocks = { };
    git_includes = [ ];
    git_extra = { };
  };
in {

  home.sessionVariables = { CARGO_HOME = "$HOME/.cache/cargo"; };
  home.packages = with pkgs; [ age devenv fzf htop jaq ripgrep tlrc tree ];
  home.file = {
    ".config/git/ignore_misc".text = lib.concatStringsSep "\n" [
      ".claude/"
      ".devenv*"
      ".direnv*"
      ".envrc"
      ".helix/"
      ".pre-commit-config.yaml"
      "devenv*"
      "direnv*"
    ];
  };

  programs = {
    home-manager.enable = true;
    delta = {
      enable = true;
      enableGitIntegration = true;
    };
    git = {
      enable = true;
      ignores = [
        "*.env"
        "/env/"
        ".devenv*"
        ".direnv/"
        ".devcontainer/"
        ".pre-commit-config.yaml"
      ];
      lfs.enable = true;
      settings = personal.git_extra // {
        user.email = "johndoe@example.com";
        user.name = "John Doe";
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
      includes = personal.git_includes;
    };
    gitui.enable = true;
    ssh = {
      enable = true;
      enableDefaultConfig = false;
      matchBlocks = personal.ssh_match_blocks // {
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
        keys.select = { "A-tab" = ":buffer-next"; };
      };
      languages = {
        language = [
          {
            name = "nix";
            auto-format = true;
            formatter.command = "${pkgs.nixfmt-classic}/bin/nixfmt";
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
      settings = { mgr = { show_hidden = true; }; };
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
      localVariables = { ZSH_COMPDUMP = "$HOME/.cache/.zcompdump-$HOST"; };
      history = {
        share = false;
        append = true;
        saveNoDups = true;
        ignoreAllDups = true;
        ignoreSpace = true;
        extended = true;
      };
      initContent = let
        zshConfig = lib.mkOrder 1500 ''
          eval "$(fzf --zsh| sed -e '/zmodload/s/perl/perl_off/' -e '/selected/s/fc -rl/fc -rlt "%y-%m-%d"/')"'';
      in lib.mkMerge [ zshConfig ];
      siteFunctions = {
        gclone = ''
          gitstrip="''${1#*:}"; gitpath="''${gitstrip%.git}"; git clone "$1" "''${gitpath%.git}"'';
        mkcd = ''mkdir --parents "$1" && cd "$1"'';
        tch = ''mkdir --parents "$(dirname "$@")" && touch "$@"'';
      };
      prezto = {
        enable = false;
        caseSensitive = false;
        editor.keymap = "vi";
      };
      oh-my-zsh = {
        enable = true;
        plugins = [ "git" "fzf" ];
        theme = "kardan";
      };
    };
    zellij = {
      enable = true;
      enableZshIntegration = false;
    };
  };
}
