# nix-packaging Specification

## Purpose
TBD - created by archiving change add-kiro-desktop-package. Update Purpose after archive.
## Requirements
### Requirement: Kiro Desktop Package Derivation
The flake SHALL provide a default package that fetches and installs the pre-built Kiro desktop application (version 0.5.0, Electron 37.5.1, VSCode 1.103.2 base) from the official release tarball.

#### Scenario: Package builds successfully
- **WHEN** user runs `nix build`
- **THEN** the Kiro desktop tarball is fetched from https://prod.download.desktop.kiro.dev/releases/202510301715--distro-linux-x64-tar-gz/202510301715-distro-linux-x64.tar.gz
- **AND** the tarball SHA256 hash is verified before extraction
- **AND** the tarball (244M compressed → 720M extracted) is unpacked into the Nix store
- **AND** the build completes without errors

#### Scenario: Package structure is preserved
- **WHEN** the package is built
- **THEN** the main `kiro` binary (193M Electron executable) is installed to `$out/lib/kiro/kiro`
- **AND** the wrapper script `bin/kiro` is installed to `$out/bin/kiro`
- **AND** all bundled shared libraries (libffmpeg.so, libEGL.so, libGLESv2.so, libvulkan.so.1, libvk_swiftshader.so) are preserved in `$out/lib/kiro/`
- **AND** the `resources/` directory with 94 extensions (346M) and AI models (23M) is preserved
- **AND** the `locales/` directory with 58 locale .pak files is preserved
- **AND** all native Node.js addons (.node files) remain in their original locations

### Requirement: System Dependencies
The package SHALL declare and inject all required system libraries for the Electron application and GTK-based UI.

#### Scenario: Core graphics dependencies are available
- **WHEN** the package is built
- **THEN** glib, gtk3, cairo, pango, atk, and at-spi2-atk are included in buildInputs
- **AND** these libraries are findable by the patched binary at runtime

#### Scenario: X11 and display dependencies are available
- **WHEN** the package is built
- **THEN** xorg.libX11, xorg.libXcomposite, xorg.libXdamage, xorg.libXext, xorg.libXfixes, xorg.libXrandr, libxcb, and libxkbcommon are included
- **AND** the application can connect to X11 or Wayland displays

#### Scenario: Mozilla and security libraries are available
- **WHEN** the package is built
- **THEN** nspr and nss (Mozilla libraries) are included
- **AND** the Chromium security stack functions correctly

#### Scenario: Device and system libraries are available
- **WHEN** the package is built
- **THEN** cups (printing), mesa (libgbm for GPU), udev (device management), alsa-lib (audio), dbus, and expat are included
- **AND** hardware acceleration and device access work as expected

### Requirement: Binary Patching
The package SHALL patch all ELF binaries and native addons to work with Nix library paths.

#### Scenario: Main binary is patched
- **WHEN** the package is built with autoPatchelfHook
- **THEN** the main `kiro` binary interpreter is set to the Nix glibc dynamic linker
- **AND** the RPATH is updated to include Nix library paths while preserving `$ORIGIN` for bundled libraries
- **AND** all required shared library dependencies are resolved

#### Scenario: Native Node.js addons are patched
- **WHEN** the package is built
- **THEN** all .node files in `resources/app/node_modules/` are patched (pty.node, keymapping.node, watchdog.node, watcher.node, spdlog.node, vscode-sqlite3.node, kerberos.node)
- **AND** all .node files in the kiro-agent extension are patched (index.node 57M vector DB, node_sqlite3.node, onnxruntime_binding.node)
- **AND** native addons can load their dependencies from Nix paths

#### Scenario: Helper binaries are patched
- **WHEN** the package is built
- **THEN** chrome_crashpad_handler (1.5M crash reporter) is patched
- **AND** chrome-sandbox (15K sandbox helper) is patched

### Requirement: Runtime Environment Configuration
The package SHALL provide a wrapper that configures the execution environment for bundled libraries and Electron-specific settings.

#### Scenario: Wrapper preserves bundled library paths
- **WHEN** user runs `nix run` or executes `$out/bin/kiro`
- **THEN** the wrapper sets LD_LIBRARY_PATH to include `$out/lib/kiro` for bundled libraries
- **AND** the RPATH=$ORIGIN setting in the binary finds libffmpeg.so, libEGL.so, libGLESv2.so, libvulkan.so.1, and libvk_swiftshader.so
- **AND** the application does not fail due to missing bundled libraries

#### Scenario: Wrapper handles Electron execution
- **WHEN** the wrapper script runs
- **THEN** it sets ELECTRON_RUN_AS_NODE=1 and executes the main binary with CLI args
- **AND** it passes through all command-line arguments to the Electron app
- **AND** it correctly resolves the script location via readlink for symlink support

#### Scenario: Sandbox configuration is handled
- **WHEN** the application starts
- **THEN** either chrome-sandbox has correct permissions OR --no-sandbox flag is passed
- **AND** the Chromium sandbox initializes without errors OR runs in no-sandbox mode safely

### Requirement: Desktop Integration
The package SHALL provide desktop environment integration for launching Kiro from application menus.

#### Scenario: Desktop entry is installed
- **WHEN** the package is built
- **THEN** a .desktop file is created at `$out/share/applications/kiro.desktop`
- **AND** the desktop entry has Name=Kiro, Exec=$out/bin/kiro, and Type=Application
- **AND** the desktop entry includes relevant categories (Development;IDE;TextEditor)
- **AND** the desktop entry specifies MimeType for supported file types

#### Scenario: Application icon is available
- **WHEN** the package is built
- **THEN** an icon is extracted or linked from the resources
- **AND** the icon is installed to `$out/share/icons/hicolor/*/apps/kiro.png` or similar
- **AND** the desktop entry Icon field points to the installed icon

### Requirement: Shell Completion Support
The package SHALL install shell completions for bash and zsh.

#### Scenario: Bash completion is installed
- **WHEN** the package is built
- **THEN** the file `resources/completions/bash/kiro` is installed to `$out/share/bash-completion/completions/kiro`
- **AND** bash users get command completion for Kiro CLI arguments

#### Scenario: Zsh completion is installed
- **WHEN** the package is built
- **THEN** the file `resources/completions/zsh/_kiro` is installed to `$out/share/zsh/site-functions/_kiro`
- **AND** zsh users get command completion for Kiro CLI arguments

### Requirement: Source Verification
The package SHALL verify the integrity of the downloaded tarball using a cryptographic hash.

#### Scenario: Tarball hash verification
- **WHEN** the package fetches the tarball with pkgs.fetchurl
- **THEN** the hash is verified against the computed SHA256 value
- **AND** the build fails immediately if the hash does not match
- **AND** the hash value is explicitly documented in the flake.nix source code

### Requirement: Flake Output Structure
The package SHALL be exposed as the default flake output with complete metadata.

#### Scenario: Default package is defined
- **WHEN** user runs `nix flake show`
- **THEN** `packages.${system}.default` is defined and points to kiro-desktop
- **AND** `packages.${system}.kiro-desktop` is also available as a named output
- **AND** the output includes the x86_64-linux system

#### Scenario: Package metadata is complete
- **WHEN** the package derivation is defined
- **THEN** pname = "kiro-desktop"
- **AND** version = "0.5.0" (or extracted from tarball name)
- **AND** meta.description = "Kiro Desktop - AWS Electron-based IDE with AI (VSCode fork)"
- **AND** meta.homepage = "https://kiro.dev"
- **AND** meta.license includes AWS-IPL license information
- **AND** meta.platforms = [ "x86_64-linux" ]
- **AND** meta.mainProgram = "kiro" for `nix run` support

### Requirement: AI Features Support
The package SHALL preserve and enable ML models and vector database functionality for AI-powered features.

#### Scenario: ML models are accessible
- **WHEN** the application starts and uses AI features
- **THEN** the all-MiniLM-L6-v2 model (23M) in `resources/app/extensions/kiro.kiro-agent/models/` is accessible
- **AND** the quantized ONNX model (model_quantized.onnx) loads successfully
- **AND** semantic embeddings and code search features work

#### Scenario: Vector database operates correctly
- **WHEN** AI features index code or perform semantic search
- **THEN** the LanceDB native addon (index.node 57M) functions correctly
- **AND** ONNX runtime bindings (onnxruntime_binding.node) load the .so libraries
- **AND** vector similarity search completes without crashes

#### Scenario: Tree-sitter parsers are available
- **WHEN** the application parses source code
- **THEN** all 27 tree-sitter WASM parsers (bash, c, cpp, python, rust, typescript, etc.) are accessible
- **AND** syntax highlighting and code analysis features work for supported languages

