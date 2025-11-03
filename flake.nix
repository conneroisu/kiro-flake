{
  description = "";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    treefmt-nix.url = "github:numtide/treefmt-nix";
    treefmt-nix.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = {
    self,
    nixpkgs,
    flake-utils,
    treefmt-nix,
    ...
  }:
    flake-utils.lib.eachDefaultSystem (system: let
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
        overlays = [
          (final: prev: {
          })
        ];
      };

      rooted = exec:
        builtins.concatStringsSep "\n"
        [
          ''REPO_ROOT="$(git rev-parse --show-toplevel)"''
          exec
        ];

      scripts = {
        dx = {
          exec = rooted ''$EDITOR "$REPO_ROOT"/flake.nix'';
          description = "Edit flake.nix";
        };
      };

      scriptPackages =
        pkgs.lib.mapAttrs
        (
          name: script:
            pkgs.writeShellApplication {
              inherit name;
              text = script.exec;
              runtimeInputs = script.deps or [];
            }
        )
        scripts;

      treefmtModule = {
        projectRootFile = "flake.nix";
        programs = {
          alejandra.enable = true; # Nix formatter
        };
      };
    in {
      devShells.default = pkgs.mkShell {
        name = "dev";

        # Available packages on https://search.nixos.org/packages
        packages = with pkgs;
          [
            alejandra # Nix
            nixd
            statix
            deadnix
          ]
          ++ builtins.attrValues scriptPackages;
      };

      packages = {
        kiro-desktop = pkgs.stdenv.mkDerivation rec {
          pname = "kiro-desktop";
          version = "0.5.0";

          # SHA256 hash calculated with nix-prefetch-url
          # Hash: sha256-XUby2u/pMgSfYOG08ix3f64Tlc/5oMzh3eabRDRElBg=
          src = pkgs.fetchurl {
            url = "https://prod.download.desktop.kiro.dev/releases/202510301715--distro-linux-x64-tar-gz/202510301715-distro-linux-x64.tar.gz";
            hash = "sha256-XUby2u/pMgSfYOG08ix3f64Tlc/5oMzh3eabRDRElBg=";
          };

          # Tarball extracts to Kiro/ directory
          sourceRoot = ".";

          # Native build tools for patching and wrapping
          nativeBuildInputs = with pkgs; [
            autoPatchelfHook
            makeWrapper
            copyDesktopItems
          ];

          # System dependencies required by Electron and native addons
          buildInputs = with pkgs; [
            # Core graphics stack
            glib
            gtk3
            cairo
            pango
            atk
            at-spi2-atk

            # X11 display libraries
            xorg.libX11
            xorg.libXcomposite
            xorg.libXdamage
            xorg.libXext
            xorg.libXfixes
            xorg.libXrandr
            libxcb
            libxkbcommon
            xorg.libxkbfile

            # Mozilla crypto stack
            nspr
            nss

            # Hardware and system integration
            cups
            mesa # for libgbm
            systemd # for libudev
            alsa-lib
            dbus
            expat

            # Optional but recommended
            libsecret
            krb5
          ];

          # Install phase: copy entire structure to $out/lib/kiro
          installPhase = ''
            runHook preInstall

            # Create main installation directory
            mkdir -p $out/lib/kiro

            # Copy main Electron binary (193M)
            cp Kiro/kiro $out/lib/kiro/

            # Copy bundled graphics libraries
            cp Kiro/libffmpeg.so $out/lib/kiro/
            cp Kiro/libEGL.so $out/lib/kiro/
            cp Kiro/libGLESv2.so $out/lib/kiro/
            cp Kiro/libvulkan.so.1 $out/lib/kiro/
            cp Kiro/libvk_swiftshader.so $out/lib/kiro/

            # Copy support files
            cp Kiro/chrome-sandbox $out/lib/kiro/
            cp Kiro/chrome_crashpad_handler $out/lib/kiro/
            cp Kiro/*.pak $out/lib/kiro/
            cp Kiro/*.bin $out/lib/kiro/
            cp Kiro/*.dat $out/lib/kiro/
            cp Kiro/*.json $out/lib/kiro/

            # Copy locales directory (58 locale files)
            cp -r Kiro/locales $out/lib/kiro/

            # Copy resources directory (436M with extensions and AI models)
            cp -r Kiro/resources $out/lib/kiro/

            runHook postInstall
          '';

          # Manual patching for .node files that autoPatchelfHook might miss
          preFixup = ''
            # Patch all native Node.js addons
            find $out/lib/kiro/resources -name '*.node' -exec \
              patchelf --set-rpath "${pkgs.lib.makeLibraryPath buildInputs}:$out/lib/kiro" {} \;
          '';

          # Create wrapper script
          postFixup = ''
            # Create wrapper at $out/bin/kiro
            makeWrapper $out/lib/kiro/kiro $out/bin/kiro \
              --prefix LD_LIBRARY_PATH : "$out/lib/kiro" \
              --set ELECTRON_RUN_AS_NODE 1 \
              --add-flags "$out/lib/kiro/resources/app/out/cli.js"

            # Install desktop entry
            mkdir -p $out/share/applications
            cat > $out/share/applications/kiro.desktop <<EOF
            [Desktop Entry]
            Name=Kiro
            Comment=AWS AI-powered IDE (VSCode fork)
            Exec=kiro %U
            Icon=kiro
            Type=Application
            Categories=Development;IDE;TextEditor;
            MimeType=text/plain;text/x-source;
            StartupWMClass=Kiro
            EOF

            # TODO: Extract and install icon from resources
            # Icons should be in resources/app/resources/linux/ or similar

            # Install shell completions if they exist
            if [ -d Kiro/resources/completions/bash ]; then
              mkdir -p $out/share/bash-completion/completions
              cp Kiro/resources/completions/bash/kiro $out/share/bash-completion/completions/ || true
            fi

            if [ -d Kiro/resources/completions/zsh ]; then
              mkdir -p $out/share/zsh/site-functions
              cp Kiro/resources/completions/zsh/_kiro $out/share/zsh/site-functions/ || true
            fi
          '';

          meta = with pkgs.lib; {
            description = "Kiro Desktop - AWS Electron-based IDE with AI (VSCode fork)";
            homepage = "https://kiro.dev";
            platforms = ["x86_64-linux"];
            mainProgram = "kiro";
            license = licenses.unfree; # AWS-IPL
            # Note: This package is 720M extracted and requires a graphical environment
          };
        };

        default = self.packages.${system}.kiro-desktop;
      };

      formatter = treefmt-nix.lib.mkWrapper pkgs treefmtModule;
    });
}
