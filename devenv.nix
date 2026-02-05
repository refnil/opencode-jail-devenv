{
  pkgs,
  lib,
  config,
  inputs,
  ...
}:
with lib;
let
  cfg = config.programs.opencode;

  packages =
    cfg.basePackages ++ cfg.packages ++ (if cfg.addProjectPackages then config.packages else [ ]);

  jail_env = pkgs.mkShell {
    inherit packages;
    buildPhase = ''
      unset HOME
      unset PWD
      unset name
      unset SSL_CERT_FILE
      unset TMP
      unset TMPDIR
      unset TEMP
      unset TEMPDIR
      unset XDG_DATA_DIRS

      # Unset each variable
      lowercase_vars=$(export | sed -e "s/^declare -x //" | grep '^[^A-Z].*=' | grep -v '^out=' | cut -d= -f1)

      for var in $lowercase_vars; do
        unset "$var"
        echo "Unset: $var"
      done

      export > $out
    '';
  };

  opencode_with_env =
    with pkgs;
    stdenv.mkDerivation {
      name = "opencode-wrapped";
      phases = [ "buildPhase" ];
      nativeBuildInputs = [ pkgs.makeWrapper ];
      buildPhase = ''
        makeWrapper ${cfg.opencodePackage}/bin/opencode $out/bin/opencode \
          --run "source ${jail_env}"
      '';
      meta.mainProgram = "opencode";
    };

  opencode_jail = pkgs.jail "opencode" opencode_with_env (
    cfg.baseJailCombinators ++ cfg.jailCombinators
  );
in
{
  options.programs.opencode = {
    enable = mkEnableOption "opencode";

    addProjectPackages = mkOption {
      type = types.bool;
      default = true;
      example = false;
      description = "Add config.packages to programs.opencode.packages";
    };

    basePackages = mkOption {
      type = types.listOf types.package;
      default = with pkgs; [
        bashInteractive
        curl
        wget
        jq
        git
        which
        ripgrep
        gnugrep
        gawkInteractive
        ps
        findutils
        gzip
        unzip
        gnutar
        diffutils
      ];
      description = "Add basic packages (e.g., curl, ripgrep) to programs.opencode.packages";
    };

    packages = mkOption {
      type = types.listOf types.package;
      default = [ ];
      description = "List of packages to add to the opencode path";
    };

    opencodePackage = mkOption {
      type = types.package;
      default = pkgs.opencode;
      description = "Opencode package";
    };

    baseJailCombinators = mkOption {
      default = with pkgs.jail.combinators; [
        network
        time-zone
        no-new-session
        (tmpfs "/tmp")

        # Give it a safe spot for its own config and cache.
        # This also lets it remember things between sessions.
        (readwrite (noescape "~/.config/opencode"))
        (readwrite (noescape "~/.local/share/opencode"))
        (readwrite (noescape "~/.local/state/opencode"))

        # Allow agents to see the full project
        (
          let
            path = config.devenv.root;
          in
          rw-bind path path
        )
      ];
      description = "Base jail permissions";
    };

    jailCombinators = mkOption {
      default = [ ];
      description = "Permissions to add to the project";
    };
  };

  config =
    let
      realConfig = mkIf cfg.enable {
        overlays = [
          (final: prev: { jail = inputs.jail-nix.lib.init prev; })
        ];

        inputsFrom = [
          # Workaround to include opencode in the shell while also referencing
          # every other packages defined in config.packages.
          (pkgs.mkShell {
            packages = [ opencode_jail ];
          })
        ];
      };
      testConfig = {
        profiles.dev-opencode-module.module = {
          programs.opencode.enable = true;
          packages = with pkgs; [ nixfmt ];
        };
      };
    in
    mkMerge [
      realConfig
      testConfig
    ];
}
