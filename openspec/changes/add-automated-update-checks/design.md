# Automated Update Checks - Design Document

## Context

Kiro Desktop releases are published to https://prod.download.desktop.kiro.dev/releases/ with a timestamp-based URL structure. The current release (0.5.0) uses the URL pattern:
```
https://prod.download.desktop.kiro.dev/releases/202510301715--distro-linux-x64-tar-gz/202510301715-distro-linux-x64.tar.gz
```

Where `202510301715` is a timestamp (2025-10-30 at 17:15).

### Current State
- No GitHub Releases API available
- Release directory listing returns 403 Forbidden
- **Metadata API endpoint available** at `https://prod.download.desktop.kiro.dev/stable/metadata-linux-x64-stable.json`
- Metadata includes version number, download URL, and publication date
- Manual process: discover new version → update flake.nix → recalculate hash → commit

### Stakeholders
- Package maintainers who need to keep Kiro Desktop current
- End users who benefit from timely updates

## Goals / Non-Goals

### Goals
- Automatically detect new Kiro Desktop releases daily
- Automatically update flake.nix with new version, URL, and hash
- Create PRs for human review before merging
- Handle failures gracefully (network issues, parsing errors, etc.)
- Minimize external dependencies

### Non-Goals
- Auto-merging without human approval (security concern)
- Supporting multiple platforms in one PR (focus on Linux x64 initially)
- Detecting pre-releases or beta versions
- Rollback mechanisms (handled via git revert)
- Complex version constraint checking

## Decisions

### Decision 1: Update Detection Method
**Choice:** Fetch JSON metadata from official API endpoint

**Rationale:**
- Official API endpoint at `https://prod.download.desktop.kiro.dev/stable/metadata-linux-x64-stable.json`
- Provides structured JSON with version, URL, and publication date
- More reliable than HTML scraping (won't break on UI changes)
- No client-side rendering issues (pure JSON, no JavaScript required)
- Same endpoint used by Kiro's auto-update mechanism

**API Response Format:**
```json
{
  "currentRelease": "0.5.9",
  "releases": [
    {
      "version": "0.5.9",
      "updateTo": {
        "version": "0.5.9",
        "pub_date": "2025-11-03",
        "url": "https://prod.download.desktop.kiro.dev/releases/202511032205--distro-linux-x64-tar-gz/202511032205-distro-linux-x64.tar.gz"
      }
    }
  ]
}
```

**Extraction Command:**
```bash
# Get latest version
VERSION=$(curl -sL "$METADATA_URL" | jq -r '.currentRelease')

# Get download URL
URL=$(curl -sL "$METADATA_URL" | jq -r '.releases[0].updateTo | select(.url | contains(".tar.gz")) | .url')
```

**Alternatives considered:**
1. **Scrape kiro.dev/downloads** - Fails due to client-side rendering (Next.js)
2. **Headless browser** - Works but too complex and resource-intensive
3. **Try sequential timestamps** - Too brittle, would fail frequently
4. **Email notifications from Kiro** - Requires manual setup, not automatable
5. **RSS feed** - Not available on kiro.dev

### Decision 2: Workflow Frequency
**Choice:** Run daily at 00:00 UTC (midnight)

**Rationale:**
- Balances freshness with API rate limits
- Midnight UTC is off-peak for most users
- GitHub Actions free tier: 2000 minutes/month (each run ~5 min = 400 runs/month)
- Aligns with typical software release schedules
- Detects updates within 24 hours of publication

**Alternatives considered:**
1. **Hourly** - Wasteful, releases are infrequent
2. **Weekly** - Too slow, misses updates for days
3. **On webhook** - No webhook available from kiro.dev

### Decision 3: JSON Parsing Approach
**Choice:** Use `jq` for JSON parsing and extraction

**Rationale:**
- Built-in to most GitHub Actions runners
- Robust, well-tested tool for JSON manipulation
- Supports complex queries and filtering
- Available in nixpkgs (jq v1.7.1)
- No HTML parsing brittleness

**Example:**
```bash
# Fetch and parse metadata
METADATA_URL="https://prod.download.desktop.kiro.dev/stable/metadata-linux-x64-stable.json"
VERSION=$(curl -sL "$METADATA_URL" | jq -r '.currentRelease')
URL=$(curl -sL "$METADATA_URL" | jq -r '.releases[0].updateTo | select(.url | contains(".tar.gz")) | .url')
```

**Alternatives considered:**
1. **Python + json module** - Heavier runtime, extra dependency
2. **Bash parameter expansion** - Less robust for nested JSON
3. **yq** - Designed for YAML, overkill for simple JSON

### Decision 4: PR Creation Strategy
**Choice:** Use gh CLI to create or update a single PR

**Rationale:**
- gh CLI is maintained by GitHub, well-supported
- Can update existing PRs (avoids spam)
- Supports branch reuse
- Simple authentication via GITHUB_TOKEN

**Implementation:**
```bash
BRANCH="automated-update/kiro-${NEW_VERSION}"
git checkout -b "$BRANCH" || git checkout "$BRANCH"
git add flake.nix flake.lock
git commit -m "Update Kiro Desktop to ${NEW_VERSION}"
git push origin "$BRANCH" --force
gh pr create --fill || gh pr edit --body "Updated to ${NEW_VERSION}"
```

**Alternatives considered:**
1. **Create new PR each time** - Spammy, clutters PR list
2. **Direct push to main** - Unsafe, bypasses review
3. **GitHub API directly** - More complex than gh CLI

### Decision 5: Hash Calculation
**Choice:** Use nix-prefetch-url in the workflow

**Rationale:**
- Official Nix tool for this purpose
- Automatically validates download
- Produces correct hash format for flake.nix
- Works offline with cached results

**Command:**
```bash
nix-prefetch-url --type sha256 "$NEW_URL"
```

**Alternatives considered:**
1. **Download + sha256sum** - Manual, error-prone
2. **nix-hash** - Requires download first
3. **Trust upstream checksums** - Not provided by kiro.dev

### Decision 6: Flake Update Method
**Choice:** Use sed for surgical flake.nix edits

**Rationale:**
- Simple, available everywhere
- Preserves file formatting
- Minimal risk of corruption
- Easy to verify in PR diff

**Implementation:**
```bash
sed -i "s|version = \".*\"|version = \"${NEW_VERSION}\"|" flake.nix
sed -i "s|url = \"https://prod.download.*\"|url = \"${NEW_URL}\"|" flake.nix
sed -i "s|hash = \"sha256-.*\"|hash = \"${NEW_HASH}\"|" flake.nix
```

**Alternatives considered:**
1. **nix-update tool** - Not in nixpkgs, external dependency
2. **JSON/TOML config** - Would require restructuring flake
3. **Template rendering** - Overkill for 3 values
4. **Tree-sitter AST editing** - Too complex

### Decision 7: Stale PR Management
**Choice:** Close PRs automatically after 30 days of inactivity

**Rationale:**
- Prevents accumulation of outdated update PRs
- 30 days provides ample time for review
- Workflow can create new PR when maintainer is ready
- Keeps PR list clean and focused

**Implementation:**
- Use GitHub Actions' `actions/stale` or manual check in workflow
- Add "stale" label after 23 days, close after 30 days
- Comment explaining closure and how to recreate

**Alternatives considered:**
1. **Never close** - Leads to PR clutter
2. **7 days** - Too aggressive, may close before review
3. **Manual closure** - Requires maintainer action
4. **Supersede instead of close** - More complex, same outcome

## Risks / Trade-offs

### Risk 1: API Endpoint Changes
**Impact:** Medium - Workflow breaks if metadata API changes or moves

**Mitigation:**
- API is official update mechanism, unlikely to change frequently
- Validate JSON structure before parsing (check for required fields)
- Alert on parsing failures with clear error messages
- Include manual fallback instructions in workflow
- Test endpoint accessibility before processing

**Trade-off:** Dependency on external API, but much more stable than HTML scraping

### Risk 2: Hash Mismatch
**Impact:** Critical - Breaks builds if hash is wrong

**Mitigation:**
- Workflow includes test build step: `nix build .#kiro-desktop`
- PR checks must pass before merge
- Manual review of PR required

**Trade-off:** Longer workflow time for safety

### Risk 3: False Positives
**Impact:** Low - Creates unnecessary PRs

**Mitigation:**
- Compare current version before creating PR
- Skip if version unchanged
- Close stale PRs automatically after 7 days

**Trade-off:** Accepts occasional false positives for reliability

### Risk 4: Rate Limiting
**Impact:** Low - GitHub API rate limits

**Mitigation:**
- Daily schedule is well within limits
- Use GITHUB_TOKEN (5000 requests/hour)
- Exponential backoff on failures

**Trade-off:** None significant

## Migration Plan

### Phase 1: Implementation (Week 1)
1. Create update-check script
2. Test script locally with current version
3. Create GitHub Actions workflow
4. Test workflow in fork or test branch
5. Deploy to main repository

### Phase 2: Monitoring (Week 2-4)
1. Watch for false positives
2. Verify PR quality
3. Monitor API endpoint stability
4. Document manual override process

### Phase 3: Maintenance (Ongoing)
1. Review PRs within 48 hours
2. Monitor workflow failures
3. Update workflow if API structure changes

### Rollback
If the automation causes issues:
1. Disable workflow via GitHub UI (no code change needed)
2. Delete automation branch
3. Resume manual updates

## Open Questions

1. **Q: Should we update flake.lock automatically?**
   - **A:** No. Keep changes minimal and focused.
   - **Reason:** The kiro-desktop package has no flake inputs of its own
   - **Decision:** Only update flake.nix; leave flake.lock for manual updates

2. **Q: Should we support multiple release channels (stable, beta)?**
   - **A:** Not initially. Focus on stable channel only.
   - **Future:** Could add workflow_dispatch input to select channel
   - **Note:** Beta endpoint would be `/beta/metadata-linux-x64-beta.json`

3. **Q: What if download URL becomes unavailable?**
   - **A:** Workflow fails, no PR created. Manual intervention required.
   - **Future:** Could cache previous releases or retry later

4. **Q: Should we auto-merge if tests pass?**
   - **A:** No. Always require human review for security and correctness.
   - **Reason:** Binary packages need verification beyond automated tests

5. **Q: How to handle version downgrades (if they occur)?**
   - **A:** Skip update if new version is older than current version
   - **Implementation:** Use semantic version comparison, not string comparison
   - **Fallback:** Log warning and exit without creating PR
