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

      # Platform-specific release URLs and hashes
      releaseConfig = {
        "x86_64-linux" = {
          url = "https://prod.download.desktop.kiro.dev/releases/stable/linux-x64/signed/1.0.437/tar/kiro-ide-1.0.437-stable-linux-x64.tar.gz";
          hash = "sha256-Fh3/vQTqs1nPcIxGeXf38wSBSp7LvvqLxGg4aXJVrCQ=";
          platform = "linux";
          enabled = true;
        };
        "aarch64-darwin" = {
          url = "https://prod.download.desktop.kiro.dev/releases/stable/linux-x64/signed/1.0.437/tar/kiro-ide-1.0.437-stable-linux-x64.tar.gz";
          # Hash in base32 format from nix-prefetch-url (1.4GB DMG file)
          hash = "sha256:1jh4zl4rg4p3s997l1lfk0v1caj02ay9h7ny0avbrn0yp9pv8nhx";
          platform = "darwin";
          enabled = true;
        };
      };

      currentRelease = releaseConfig.${system} or null;
      isSupported = currentRelease != null && (currentRelease.enabled or true);

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

      packages = if !isSupported then {} else {
        kiro-desktop = pkgs.stdenv.mkDerivation rec {
          pname = "kiro-desktop";
          version = "1.0.437";

          # Platform-specific source
          src = pkgs.fetchurl {
            url = currentRelease.url;
            hash = currentRelease.hash;
          };

          # Handle both tarball (Linux) and DMG (macOS)
          sourceRoot = if currentRelease.platform == "linux" then "." else ".";
          
          # Don't try to unpack DMG files - we'll handle them specially
          unpackCmd = if currentRelease.platform == "darwin" then ":" else "";
          phases = if currentRelease.platform == "darwin" 
            then ["unpackPhase" "installPhase" "postFixup"]
            else ["unpackPhase" "installPhase" "preFixup" "postFixup"];

          # Platform-specific native build inputs
          nativeBuildInputs = with pkgs; [
            makeWrapper
            copyDesktopItems
          ] ++ (if currentRelease.platform == "linux" then [
            autoPatchelfHook
          ] else if currentRelease.platform == "darwin" then [
            # macOS-specific tools for DMG mounting are built-in
            # (hdiutil is a macOS system utility, not packaged in nixpkgs)
          ] else []);

          # System dependencies required by Electron and native addons
          buildInputs = with pkgs;
            (if currentRelease.platform == "linux" then [
              # Core graphics stack
              glib
              gtk3
              webkitgtk_4_1
              libsoup_3
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
              mesa # for OpenGL
              libgbm # for GBM (Generic Buffer Management)
              systemd # for libudev
              alsa-lib
              dbus
              expat

              # Optional but recommended
              libsecret
              krb5
            ] else if currentRelease.platform == "darwin" then [
              # macOS framework dependencies
              # These are typically already available in system frameworks
              # but we may need SDK headers or specific dylibs
            ] else []);

          # Install phase: platform-specific installation
          installPhase = if currentRelease.platform == "linux" then ''
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
          '' else if currentRelease.platform == "darwin" then ''
            runHook preInstall

            # macOS: The source is a pre-built DMG file
            # Mount it temporarily to extract the app bundle
            TEMP_MOUNT=$(mktemp -d)
            hdiutil attach "$src" -mountpoint "$TEMP_MOUNT" -nobrowse
            
            # Find and copy the .app bundle
            APP_BUNDLE=$(find "$TEMP_MOUNT" -name "Kiro.app" -type d | head -1)
            
            if [ -n "$APP_BUNDLE" ]; then
              mkdir -p $out/Applications
              cp -r "$APP_BUNDLE" $out/Applications/
              echo "Extracted: $APP_BUNDLE"
            else
              # Fallback: try to find any .app bundle
              find "$TEMP_MOUNT" -name "*.app" -type d -print
              echo "ERROR: No .app bundle found in DMG"
              exit 1
            fi
            
            # Unmount the DMG
            hdiutil detach "$TEMP_MOUNT"
            
            runHook postInstall
          '' else throw "Unsupported platform: ${currentRelease.platform}";

          # Manual patching for .node files that autoPatchelfHook might miss
           preFixup = if currentRelease.platform == "linux" then ''
             # Patch main binary with library paths
             patchelf --set-rpath "${pkgs.lib.makeLibraryPath buildInputs}:$out/lib/kiro" $out/lib/kiro/kiro
             
             # Patch all native Node.js addons
             find $out/lib/kiro/resources -name '*.node' -exec \
               patchelf --set-rpath "${pkgs.lib.makeLibraryPath buildInputs}:$out/lib/kiro" {} \;
           '' else if currentRelease.platform == "darwin" then ''
             # macOS: nothing to patch in preFixup
             # DYLD paths are handled in wrapper and at runtime
           '' else "";

          # Create wrapper script and install files
           postFixup = if currentRelease.platform == "linux" then ''
             # Create wrapper at $out/bin/kiro (Linux)
             makeWrapper $out/lib/kiro/kiro $out/bin/kiro \
               --prefix LD_LIBRARY_PATH : "${pkgs.lib.makeLibraryPath buildInputs}:$out/lib/kiro" \
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
          '' else if currentRelease.platform == "darwin" then ''
            # Create wrapper script for macOS
            mkdir -p $out/bin
            cat > $out/bin/kiro << 'WRAPPER'
            #!/bin/bash
            APP_DIR="@out@/Applications/Kiro.app/Contents/MacOS"
            RESOURCES_DIR="@out@/Applications/Kiro.app/Contents/Resources"
            
            # Set up macOS-specific environment
            export DYLD_LIBRARY_PATH="$APP_DIR:${pkgs.lib.makeLibraryPath buildInputs}:$DYLD_LIBRARY_PATH"
            export DYLD_FRAMEWORK_PATH="/System/Library/Frameworks:/Library/Frameworks:$DYLD_FRAMEWORK_PATH"
            
            # Execute the main application
            exec "$APP_DIR/Kiro" "$@"
            WRAPPER
            chmod +x $out/bin/kiro
            
            # Substitute @out@ placeholder
            substituteInPlace $out/bin/kiro \
              --subst-var out

            # Install shell completions if they exist
            if [ -d Kiro/resources/completions/bash ]; then
              mkdir -p $out/share/bash-completion/completions
              cp Kiro/resources/completions/bash/kiro $out/share/bash-completion/completions/ || true
            fi

            if [ -d Kiro/resources/completions/zsh ]; then
              mkdir -p $out/share/zsh/site-functions
              cp Kiro/resources/completions/zsh/_kiro $out/share/zsh/site-functions/ || true
            fi
          '' else "";

          meta = with pkgs.lib; {
            description = "Kiro Desktop - AWS Electron-based IDE with AI (VSCode fork)";
            homepage = "https://kiro.dev";
            platforms = 
              if currentRelease.platform == "linux" then ["x86_64-linux"]
              else if currentRelease.platform == "darwin" then ["aarch64-darwin"]
              else [];
            mainProgram = "kiro";
            license = licenses.unfree; # AWS-IPL
            # Note: This package is 720M extracted and requires a graphical environment
          };
        };

        default = self.packages.${system}.kiro-desktop;
      } // (
        # Add DMG output for macOS (only on macOS system)
        # DMG is pre-built, so we just copy it
        if isSupported && currentRelease.platform == "darwin" && system == "aarch64-darwin" then {
          dmg = pkgs.runCommand "kiro-0.8.86.dmg" {} ''
            # The source is already a DMG file, just copy it
            cp "${self.packages.${system}.kiro-desktop.src}" "$out"
          '';
        } else {}
      );

      formatter = treefmt-nix.lib.mkWrapper pkgs treefmtModule;
    });
}
