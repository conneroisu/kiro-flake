# Implementation Tasks

## 1. Source Preparation
- [ ] 1.1 Calculate SHA256 hash for tarball using `nix-prefetch-url https://prod.download.desktop.kiro.dev/releases/202510301715--distro-linux-x64-tar-gz/202510301715-distro-linux-x64.tar.gz`
- [ ] 1.2 Document the hash value in comments for future updates

## 2. Package Definition and Metadata
- [ ] 2.1 Define `kiro-desktop` package in flake.nix under `packages.kiro-desktop` using `pkgs.stdenv.mkDerivation`
- [ ] 2.2 Set `pname = "kiro-desktop"`
- [ ] 2.3 Set `version = "0.5.0"` (from investigation: Kiro version 0.5.0)
- [ ] 2.4 Create `src` using `pkgs.fetchurl` with the tarball URL and calculated hash
- [ ] 2.5 Set `meta.description = "Kiro Desktop - AWS Electron-based IDE with AI (VSCode fork)"`
- [ ] 2.6 Set `meta.homepage = "https://kiro.dev"`
- [ ] 2.7 Set `meta.platforms = [ "x86_64-linux" ]`
- [ ] 2.8 Set `meta.mainProgram = "kiro"` for `nix run` support
- [ ] 2.9 Add `meta.license` with AWS-IPL information
- [ ] 2.10 Assign to `packages.default = packages.kiro-desktop`

## 3. System Dependencies Declaration
- [ ] 3.1 Add to `nativeBuildInputs`: autoPatchelfHook, makeWrapper, copyDesktopItems (or makeDesktopItem)
- [ ] 3.2 Add core graphics to `buildInputs`: glib, gtk3, cairo, pango, atk, at-spi2-atk
- [ ] 3.3 Add X11/display to `buildInputs`: xorg.libX11, xorg.libXcomposite, xorg.libXdamage, xorg.libXext, xorg.libXfixes, xorg.libXrandr, libxcb, libxkbcommon
- [ ] 3.4 Add Mozilla libs to `buildInputs`: nspr, nss
- [ ] 3.5 Add device/system to `buildInputs`: cups, mesa (for libgbm), systemd (for libudev), alsa-lib, dbus, expat
- [ ] 3.6 Add optional dependencies: libsecret, krb5 (for kerberos.node addon)

## 4. Unpack Phase
- [ ] 4.1 Set `sourceRoot = "."` since tarball extracts to `Kiro/` directory
- [ ] 4.2 Verify tarball extraction creates expected structure: kiro binary, resources/, locales/, bin/kiro

## 5. Install Phase - Main Structure
- [ ] 5.1 Create `$out/lib/kiro` directory for main installation
- [ ] 5.2 Copy main `kiro` binary (193M Electron executable) to `$out/lib/kiro/kiro`
- [ ] 5.3 Copy all bundled .so files to `$out/lib/kiro/`: libffmpeg.so, libEGL.so, libGLESv2.so, libvulkan.so.1, libvk_swiftshader.so
- [ ] 5.4 Copy all support files: chrome-sandbox, chrome_crashpad_handler, icudtl.dat, snapshot_blob.bin, v8_context_snapshot.bin, *.pak files, vk_swiftshader_icd.json
- [ ] 5.5 Copy `locales/` directory with all 58 locale .pak files to `$out/lib/kiro/locales/`
- [ ] 5.6 Copy entire `resources/` directory (436M with 94 extensions, AI models, node_modules) to `$out/lib/kiro/resources/`
- [ ] 5.7 Verify native .node addons are preserved: resources/app/node_modules/{node-pty,native-keymap,@vscode/sqlite3,@parcel/watcher}/build/Release/*.node
- [ ] 5.8 Verify kiro-agent extension files: resources/app/extensions/kiro.kiro-agent/ with index.node (57M), models/, node_modules/

## 6. Binary Patching with autoPatchelfHook
- [ ] 6.1 Allow autoPatchelfHook to run automatically on main `kiro` binary
- [ ] 6.2 Set `dontAutoPatchelf = false` (or omit, default behavior)
- [ ] 6.3 Use `preFixup` hook to manually patch any .node files missed by autoPatchelfHook using `find $out -name '*.node' -exec patchelf ... \;`
- [ ] 6.4 Verify chrome_crashpad_handler and chrome-sandbox are patched
- [ ] 6.5 Test that RPATH includes both Nix paths and `$ORIGIN` for bundled libraries

## 7. Wrapper Script Creation
- [ ] 7.1 Create wrapper at `$out/bin/kiro` using `makeWrapper`
- [ ] 7.2 Wrap `$out/lib/kiro/kiro` as the main executable
- [ ] 7.3 Set `--prefix LD_LIBRARY_PATH : "$out/lib/kiro"` for bundled libraries
- [ ] 7.4 Set `--set ELECTRON_RUN_AS_NODE 1` for CLI mode
- [ ] 7.5 Add `--add-flags "$out/lib/kiro/resources/app/out/cli.js"` to execute CLI entry point
- [ ] 7.6 Consider adding `--add-flags "--no-sandbox"` if chrome-sandbox setup is complex (test without first)
- [ ] 7.7 Test wrapper passes through CLI arguments correctly: `kiro --help`, `kiro file.txt`

## 8. Desktop Integration
- [ ] 8.1 Create `.desktop` file content with: Name=Kiro, Comment=AWS AI-powered IDE, Exec=kiro %U, Icon=kiro, Type=Application, Categories=Development;IDE;TextEditor;
- [ ] 8.2 Add MimeType entries for common code file types
- [ ] 8.3 Install .desktop file to `$out/share/applications/kiro.desktop`
- [ ] 8.4 Extract or create icon from resources (check resources/app for .png/.svg icons)
- [ ] 8.5 Install icon to `$out/share/icons/hicolor/*/apps/kiro.png` (multiple resolutions if available)
- [ ] 8.6 Run `gtk-update-icon-cache` in postInstall if needed

## 9. Shell Completions Installation
- [ ] 9.1 Install bash completion: `cp $sourceRoot/Kiro/resources/completions/bash/kiro $out/share/bash-completion/completions/kiro`
- [ ] 9.2 Create `$out/share/bash-completion/completions/` directory before copying
- [ ] 9.3 Install zsh completion: `cp $sourceRoot/Kiro/resources/completions/zsh/_kiro $out/share/zsh/site-functions/_kiro`
- [ ] 9.4 Create `$out/share/zsh/site-functions/` directory before copying

## 10. Build Testing
- [ ] 10.1 Run `nix build .#kiro-desktop` and verify it completes without errors
- [ ] 10.2 Check build output size is ~720M + dependencies
- [ ] 10.3 Verify `result/bin/kiro` exists and is executable
- [ ] 10.4 Check `result/lib/kiro/` contains all expected files

## 11. Runtime Testing
- [ ] 11.1 Run `nix run .#kiro-desktop -- --version` and verify output shows version 0.5.0
- [ ] 11.2 Run `nix run .#kiro-desktop -- --help` and verify CLI help displays
- [ ] 11.3 Test GUI launch: `nix run .#kiro-desktop` and verify window opens
- [ ] 11.4 Test opening a file: `nix run .#kiro-desktop -- test.js`
- [ ] 11.5 Verify AI features work: test code completion, semantic search in UI
- [ ] 11.6 Check terminal functionality (uses node-pty addon)
- [ ] 11.7 Verify syntax highlighting works for multiple languages (tree-sitter parsers)
- [ ] 11.8 Check browser console (F12) for JavaScript errors or missing library warnings

## 12. Library Dependency Verification
- [ ] 12.1 Run `ldd result/lib/kiro/kiro` and verify all dependencies resolve (no "not found")
- [ ] 12.2 Check bundled libraries: `ldd result/lib/kiro/libffmpeg.so`, verify they load
- [ ] 12.3 Test native addons: verify .node files can be loaded by Node.js runtime
- [ ] 12.4 Use `readelf -d result/lib/kiro/kiro | grep RPATH` to verify RPATH includes $ORIGIN

## 13. Desktop Environment Testing
- [ ] 13.1 Test .desktop file appears in application menu after install
- [ ] 13.2 Verify icon displays correctly in application launcher
- [ ] 13.3 Test launching from desktop environment (not just command line)
- [ ] 13.4 Verify file associations work if MimeType is set

## 14. Flake Integration Verification
- [ ] 14.1 Run `nix flake check` and ensure no errors
- [ ] 14.2 Run `nix flake show` and verify `packages.x86_64-linux.default` and `packages.x86_64-linux.kiro-desktop` are listed
- [ ] 14.3 Test `nix run` without path: `nix run .` should launch kiro (via meta.mainProgram)
- [ ] 14.4 Verify package can be installed: `nix profile install .#kiro-desktop`

## 15. Edge Cases and Error Handling
- [ ] 15.1 Test on a minimal NixOS system without desktop environment (should fail gracefully with clear error)
- [ ] 15.2 Verify Wayland support works (libxkbcommon, wayland libraries)
- [ ] 15.3 Test with --no-sandbox flag if chrome-sandbox causes issues
- [ ] 15.4 Check behavior when ~/.kiro user data directory doesn't exist (should create)
- [ ] 15.5 Test with symlinks: `ln -s result/bin/kiro ~/bin/mykiro` and run, verify it resolves paths correctly

## 16. Documentation and Cleanup
- [ ] 16.1 Add inline comments in flake.nix explaining non-obvious decisions
- [ ] 16.2 Document any workarounds needed (e.g., --no-sandbox if required)
- [ ] 16.3 Add comment about the 720M size and why it's necessary (Electron + AI models)
- [ ] 16.4 Note in meta that this requires a graphical environment
- [ ] 16.5 Format flake.nix with `nix fmt` or `alejandra`
