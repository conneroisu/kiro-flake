# Implementation Tasks

## 1. Prerequisites
- [ ] 1.1 Verify Nix is available on GitHub Actions runners (use cachix/install-nix-action if needed)
- [ ] 1.2 Verify gh CLI is available or can be installed
- [ ] 1.3 Ensure repository has Actions write permissions enabled
- [ ] 1.4 Create GITHUB_TOKEN with PR creation permissions (default token should work)

## 2. Create Update Detection Script
- [ ] 2.1 Create `scripts/check-kiro-updates.sh` in repository root
- [ ] 2.2 Implement function to fetch https://kiro.dev/downloads/ using curl
- [ ] 2.3 Install and use `pup` tool for HTML parsing (add to workflow dependencies)
- [ ] 2.4 Implement CSS selector to extract Linux x64 download URL from downloads page
- [ ] 2.5 Implement fallback selectors in case HTML structure changes
- [ ] 2.6 Extract version number from URL or fetch from https://kiro.dev/changelog/
- [ ] 2.7 Implement function to read current version from flake.nix
- [ ] 2.8 Implement version comparison logic (exit if versions match)
- [ ] 2.9 Add error handling for network failures with retries
- [ ] 2.10 Add error handling for parsing failures with detailed logging
- [ ] 2.11 Test script locally against current version (should exit with "no update")
- [ ] 2.12 Test script with simulated new version (mock old version in flake.nix)

## 3. Implement Hash Computation
- [ ] 3.1 Add function to script that runs `nix-prefetch-url --type sha256 <url>`
- [ ] 3.2 Capture and validate hash output format
- [ ] 3.3 Add error handling for download failures
- [ ] 3.4 Add timeout handling (max 10 minutes for large download)
- [ ] 3.5 Test hash computation with current release URL

## 4. Implement Flake Update Logic
- [ ] 4.1 Add function to update `version = "X.Y.Z"` line in flake.nix using sed
- [ ] 4.2 Add function to update `url = "..."` line in flake.nix using sed
- [ ] 4.3 Add function to update `hash = "sha256-..."` line in flake.nix using sed
- [ ] 4.4 Verify sed commands preserve formatting and syntax
- [ ] 4.5 Add validation to check flake.nix is still valid Nix after updates
- [ ] 4.6 Run `nix flake update` to update flake.lock
- [ ] 4.7 Test flake updates with temporary changes
- [ ] 4.8 Add rollback mechanism if validation fails

## 5. Implement Build Verification
- [ ] 5.1 Add build step that runs `nix build .#kiro-desktop` after flake updates
- [ ] 5.2 Capture build logs for debugging
- [ ] 5.3 Add timeout for build (max 30 minutes)
- [ ] 5.4 Validate build output exists and is executable
- [ ] 5.5 Prevent PR creation if build fails
- [ ] 5.6 Save build logs to workflow artifacts on failure

## 6. Create GitHub Actions Workflow
- [ ] 6.1 Create `.github/workflows/update-kiro.yml` file
- [ ] 6.2 Configure schedule trigger (cron: "0 12 * * *" for daily at noon UTC)
- [ ] 6.3 Add workflow_dispatch trigger for manual runs
- [ ] 6.4 Set up job with ubuntu-latest runner
- [ ] 6.5 Add step to checkout repository with full history
- [ ] 6.6 Add step to install Nix (use cachix/install-nix-action@v27)
- [ ] 6.7 Add step to install pup (via nix-shell or direct download)
- [ ] 6.8 Add step to configure git user (for commits)
- [ ] 6.9 Add step to run update script
- [ ] 6.10 Add conditional step to check if changes were made
- [ ] 6.11 Validate workflow YAML syntax locally

## 7. Implement PR Creation
- [ ] 7.1 Add step to create/checkout branch `automated-update/kiro-${VERSION}`
- [ ] 7.2 Add step to stage changes (git add flake.nix flake.lock)
- [ ] 7.3 Add step to commit with descriptive message
- [ ] 7.4 Add step to push branch (with --force for updates)
- [ ] 7.5 Add step to create PR using `gh pr create --fill`
- [ ] 7.6 Add step to update existing PR using `gh pr edit` if PR already exists
- [ ] 7.7 Format PR title: "Update Kiro Desktop to ${NEW_VERSION}"
- [ ] 7.8 Format PR body with version/URL/hash comparison and changelog link
- [ ] 7.9 Add step to add labels to PR (e.g., "automated", "dependencies")
- [ ] 7.10 Test PR creation in fork or test branch

## 8. Error Handling and Notifications
- [ ] 8.1 Add error handling for each step in workflow
- [ ] 8.2 Use workflow conditionals to skip PR steps on failure
- [ ] 8.3 Add step to upload artifacts (logs, HTML dumps) on failure
- [ ] 8.4 Configure workflow to fail visibly (red status)
- [ ] 8.5 Test failure scenarios (network error, parse error, build error)
- [ ] 8.6 Document how maintainers will be notified of failures

## 9. Documentation
- [ ] 9.1 Add README.md section explaining automated updates
- [ ] 9.2 Document how to manually trigger workflow
- [ ] 9.3 Document how to test update script locally
- [ ] 9.4 Document manual update process as fallback
- [ ] 9.5 Document how to modify workflow (e.g., change schedule)
- [ ] 9.6 Add comments to update script explaining key logic
- [ ] 9.7 Document troubleshooting steps for common failures

## 10. Testing and Validation
- [ ] 10.1 Test workflow in fork with manual trigger
- [ ] 10.2 Verify PR is created with correct content
- [ ] 10.3 Verify PR description includes all expected information
- [ ] 10.4 Test PR update scenario (run workflow twice)
- [ ] 10.5 Test "no update" scenario (current version is latest)
- [ ] 10.6 Test error scenarios (disconnect network, break HTML parsing)
- [ ] 10.7 Verify workflow completes within time limits
- [ ] 10.8 Verify workflow respects GitHub Actions quotas

## 11. Deployment
- [ ] 11.1 Merge workflow to main branch
- [ ] 11.2 Enable workflow in repository settings
- [ ] 11.3 Manually trigger workflow to verify it works in production
- [ ] 11.4 Monitor first few scheduled runs
- [ ] 11.5 Adjust schedule or selectors if needed
- [ ] 11.6 Set up notifications for workflow failures (optional)

## 12. Monitoring and Maintenance
- [ ] 12.1 Document expected workflow run frequency and duration
- [ ] 12.2 Create runbook for handling failed workflow runs
- [ ] 12.3 Schedule periodic review of workflow (quarterly)
- [ ] 12.4 Update selectors if kiro.dev HTML structure changes
- [ ] 12.5 Monitor PR quality and accuracy
- [ ] 12.6 Consider adding tests for update script
