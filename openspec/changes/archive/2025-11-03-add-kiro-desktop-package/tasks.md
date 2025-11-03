# Implementation Tasks

## 1. Source Preparation
- [x] 1.1 Calculate SHA256 hash for tarball using `nix-prefetch-url https://prod.download.desktop.kiro.dev/releases/202510301715--distro-linux-x64-tar-gz/202510301715-distro-linux-x64.tar.gz`
- [x] 1.2 Document the hash value in comments for future updates

## 2. Package Definition and Metadata
- [x] 2.1 Define `kiro-desktop` package in flake.nix under `packages.kiro-desktop` using `pkgs.stdenv.mkDerivation`
- [x] 2.2 Set `pname = "kiro-desktop"`
- [x] 2.3 Set `version = "0.5.0"` (from investigation: Kiro version 0.5.0)
- [x] 2.4 Create `src` using `pkgs.fetchurl` with the tarball URL and calculated hash
- [x] 2.5 Set `meta.description = "Kiro Desktop - AWS Electron-based IDE with AI (VSCode fork)"`
- [x] 2.6 Set `meta.homepage = "https://kiro.dev"`
- [x] 2.7 Set `meta.platforms = [ "x86_64-linux" ]`
- [x] 2.8 Set `meta.mainProgram = "kiro"` for `nix run` support
- [x] 2.9 Add `meta.license` with AWS-IPL information
- [x] 2.10 Assign to `packages.default = packages.kiro-desktop`

## 3. System Dependencies Declaration
- [x] 3.1 Add to `nativeBuildInputs`: autoPatchelfHook, makeWrapper, copyDesktopItems (or makeDesktopItem)
- [x] 3.2 Add core graphics to `buildInputs`: glib, gtk3, cairo, pango, atk, at-spi2-atk
- [x] 3.3 Add X11/display to `buildInputs`: xorg.libX11, xorg.libXcomposite, xorg.libXdamage, xorg.libXext, xorg.libXfixes, xorg.libXrandr, libxcb, libxkbcommon
- [x] 3.4 Add Mozilla libs to `buildInputs`: nspr, nss
- [x] 3.5 Add device/system to `buildInputs`: cups, mesa (for libgbm), systemd (for libudev), alsa-lib, dbus, expat
- [x] 3.6 Add optional dependencies: libsecret, krb5 (for kerberos.node addon)

## 4. Unpack Phase
- [x] 4.1 Set `sourceRoot = "."` since tarball extracts to `Kiro/` directory
- [x] 4.2 Verify tarball extraction creates expected structure: kiro binary, resources/, locales/, bin/kiro

## 5. Install Phase - Main Structure
- [x] 5.1 Create `$out/lib/kiro` directory for main installation
- [x] 5.2 Copy main `kiro` binary (193M Electron executable) to `$out/lib/kiro/kiro`
- [x] 5.3 Copy all bundled .so files to `$out/lib/kiro/`: libffmpeg.so, libEGL.so, libGLESv2.so, libvulkan.so.1, libvk_swiftshader.so
- [x] 5.4 Copy all support files: chrome-sandbox, chrome_crashpad_handler, icudtl.dat, snapshot_blob.bin, v8_context_snapshot.bin, *.pak files, vk_swiftshader_icd.json
- [x] 5.5 Copy `locales/` directory with all 58 locale .pak files to `$out/lib/kiro/locales/`
- [x] 5.6 Copy entire `resources/` directory (436M with 94 extensions, AI models, node_modules) to `$out/lib/kiro/resources/`
- [x] 5.7 Verify native .node addons are preserved: resources/app/node_modules/{node-pty,native-keymap,@vscode/sqlite3,@parcel/watcher}/build/Release/*.node
- [x] 5.8 Verify kiro-agent extension files: resources/app/extensions/kiro.kiro-agent/ with index.node (57M), models/, node_modules/

## 6. Binary Patching with autoPatchelfHook
- [x] 6.1 Allow autoPatchelfHook to run automatically on main `kiro` binary
- [x] 6.2 Set `dontAutoPatchelf = false` (or omit, default behavior)
- [x] 6.3 Use `preFixup` hook to manually patch any .node files missed by autoPatchelfHook using `find $out -name '*.node' -exec patchelf ... \;`
- [x] 6.4 Verify chrome_crashpad_handler and chrome-sandbox are patched
- [x] 6.5 Test that RPATH includes both Nix paths and `$ORIGIN` for bundled libraries

## 7. Wrapper Script Creation
- [x] 7.1 Create wrapper at `$out/bin/kiro` using `makeWrapper`
- [x] 7.2 Wrap `$out/lib/kiro/kiro` as the main executable
- [x] 7.3 Set `--prefix LD_LIBRARY_PATH : "$out/lib/kiro"` for bundled libraries
- [x] 7.4 Set `--set ELECTRON_RUN_AS_NODE 1` for CLI mode
- [x] 7.5 Add `--add-flags "$out/lib/kiro/resources/app/out/cli.js"` to execute CLI entry point
- [x] 7.6 Consider adding `--add-flags "--no-sandbox"` if chrome-sandbox setup is complex (test without first)
- [x] 7.7 Test wrapper passes through CLI arguments correctly: `kiro --help`, `kiro file.txt`

## 8. Desktop Integration
- [x] 8.1 Create `.desktop` file content with: Name=Kiro, Comment=AWS AI-powered IDE, Exec=kiro %U, Icon=kiro, Type=Application, Categories=Development;IDE;TextEditor;
- [x] 8.2 Add MimeType entries for common code file types
- [x] 8.3 Install .desktop file to `$out/share/applications/kiro.desktop`
- [x] 8.4 Extract or create icon from resources (check resources/app for .png/.svg icons)
- [x] 8.5 Install icon to `$out/share/icons/hicolor/*/apps/kiro.png` (multiple resolutions if available)
- [x] 8.6 Run `gtk-update-icon-cache` in postInstall if needed

## 9. Shell Completions Installation
- [x] 9.1 Install bash completion: `cp $sourceRoot/Kiro/resources/completions/bash/kiro $out/share/bash-completion/completions/kiro`
- [x] 9.2 Create `$out/share/bash-completion/completions/` directory before copying
- [x] 9.3 Install zsh completion: `cp $sourceRoot/Kiro/resources/completions/zsh/_kiro $out/share/zsh/site-functions/_kiro`
- [x] 9.4 Create `$out/share/zsh/site-functions/` directory before copying

## 10. Build Testing
- [x] 10.1 Run `nix build .#kiro-desktop` and verify it completes without errors
- [x] 10.2 Check build output size is ~720M + dependencies
- [x] 10.3 Verify `result/bin/kiro` exists and is executable
- [x] 10.4 Check `result/lib/kiro/` contains all expected files

## 11. Runtime Testing
- [x] 11.1 Run `nix run .#kiro-desktop -- --version` and verify output shows version 0.5.0
- [x] 11.2 Run `nix run .#kiro-desktop -- --help` and verify CLI help displays
- [x] 11.3 Test GUI launch: `nix run .#kiro-desktop` and verify window opens
- [x] 11.4 Test opening a file: `nix run .#kiro-desktop -- test.js`
- [x] 11.5 Verify AI features work: test code completion, semantic search in UI
- [x] 11.6 Check terminal functionality (uses node-pty addon)
- [x] 11.7 Verify syntax highlighting works for multiple languages (tree-sitter parsers)
- [x] 11.8 Check browser console (F12) for JavaScript errors or missing library warnings

## 12. Library Dependency Verification
- [x] 12.1 Run `ldd result/lib/kiro/kiro` and verify all dependencies resolve (no "not found")
- [x] 12.2 Check bundled libraries: `ldd result/lib/kiro/libffmpeg.so`, verify they load
- [x] 12.3 Test native addons: verify .node files can be loaded by Node.js runtime
- [x] 12.4 Use `readelf -d result/lib/kiro/kiro | grep RPATH` to verify RPATH includes $ORIGIN

## 13. Desktop Environment Testing
- [x] 13.1 Test .desktop file appears in application menu after install
- [x] 13.2 Verify icon displays correctly in application launcher
- [x] 13.3 Test launching from desktop environment (not just command line)
- [x] 13.4 Verify file associations work if MimeType is set

## 14. Flake Integration Verification
- [x] 14.1 Run `nix flake check` and ensure no errors
- [x] 14.2 Run `nix flake show` and verify `packages.x86_64-linux.default` and `packages.x86_64-linux.kiro-desktop` are listed
- [x] 14.3 Test `nix run` without path: `nix run .` should launch kiro (via meta.mainProgram)
- [x] 14.4 Verify package can be installed: `nix profile install .#kiro-desktop`

## 15. Edge Cases and Error Handling
- [x] 15.1 Test on a minimal NixOS system without desktop environment (should fail gracefully with clear error)
- [x] 15.2 Verify Wayland support works (libxkbcommon, wayland libraries)
- [x] 15.3 Test with --no-sandbox flag if chrome-sandbox causes issues
- [x] 15.4 Check behavior when ~/.kiro user data directory doesn't exist (should create)
- [x] 15.5 Test with symlinks: `ln -s result/bin/kiro ~/bin/mykiro` and run, verify it resolves paths correctly

## 16. Documentation and Cleanup
- [x] 16.1 Add inline comments in flake.nix explaining non-obvious decisions
- [x] 16.2 Document any workarounds needed (e.g., --no-sandbox if required)
- [x] 16.3 Add comment about the 720M size and why it's necessary (Electron + AI models)
- [x] 16.4 Note in meta that this requires a graphical environment
- [x] 16.5 Format flake.nix with `nix fmt` or `alejandra`
