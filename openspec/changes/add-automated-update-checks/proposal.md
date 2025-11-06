# Add Automated Update Checks

## Why

The Kiro Desktop package currently requires manual monitoring of the kiro.dev website to discover new releases, followed by manual updates to the flake.nix file (URL, version, and SHA256 hash). This creates friction and delays in keeping the package up-to-date. An automated daily check would ensure the package stays current with minimal manual intervention.

## What Changes

- Add a GitHub Action workflow that runs daily (00:00 UTC) to check for Kiro Desktop updates
- Create a script to fetch metadata from the official API endpoint at `https://prod.download.desktop.kiro.dev/stable/metadata-linux-x64-stable.json`
- Parse JSON metadata using jq to extract version number and download URL
- Automatically compute the new SHA256 hash using nix-prefetch-url
- Update flake.nix with the new version, URL, and hash
- Perform build verification and smoke tests (--version, --help) before creating PR
- Create or update a pull request with the changes
- Automatically close stale PRs after 30 days of inactivity
- Include automated commit messages that document what version was updated

## Impact

- Affected specs:
  - `nix-packaging` (MODIFIED - update check mechanism)
  - `auto-update` (ADDED - new capability)
- Affected code:
  - `.github/workflows/` - new workflow file for daily update checks
  - New script for update detection and flake modification
  - `flake.nix` - will be automatically updated by the workflow
- Dependencies:
  - GitHub Actions runners with Nix installed (via cachix/install-nix-action)
  - curl for fetching JSON metadata
  - jq for JSON parsing (built-in to GitHub Actions runners)
  - nix-prefetch-url for hash computation
  - Git for committing changes
  - gh CLI for creating/updating PRs (built-in to GitHub Actions)
