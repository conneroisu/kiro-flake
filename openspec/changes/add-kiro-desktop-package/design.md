# Kiro Desktop Packaging Design

## Context

Kiro Desktop is a large, complex Electron-based application (720M extracted) with:
- Pre-built binary distribution (not built from source)
- 50+ native Node.js addons (.node files)
- Bundled graphics libraries (libffmpeg, Vulkan, OpenGL ES)
- Machine learning models and ONNX runtime
- Extensive system library dependencies (GTK3, X11, NSS, etc.)

This differs from typical Nix packages that build from source. The challenge is adapting a pre-built, self-contained Linux distribution to work within Nix's philosophy while preserving functionality.

**Key Constraints:**
- Cannot rebuild from source (pre-built binary only)
- Must preserve RPATH=$ORIGIN for bundled libraries
- Native addons must find their dependencies
- 720M size is non-negotiable (includes AI models and 94 extensions)
- Targets NixOS and Nix on Linux systems

## Goals / Non-Goals

### Goals
1. Create a working Nix package that runs Kiro Desktop successfully
2. Preserve all functionality including AI features, terminal, syntax highlighting
3. Enable standard Nix workflows: `nix build`, `nix run`, `nix profile install`
4. Integrate with desktop environments (launcher, icon, file associations)
5. Maintain security through proper library path management

### Non-Goals
1. Building from source (upstream doesn't provide build instructions)
2. Splitting into modular sub-packages (would break native addon paths)
3. Reducing size below 720M (extensions and models are essential)
4. Supporting non-x86_64 architectures (tarball is x64-only)
5. Supporting macOS or Windows (Linux-specific tarball)

## Decisions

### Decision 1: Use autoPatchelfHook + Manual Patching Hybrid

**Choice:** Use `autoPatchelfHook` for automatic binary patching, with manual `patchelf` in `preFixup` for any .node files that are missed.

**Why:**
- autoPatchelfHook handles the 193M main binary and helper executables automatically
- Reduces boilerplate compared to manual patchelf for every binary
- Manual patching ensures .node files deep in node_modules are covered
- Preserves RPATH=$ORIGIN which is critical for bundled libraries

**Alternatives Considered:**
1. **Pure manual patchelf:** Too verbose, error-prone for 50+ addons
2. **FHS environment (buildFHSUserEnv):** Cleaner isolation but:
   - Adds wrapper complexity
   - Doesn't integrate as cleanly with desktop environments
   - Harder to debug library issues
3. **Steam's approach (heavy FHS wrapper):** Overkill for a single Electron app

**Implementation:**
```nix
nativeBuildInputs = [ autoPatchelfHook makeWrapper ];
preFixup = ''
  find $out -name '*.node' -exec patchelf --set-rpath ... {} \;
'';
```

### Decision 2: Install to $out/lib/kiro with Wrapper in $out/bin

**Choice:** Main installation in `$out/lib/kiro/`, wrapper script at `$out/bin/kiro`

**Why:**
- Mirrors upstream's structure (app in lib, wrapper in bin)
- Preserves relative paths used by the original bin/kiro wrapper
- Allows RPATH=$ORIGIN to find libraries in same directory
- Standard location for large GUI applications in Nix (e.g., vscode, chromium)

**Path Layout:**
```
$out/
├── bin/
│   └── kiro                           # Wrapper created by makeWrapper
├── lib/
│   └── kiro/
│       ├── kiro                       # Main Electron binary
│       ├── libffmpeg.so, libEGL.so... # Bundled libraries
│       ├── resources/                 # 436M of app data
│       └── locales/                   # Locale files
└── share/
    ├── applications/kiro.desktop
    ├── icons/
    └── {bash-completion,zsh}/
```

### Decision 3: Comprehensive System Dependencies List

**Choice:** Include all 14+ system libraries identified by `ldd` analysis in `buildInputs`.

**Why:**
- Electron depends on GTK3 stack for UI rendering
- X11 libraries required for display connection
- NSS/NSPR needed for Chromium's crypto stack
- CUPS, ALSA, udev required for hardware access
- Missing any causes runtime crashes or degraded functionality

**Categories:**
1. **Graphics:** glib, gtk3, cairo, pango, atk, at-spi2-atk
2. **Display:** xorg.* (X11, Xcomposite, Xdamage, Xext, Xfixes, Xrandr), libxcb, libxkbcommon
3. **Security:** nspr, nss
4. **Hardware:** cups, mesa (libgbm), systemd (libudev), alsa-lib, dbus, expat
5. **Optional:** libsecret (credential storage), krb5 (Kerberos auth)

### Decision 4: Wrapper Configuration with LD_LIBRARY_PATH

**Choice:** Use `makeWrapper` to set `LD_LIBRARY_PATH=$out/lib/kiro` and configure Electron execution.

**Why:**
- Bundled libraries (libffmpeg, libvulkan) must be found at runtime
- RPATH=$ORIGIN handles co-located libraries, but wrapper ensures discoverability
- Electron requires specific environment variables (ELECTRON_RUN_AS_NODE)
- CLI entry point (resources/app/out/cli.js) must be passed as argument

**Wrapper Flags:**
```nix
makeWrapper $out/lib/kiro/kiro $out/bin/kiro \
  --prefix LD_LIBRARY_PATH : "$out/lib/kiro" \
  --set ELECTRON_RUN_AS_NODE 1 \
  --add-flags "$out/lib/kiro/resources/app/out/cli.js"
```

**Alternative:** Direct symlink to binary
- **Rejected:** Loses ability to set environment variables and pass CLI flags

### Decision 5: Handle chrome-sandbox with --no-sandbox Fallback

**Choice:** Initially attempt to run with sandbox, add `--no-sandbox` as wrapper flag if needed.

**Why:**
- chrome-sandbox requires setuid bit in traditional Linux
- Nix cannot set setuid in store (immutable, multi-user security)
- Modern Electron can run with `--no-sandbox` for single-user scenarios
- User namespaces may provide sandboxing without setuid

**Security Trade-off:**
- Sandboxed: Better isolation, more secure (preferred)
- No-sandbox: Reduced isolation, but still runs in Nix user context
- Decision: Test without flag first, add if necessary during implementation

**Implementation:**
```nix
# Try without flag first:
makeWrapper ... $out/bin/kiro

# If tests fail with sandbox errors:
makeWrapper ... $out/bin/kiro --add-flags "--no-sandbox"
```

### Decision 6: Desktop Integration via Standard FreeDesktop Spec

**Choice:** Create `.desktop` file manually and install icon from resources.

**Why:**
- Standard approach for GUI applications on Linux
- Integrates with GNOME, KDE, XFCE launchers
- Allows file association via MimeType declarations
- Icon extraction from resources ensures branding consistency

**Desktop Entry:**
```ini
[Desktop Entry]
Name=Kiro
Comment=AWS AI-powered IDE (VSCode fork)
Exec=kiro %U
Icon=kiro
Type=Application
Categories=Development;IDE;TextEditor;
MimeType=text/plain;text/x-source;
StartupWMClass=Kiro
```

### Decision 7: Preserve Entire Directory Structure

**Choice:** Copy the complete extracted tarball structure to `$out/lib/kiro/` without reorganization.

**Why:**
- Native addons use relative paths to find models and data files
- Electron expects specific resource layout (resources/app/, locales/)
- Tree-sitter parsers referenced by relative paths in extensions
- AI models loaded from `extensions/kiro.kiro-agent/models/`
- Any restructuring risks breaking internal path resolution

**Risk of Reorganization:**
- Native .node addons may fail to load
- ML model loading could fail
- Extension activation errors
- Subtle runtime failures in specific features

## Risks / Trade-offs

### Risk: Large Closure Size
- **Impact:** ~720M package + dependency closure (~200-300M)
- **Mitigation:** Document size in meta, accept as necessary for Electron + AI
- **Trade-off:** Functionality vs. size (choosing functionality)

### Risk: Binary Patching May Miss Native Addons
- **Impact:** Some .node files might not get patched, causing load failures
- **Mitigation:** Comprehensive `find` in preFixup, test all major features
- **Detection:** Runtime testing will reveal missing patches (error logs)

### Risk: chrome-sandbox Security Model
- **Impact:** May need --no-sandbox, reducing isolation
- **Mitigation:** Run as non-root user, Nix store immutability provides some protection
- **Trade-off:** Sandboxing vs. compatibility (may need to choose compatibility)

### Risk: Bundled Library Conflicts
- **Impact:** Bundled libffmpeg/libvulkan might conflict with system libraries
- **Mitigation:** RPATH=$ORIGIN and LD_LIBRARY_PATH precedence ensures bundled libs are found first
- **Trade-off:** Bundled (controlled) vs. system (possibly newer/patched)

### Risk: AI Features Dependency on Native Addons
- **Impact:** If LanceDB (index.node 57M) or ONNX runtime fails to patch, AI features break
- **Mitigation:** Thorough testing of semantic search, embeddings, code completion
- **Detection:** Test plan includes explicit AI feature testing

### Risk: Future Tarball Updates
- **Impact:** URL/hash hardcoded, new releases require manual update
- **Mitigation:** Document update process in comments, include version in pname
- **Enhancement Opportunity:** Could script update checking or use updateScript in meta

## Migration Plan

N/A - This is a new package addition, not a migration.

## Implementation Phases

1. **Phase 1 - Basic Package:** Fetch, extract, install structure (tasks 1-5)
2. **Phase 2 - Binary Patching:** autoPatchelfHook + manual patching (task 6)
3. **Phase 3 - Wrapper & Environment:** Create wrapper with proper env (task 7)
4. **Phase 4 - Desktop Integration:** .desktop file, icons, completions (tasks 8-9)
5. **Phase 5 - Testing:** Build, runtime, library checks (tasks 10-15)
6. **Phase 6 - Polish:** Documentation, cleanup, formatting (task 16)

Each phase should result in a buildable (though possibly non-functional) package until Phase 3.

## Open Questions

1. **Icon Extraction:** Where exactly is the icon in resources/? May need to explore during implementation.
   - Check: `resources/app/resources/linux/` or `resources/app/out/vs/code/electron-sandbox/`

2. **Setuid Alternative:** Can we use kernel.unprivileged_userns_clone for sandboxing?
   - Test: Try running without --no-sandbox on NixOS with userns enabled

3. **Wayland Support:** Does Electron 37 + bundled libs support Wayland natively?
   - Test: Run on Wayland compositor, check for XWayland vs. native

4. **Multiple Version Support:** Should we support multiple Kiro versions simultaneously?
   - Decision: No for initial implementation, but version in pname allows future multi-version support

5. **ONNX Runtime .so:** Are ONNX shared libraries (libonnxruntime.so.1.14.0) properly located?
   - Test: Check if onnxruntime_binding.node finds its .so, may need additional LD_LIBRARY_PATH entries

## Success Criteria

Implementation is successful when:

1. ✅ `nix build` completes without errors
2. ✅ `nix run` launches Kiro GUI
3. ✅ All ldd dependencies resolve (no "not found")
4. ✅ Terminal emulation works (node-pty addon)
5. ✅ Syntax highlighting works for multiple languages (tree-sitter)
6. ✅ AI features work: code completion, semantic search (LanceDB + ONNX)
7. ✅ Desktop launcher shows Kiro with icon
8. ✅ Shell completions available for bash/zsh
9. ✅ No JavaScript errors in browser console (F12)
10. ✅ Can open and edit files successfully

## References

- [Nix Pills - Packaging Electron Apps](https://nixos.wiki/wiki/Electron)
- [autoPatchelfHook Documentation](https://nixos.org/manual/nixpkgs/stable/#setup-hook-autopatchelfhook)
- [VSCode Nix Package](https://github.com/NixOS/nixpkgs/blob/master/pkgs/applications/editors/vscode/vscode.nix) - Similar Electron app
- [Packaging Pre-built Binaries](https://nixos.wiki/wiki/Packaging/Binaries)
- Kiro tarball investigation report (from research phase)
