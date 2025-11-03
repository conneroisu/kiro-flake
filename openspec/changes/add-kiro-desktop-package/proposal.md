# Add Kiro Desktop Package

## Why
The flake currently lacks a default package implementation (flake.nix:75), preventing users from building or running the Kiro desktop application through standard Nix workflows (`nix build`, `nix run`).

**Kiro Desktop** is an Electron-based IDE developed by AWS, forked from VSCode 1.103.2 with integrated AI capabilities. Version 0.5.0 includes:
- 193M Electron application binary
- 265M AI agent extension with ML models (all-MiniLM-L6-v2), LanceDB vector database, and ONNX runtime
- 94 built-in extensions with language support for 58 languages
- 27 tree-sitter WASM parsers for syntax analysis
- Native Node.js addons for terminal emulation, file watching, and SQLite
- Bundled graphics libraries (libffmpeg, libEGL, libGLESv2, libvulkan, SwiftShader)
- Total size: 244M compressed → 720M extracted

The pre-built distribution requires extensive system dependencies (GTK3, X11, NSS, CUPS, ALSA) and proper binary patching to work on NixOS.

## What Changes
- Add a default Nix package that fetches the Kiro desktop tarball (202510301715 release) with SHA256 verification
- Implement comprehensive dependency injection for 14+ required system libraries (glib, gtk3, cairo, pango, atk, nss, nspr, X11, alsa-lib, cups, mesa, udev, expat, libxkbcommon)
- Use autoPatchelfHook to patch the main Electron binary and all native Node.js addons (.node files)
- Configure wrapper with proper LD_LIBRARY_PATH for bundled libraries while preserving RPATH=$ORIGIN
- Create desktop entry (.desktop file) for application launcher integration
- Install shell completions (bash/zsh) from bundled resources
- Handle chrome-sandbox requirements (either via permissions or --no-sandbox flag)
- Make the package installable as a standalone package (not added to devShell)

## Impact
- Affected specs: `nix-packaging` (new capability)
- Affected code: `flake.nix` (packages.default section)
- Package complexity: High - Electron app with 50+ native addons and ML models
- Build closure size: ~720M + system dependencies
- Users will be able to install and run Kiro desktop via `nix build` and `nix run .#kiro-desktop`
- Desktop integration will allow launching from application menus
- AI features (embeddings, semantic search) will work with proper ONNX runtime support
