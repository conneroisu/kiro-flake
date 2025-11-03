# kiro-flake

A Nix flake providing the [Kiro Desktop IDE](https://kiro.dev) - an AWS AI-powered IDE based on VSCode.

## Prerequisites

- **Nix package manager** installed (with or without flakes enabled)
- **Linux x86_64 system** (currently supported platform)
- **Graphical environment** (X11/Wayland)

## Installation

### With Flakes Enabled (Recommended)

If you have Nix flakes enabled (Nix 2.4+), you can use the modern flake commands.

#### Try without installing

```bash
nix run github:conneroisu/kiro-flake
```

#### Install to your profile

```bash
nix profile install github:conneroisu/kiro-flake
```

#### Add to NixOS configuration

In your `flake.nix`:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    kiro-flake.url = "github:conneroisu/kiro-flake";
  };

  outputs = { self, nixpkgs, kiro-flake, ... }: {
    nixosConfigurations.yourhostname = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        {
          environment.systemPackages = [
            kiro-flake.packages.x86_64-linux.kiro-desktop
          ];
        }
      ];
    };
  };
}
```

#### Add to home-manager

In your home-manager configuration:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    home-manager.url = "github:nix-community/home-manager";
    kiro-flake.url = "github:conneroisu/kiro-flake";
  };

  outputs = { nixpkgs, home-manager, kiro-flake, ... }: {
    homeConfigurations.yourusername = home-manager.lib.homeManagerConfiguration {
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
      modules = [
        {
          home.packages = [
            kiro-flake.packages.x86_64-linux.kiro-desktop
          ];
        }
      ];
    };
  };
}
```

### Without Flakes (Traditional Nix)

If you don't have flakes enabled or prefer the traditional Nix approach:

#### Using nix-env

```bash
# Install directly from GitHub
nix-env -iA packages.x86_64-linux.kiro-desktop -f https://github.com/conneroisu/kiro-flake/archive/main.tar.gz
```

#### Using nix-shell (temporary environment)

```bash
# Enter a shell with kiro-desktop available
nix-shell -p '(import (builtins.fetchTarball "https://github.com/conneroisu/kiro-flake/archive/main.tar.gz") {}).packages.x86_64-linux.kiro-desktop'
```

#### Add to NixOS configuration (channels)

In your `/etc/nixos/configuration.nix`:

```nix
{ config, pkgs, ... }:

let
  kiro-flake = import (builtins.fetchTarball {
    url = "https://github.com/conneroisu/kiro-flake/archive/main.tar.gz";
  });
in
{
  environment.systemPackages = [
    (kiro-flake.packages.x86_64-linux.kiro-desktop)
  ];
}
```

## Development

### With Flakes Enabled

Enter the development environment:

```bash
nix develop github:conneroisu/kiro-flake
```

Or for local development:

```bash
git clone https://github.com/conneroisu/kiro-flake.git
cd kiro-flake
nix develop
```

### Without Flakes

```bash
git clone https://github.com/conneroisu/kiro-flake.git
cd kiro-flake
nix-shell
```

### Available Development Tools

The development shell includes:

- **alejandra** - Nix code formatter
- **nixd** - Nix language server
- **statix** - Nix linter
- **deadnix** - Find and remove dead Nix code
- **dx** - Script to edit flake.nix

### Formatting

Format Nix code:

```bash
# With flakes
nix fmt

# Without flakes (in nix-shell)
alejandra .
```

## Available Packages

This flake provides the following packages:

- **kiro-desktop** (default) - The Kiro Desktop IDE application

## Usage

After installation, launch Kiro Desktop:

```bash
kiro
```

Or use it with files:

```bash
kiro /path/to/your/project
```

## Package Details

- **Version**: 0.5.0
- **Size**: ~720MB extracted
- **Platform**: x86_64-linux only
- **License**: AWS-IPL (unfree)

The package includes:
- Kiro Electron application
- Bundled graphics libraries (OpenGL, Vulkan)
- Localization files (58 locales)
- AI models and extensions
- Shell completions (bash, zsh)

## Enabling Nix Flakes

If you don't have flakes enabled, you can enable them by adding to your Nix configuration:

### On NixOS

In `/etc/nixos/configuration.nix`:

```nix
{
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
}
```

Then rebuild:

```bash
sudo nixos-rebuild switch
```

### On non-NixOS systems

In `~/.config/nix/nix.conf` or `/etc/nix/nix.conf`:

```
experimental-features = nix-command flakes
```

## Troubleshooting

### Missing libraries

If you encounter missing library errors, ensure your system has the necessary graphics drivers installed. Kiro Desktop requires:
- OpenGL support
- X11 or Wayland display server

### Permission issues

The `chrome-sandbox` binary requires proper permissions. This is handled automatically by the package.

## Contributing

Contributions are welcome! Please feel free to submit issues or pull requests.

## License

This flake is provided as-is. Kiro Desktop itself is distributed under the AWS-IPL license (unfree).

## Links

- [Kiro Desktop Homepage](https://kiro.dev)
- [Official Downloads](https://prod.download.desktop.kiro.dev/)
