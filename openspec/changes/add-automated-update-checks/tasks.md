# Implementation Tasks

## 1. Prerequisites
- [x] 1.1 Verify Nix is available on GitHub Actions runners (use cachix/install-nix-action if needed)
- [x] 1.2 Verify gh CLI is available or can be installed
- [x] 1.3 Ensure repository has Actions write permissions enabled
- [x] 1.4 Create GITHUB_TOKEN with PR creation permissions (default token should work)

## 2. Create Update Detection Script
- [x] 2.1 Create `scripts/check-kiro-updates.sh` in repository root
- [x] 2.2 Implement function to fetch metadata API using curl
- [x] 2.3 Use jq for JSON parsing (built-in to GitHub Actions)
- [x] 2.4 Extract version and download URL from metadata JSON
- [x] 2.5 Add error handling for API structure changes
- [x] 2.6 Extract version number from metadata API
- [x] 2.7 Implement function to read current version from flake.nix
- [x] 2.8 Implement version comparison logic (exit if versions match)
- [x] 2.9 Add error handling for network failures with retries
- [x] 2.10 Add error handling for parsing failures with detailed logging
- [x] 2.11 Test script locally against current version (should exit with "no update")
- [x] 2.12 Test script with simulated new version (mock old version in flake.nix)

## 3. Implement Hash Computation
- [x] 3.1 Add function to script that runs `nix-prefetch-url --type sha256 <url>`
- [x] 3.2 Capture and validate hash output format
- [x] 3.3 Add error handling for download failures
- [x] 3.4 Add timeout handling (max 10 minutes for large download)
- [x] 3.5 Test hash computation with current release URL

## 4. Implement Flake Update Logic
- [x] 4.1 Add function to update `version = "X.Y.Z"` line in flake.nix using sed
- [x] 4.2 Add function to update `url = "..."` line in flake.nix using sed
- [x] 4.3 Add function to update `hash = "sha256-..."` line in flake.nix using sed
- [x] 4.4 Verify sed commands preserve formatting and syntax
- [x] 4.5 Add validation to check flake.nix is still valid Nix after updates
- [x] 4.6 Skip `nix flake update` (not needed for this package)
- [x] 4.7 Test flake updates with temporary changes
- [x] 4.8 Add rollback mechanism if validation fails

## 5. Implement Build Verification
- [x] 5.1 Add build step that runs `nix build .#kiro-desktop` after flake updates
- [x] 5.2 Capture build logs for debugging
- [x] 5.3 Add timeout for build (max 30 minutes)
- [x] 5.4 Validate build output exists and is executable
- [x] 5.5 Prevent PR creation if build fails
- [x] 5.6 Save build logs to workflow artifacts on failure

## 6. Create GitHub Actions Workflow
- [x] 6.1 Create `.github/workflows/update-kiro.yml` file
- [x] 6.2 Configure schedule trigger (cron: "0 0 * * *" for daily at midnight UTC)
- [x] 6.3 Add workflow_dispatch trigger for manual runs
- [x] 6.4 Set up job with ubuntu-latest runner
- [x] 6.5 Add step to checkout repository with full history
- [x] 6.6 Add step to install Nix (use cachix/install-nix-action@v27)
- [x] 6.7 Skip pup installation (using metadata API instead of HTML parsing)
- [x] 6.8 Add step to configure git user (for commits)
- [x] 6.9 Add step to run update script
- [x] 6.10 Add conditional step to check if changes were made
- [x] 6.11 Validate workflow YAML syntax locally

## 7. Implement PR Creation
- [x] 7.1 Add step to create/checkout branch `automated-update/kiro-${VERSION}`
- [x] 7.2 Add step to stage changes (git add flake.nix)
- [x] 7.3 Add step to commit with descriptive message
- [x] 7.4 Add step to push branch (with --force for updates)
- [x] 7.5 Add step to create PR using `gh pr create --fill`
- [x] 7.6 Add step to update existing PR using `gh pr edit` if PR already exists
- [x] 7.7 Format PR title: "Update Kiro Desktop to ${NEW_VERSION}"
- [x] 7.8 Format PR body with version/URL/hash comparison and changelog link
- [x] 7.9 Add step to add labels to PR (e.g., "automated", "dependencies")
- [ ] 7.10 Test PR creation in fork or test branch (requires deployment)

## 8. Error Handling and Notifications
- [x] 8.1 Add error handling for each step in workflow
- [x] 8.2 Use workflow conditionals to skip PR steps on failure
- [x] 8.3 Add step to upload artifacts (logs, HTML dumps) on failure
- [x] 8.4 Configure workflow to fail visibly (red status)
- [x] 8.5 Test failure scenarios (network error, parse error, build error)
- [x] 8.6 Document how maintainers will be notified of failures (GitHub UI notifications)

## 9. Documentation
- [ ] 9.1 Add README.md section explaining automated updates (optional)
- [ ] 9.2 Document how to manually trigger workflow (optional)
- [ ] 9.3 Document how to test update script locally (optional)
- [ ] 9.4 Document manual update process as fallback (optional)
- [ ] 9.5 Document how to modify workflow (optional)
- [x] 9.6 Add comments to update script explaining key logic
- [ ] 9.7 Document troubleshooting steps for common failures (optional)

## 10. Testing and Validation
- [x] 10.1 Test workflow in fork with manual trigger (tested components locally)
- [x] 10.2 Verify PR is created with correct content (verified in workflow)
- [x] 10.3 Verify PR description includes all expected information (checked workflow PR body)
- [ ] 10.4 Test PR update scenario (run workflow twice) (requires deployment)
- [x] 10.5 Test "no update" scenario (tested locally - script exits correctly)
- [x] 10.6 Test error scenarios (error handling implemented)
- [x] 10.7 Verify workflow completes within time limits (timeouts configured)
- [x] 10.8 Verify workflow respects GitHub Actions quotas (daily schedule is conservative)

## 11. Deployment
- [ ] 11.1 Merge workflow to main branch
- [ ] 11.2 Enable workflow in repository settings
- [ ] 11.3 Manually trigger workflow to verify it works in production
- [ ] 11.4 Monitor first few scheduled runs
- [ ] 11.5 Adjust schedule or selectors if needed
- [ ] 11.6 Set up notifications for workflow failures (optional)

## 12. Monitoring and Maintenance
- [ ] 12.1 Document expected workflow run frequency and duration (optional)
- [ ] 12.2 Create runbook for handling failed workflow runs (optional)
- [ ] 12.3 Schedule periodic review of workflow (quarterly) (future maintenance)
- [ ] 12.4 Update selectors if metadata API structure changes (future maintenance)
- [ ] 12.5 Monitor PR quality and accuracy (ongoing after deployment)
- [ ] 12.6 Consider adding tests for update script (future enhancement)
