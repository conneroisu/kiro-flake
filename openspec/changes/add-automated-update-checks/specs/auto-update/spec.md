# auto-update Specification Delta

## ADDED Requirements

### Requirement: Automated Update Detection
The system SHALL detect new Kiro Desktop releases by fetching metadata from the official API endpoint daily.

#### Scenario: Latest version is detected from metadata API
- **WHEN** the update check workflow runs
- **THEN** it fetches https://prod.download.desktop.kiro.dev/stable/metadata-linux-x64-stable.json
- **AND** parses the JSON response using jq
- **AND** extracts the `currentRelease` field for the version number
- **AND** extracts the download URL from `releases[0].updateTo.url` (filtering for .tar.gz)
- **AND** compares the detected version with the current version in flake.nix

#### Scenario: Metadata API returns valid JSON
- **WHEN** the metadata API is fetched
- **THEN** the response is valid JSON
- **AND** contains the required fields: `currentRelease` and `releases` array
- **AND** the first release contains `updateTo.url` pointing to a .tar.gz file
- **AND** the URL format matches `https://prod.download.desktop.kiro.dev/releases/*-distro-linux-x64.tar.gz`

#### Scenario: Download URL is accessible
- **WHEN** a download URL is extracted from metadata
- **THEN** the system verifies the URL returns HTTP 200
- **AND** the response has a Content-Type indicating a tarball
- **AND** the Content-Length is reasonable (>100MB, <2GB)

#### Scenario: Version comparison determines update needed
- **WHEN** a new version is detected that differs from flake.nix
- **THEN** the system uses semantic version comparison (not string comparison)
- **AND** proceeds with the update workflow if new version > current version
- **AND** when the version matches or is older than current version
- **THEN** the workflow logs the status and exits without creating a PR

#### Scenario: Metadata API is unreachable
- **WHEN** the metadata API request fails with network error
- **THEN** the workflow retries up to 3 times with exponential backoff (2s, 4s, 8s)
- **AND** logs the error with HTTP status code if available
- **AND** exits without creating a PR if all retries fail
- **AND** marks the workflow run as failed for notification

### Requirement: Automated Hash Computation
The system SHALL automatically compute the SHA256 hash of new release tarballs using Nix tools.

#### Scenario: Hash is computed using nix-prefetch-url
- **WHEN** a new release URL is detected
- **THEN** the system runs `nix-prefetch-url --type sha256 <url>`
- **AND** captures the output hash in the format expected by flake.nix
- **AND** verifies the hash is a valid SHA256 string

#### Scenario: Hash computation failures are handled
- **WHEN** nix-prefetch-url fails (network error, invalid URL, etc.)
- **THEN** the workflow logs the error with context
- **AND** exits without creating a PR
- **AND** sends a notification about the failure

### Requirement: Automated Flake Updates
The system SHALL update flake.nix with new version, URL, and hash information automatically.

#### Scenario: Version field is updated
- **WHEN** a new version is detected
- **THEN** the system updates the `version = "X.Y.Z"` line in flake.nix
- **AND** preserves the surrounding code formatting
- **AND** uses the exact version string from the detected release

#### Scenario: URL field is updated
- **WHEN** a new download URL is detected
- **THEN** the system updates the `url = "..."` line in pkgs.fetchurl
- **AND** preserves the indentation and syntax
- **AND** includes the complete URL with timestamp

#### Scenario: Hash field is updated
- **WHEN** a new hash is computed
- **THEN** the system updates the `hash = "sha256-..."` line
- **AND** uses the correct hash format (sha256- prefix)
- **AND** preserves the quote style and formatting


### Requirement: GitHub Actions Workflow
The system SHALL use a GitHub Actions workflow that runs on a daily schedule to check for updates.

#### Scenario: Workflow runs daily at midnight UTC
- **WHEN** the schedule triggers (daily at 00:00 UTC)
- **THEN** the workflow starts on a GitHub Actions runner
- **AND** uses a runner with Nix pre-installed or installs Nix via cachix/install-nix-action
- **AND** completes within the GitHub Actions timeout (60 minutes max)

#### Scenario: Workflow can be manually triggered
- **WHEN** a maintainer manually triggers the workflow via GitHub UI
- **THEN** the workflow runs immediately
- **AND** follows the same process as the scheduled run
- **AND** creates a PR if updates are found

#### Scenario: Workflow uses minimal resources
- **WHEN** the workflow runs
- **THEN** it completes in under 10 minutes on average
- **AND** uses less than 2GB of disk space
- **AND** stays within GitHub Actions free tier limits

### Requirement: Pull Request Creation
The system SHALL create or update a pull request with the package updates for human review.

#### Scenario: New PR is created for first update
- **WHEN** an update is detected and no PR exists
- **THEN** the system creates a new branch named `automated-update/kiro-<version>`
- **AND** commits the flake.nix changes with a descriptive message
- **AND** pushes the branch to origin
- **AND** creates a PR using gh CLI with a descriptive title
- **AND** includes version change, download URL, and hash in the PR body

#### Scenario: Existing PR is updated for subsequent updates
- **WHEN** an update is detected and a PR already exists
- **THEN** the system force-pushes to the existing branch
- **AND** updates the PR body with the new version information
- **AND** adds a comment indicating the PR was auto-updated
- **AND** does not create duplicate PRs

#### Scenario: PR includes verification build
- **WHEN** a PR is created or updated
- **THEN** the workflow includes a test build step (`nix build .#kiro-desktop`)
- **AND** the build must succeed before the PR is created
- **AND** build failures prevent PR creation and log the error

#### Scenario: PR description is informative
- **WHEN** a PR is generated
- **THEN** the PR title includes the version (e.g., "Update Kiro Desktop to 0.6.0")
- **AND** the PR body includes:
  - Old version → New version
  - Old URL → New URL
  - Old hash → New hash
  - Link to Kiro changelog
  - Build test results
- **AND** the PR body includes instructions for manual verification

### Requirement: Error Handling and Notifications
The system SHALL handle failures gracefully and notify maintainers of issues.

#### Scenario: Network failures are logged
- **WHEN** fetching the downloads page fails
- **THEN** the workflow logs the HTTP error code and message
- **AND** retries up to 3 times with exponential backoff
- **AND** exits without creating a PR if all retries fail

#### Scenario: Parse failures are logged
- **WHEN** HTML parsing fails to extract the download URL
- **THEN** the workflow logs the parse error with context
- **AND** saves the fetched HTML to workflow artifacts for debugging
- **AND** exits without creating a PR

#### Scenario: Build failures prevent PR creation
- **WHEN** the test build fails after updating flake.nix
- **THEN** the workflow logs the build error
- **AND** does not create or update a PR
- **AND** saves build logs to workflow artifacts
- **AND** includes the error in the workflow summary

#### Scenario: Workflow failures are visible
- **WHEN** any step in the workflow fails
- **THEN** the GitHub Actions run shows as failed (red)
- **AND** the failure appears in the Actions tab
- **AND** repository admins receive email notifications (if configured)

### Requirement: Script Maintainability
The update detection script SHALL be maintainable, testable, and documented.

#### Scenario: Script is modular
- **WHEN** examining the update script
- **THEN** it has separate functions for:
  - Fetching and parsing the downloads page
  - Extracting version numbers
  - Computing hashes
  - Updating flake files
  - Creating PRs
- **AND** each function has a single responsibility
- **AND** functions can be tested independently

#### Scenario: Script has clear error messages
- **WHEN** the script encounters an error
- **THEN** the error message indicates which step failed
- **AND** includes relevant context (URL, version, etc.)
- **AND** suggests possible remediation steps

#### Scenario: Script is documented
- **WHEN** reading the script file
- **THEN** it includes a header comment explaining its purpose
- **AND** complex logic includes inline comments
- **AND** the README or comments explain how to test locally
- **AND** includes examples of manual override procedures

### Requirement: Rate Limiting and API Protection
The system SHALL respect API rate limits and implement appropriate throttling to avoid overwhelming the metadata endpoint.

#### Scenario: Workflow respects GitHub API rate limits
- **WHEN** the workflow uses GitHub API (gh CLI) for PR operations
- **THEN** it uses GITHUB_TOKEN which has 5000 requests/hour limit
- **AND** the workflow completes within 10 API calls per run
- **AND** stays well below rate limits with daily execution

#### Scenario: Metadata API requests are throttled
- **WHEN** fetching the metadata API endpoint
- **THEN** the workflow only makes one request per run
- **AND** implements a 1-second delay before retry attempts
- **AND** does not hammer the endpoint on failures

#### Scenario: Network errors trigger exponential backoff
- **WHEN** a network request fails
- **THEN** the system waits 2 seconds before first retry
- **AND** waits 4 seconds before second retry
- **AND** waits 8 seconds before third retry
- **AND** gives up after 3 failed attempts

### Requirement: Concurrent Execution Protection
The system SHALL prevent multiple workflow instances from running simultaneously to avoid race conditions.

#### Scenario: Only one workflow instance runs at a time
- **WHEN** the workflow is triggered (scheduled or manual)
- **THEN** GitHub Actions concurrency controls ensure only one instance runs
- **AND** if a workflow is already running, new triggers wait in queue
- **AND** the concurrency group is set to prevent conflicts

#### Scenario: Workflow handles concurrent PR updates safely
- **WHEN** updating an existing PR branch
- **THEN** the workflow uses force-push to overwrite previous changes
- **AND** checks for branch existence before creating new branch
- **AND** handles conflicts by aborting and logging error

### Requirement: Authentication and Permissions
The system SHALL use appropriate GitHub authentication with minimal required permissions.

#### Scenario: Workflow uses GITHUB_TOKEN
- **WHEN** the workflow runs
- **THEN** it authenticates using the automatic GITHUB_TOKEN
- **AND** the token has permissions for: contents:write, pull-requests:write, workflows:read
- **AND** the token is scoped to the repository only

#### Scenario: Authentication failures are handled
- **WHEN** GitHub authentication fails (invalid or expired token)
- **THEN** the workflow logs a clear error message
- **AND** exits with non-zero status
- **AND** does not expose token in logs
- **AND** marks the run as failed for notification

#### Scenario: Permissions are validated
- **WHEN** the workflow attempts to create a PR
- **THEN** it verifies gh CLI can authenticate
- **AND** fails early if permissions are insufficient
- **AND** provides clear error message about missing permissions

### Requirement: Stale PR Management
The system SHALL automatically close stale update PRs to keep the repository clean.

#### Scenario: PRs are marked stale after inactivity
- **WHEN** an automated update PR has no activity for 23 days
- **THEN** the workflow adds a "stale" label to the PR
- **AND** adds a comment explaining the PR will be closed soon
- **AND** provides instructions to keep PR open or recreate it

#### Scenario: Stale PRs are closed automatically
- **WHEN** a PR marked as stale has no activity for 7 more days (30 days total)
- **THEN** the workflow closes the PR with a comment
- **AND** explains that a new PR will be created if update is still needed
- **AND** does not delete the branch immediately (allows manual recovery)

#### Scenario: PR activity prevents stale closure
- **WHEN** a stale PR receives any comment or commit
- **THEN** the "stale" label is removed
- **AND** the 30-day timer resets
- **AND** the PR is treated as active again

### Requirement: Validation Beyond Build
The system SHALL perform smoke tests on the built package to verify it works beyond compilation.

#### Scenario: Built package is executable
- **WHEN** the test build completes successfully
- **THEN** the workflow verifies `result/bin/kiro` exists
- **AND** verifies the binary has execute permissions
- **AND** verifies the binary is not empty (size > 1KB)

#### Scenario: Package responds to version query
- **WHEN** the built package is tested
- **THEN** the workflow runs `result/bin/kiro --version`
- **AND** captures the output
- **AND** verifies the output contains the expected version number
- **AND** verifies the command exits with status code 0

#### Scenario: Package responds to help query
- **WHEN** the built package is tested
- **THEN** the workflow runs `result/bin/kiro --help`
- **AND** verifies the command exits with status code 0
- **AND** verifies the output contains usage information

#### Scenario: Smoke test failures prevent PR creation
- **WHEN** any smoke test fails
- **THEN** the workflow logs the failure with command output
- **AND** does not create or update a PR
- **AND** marks the workflow run as failed
- **AND** saves test output to workflow artifacts
