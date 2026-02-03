# GitHub Merge Guide - How to Merge Approved Copilot Changes

## Overview

This guide explains how to merge changes that GitHub Copilot made (and you approved during code review) back into your main branch using the GitHub UI.

## Prerequisites

- You have a Pull Request (PR) created by GitHub Copilot
- You've reviewed and approved the changes in the PR
- You have appropriate permissions to merge PRs in the repository

## Step-by-Step: Merging a PR in GitHub UI

### 1. Navigate to the Pull Request

1. Go to your repository on GitHub: `https://github.com/jbaker00/CreoleTranslator-iOS`
2. Click on the **"Pull requests"** tab near the top of the page
3. Find and click on the PR that contains the Copilot changes you approved

### 2. Review the PR Status

Before merging, check the following:

- ✅ **Review Status**: Shows "Approved" (green checkmark)
- ✅ **Checks Passing**: All CI/CD checks have passed (if configured)
- ✅ **No Conflicts**: The branch has no merge conflicts with the base branch
- ✅ **Up to Date**: The branch is up to date with the base branch (or can be merged)

### 3. Merge the Pull Request

Once everything looks good, you have three merge options:

#### Option A: Merge Commit (Default - Recommended)
1. Scroll down to the bottom of the PR page
2. Click the green **"Merge pull request"** button
3. Optionally edit the commit message
4. Click **"Confirm merge"**
5. The PR will be merged and closed automatically

**Result**: Creates a merge commit that preserves the full history of changes.

#### Option B: Squash and Merge
1. Click the dropdown arrow next to the "Merge pull request" button
2. Select **"Squash and merge"**
3. Edit the commit message if needed (combines all commits into one)
4. Click **"Confirm squash and merge"**

**Result**: Combines all commits from the PR into a single commit on the main branch.

#### Option C: Rebase and Merge
1. Click the dropdown arrow next to the "Merge pull request" button
2. Select **"Rebase and merge"**
3. Click **"Confirm rebase and merge"**

**Result**: Replays the commits from the PR onto the main branch without a merge commit.

### 4. Delete the Branch (Optional)

After merging:
1. GitHub will prompt you with **"Delete branch"** button
2. Click it to clean up the feature branch (recommended for completed features)
3. You can always restore it later if needed

### 5. Verify the Merge

1. Go to the **"Code"** tab of your repository
2. Check that your changes are now in the main branch
3. Verify the commit history shows your merged changes

## Common Scenarios

### Scenario 1: Merge Conflicts

If you see "This branch has conflicts that must be resolved":

1. Click **"Resolve conflicts"** button
2. GitHub will open an online editor showing the conflicting files
3. Edit the files to resolve conflicts (remove conflict markers `<<<<<<<`, `=======`, `>>>>>>>`)
4. Click **"Mark as resolved"** for each file
5. Click **"Commit merge"**
6. Now you can merge the PR as normal

**Alternative**: Resolve conflicts locally using git:
```bash
git checkout main
git pull origin main
git checkout copilot/your-feature-branch
git merge main
# Resolve conflicts in your editor
git add .
git commit -m "Resolve merge conflicts"
git push origin copilot/your-feature-branch
```

### Scenario 2: Checks Must Pass First

If required checks are still running or failed:

1. Wait for checks to complete (if still running)
2. If checks failed, click on the failed check to see details
3. Fix any issues in your branch
4. Push the fixes - checks will re-run automatically
5. Once checks pass, the merge button will be enabled

### Scenario 3: Required Reviews

If you see "Review required" and can't merge:

1. Request a review from a team member (if you can't approve your own PR)
2. Or check repository settings to adjust protection rules
3. Repository Settings → Branches → Branch protection rules
4. Note: In personal repositories, you typically can merge your own PRs

### Scenario 4: Branch Not Up to Date

If you see "This branch is out-of-date with the base branch":

1. Click **"Update branch"** button (easiest method)
2. This merges the latest changes from main into your PR branch
3. Wait for any checks to re-run
4. Then merge as normal

## Using GitHub CLI (Alternative Method)

If you prefer the command line:

```bash
# Install GitHub CLI (if not already installed)
# https://cli.github.com/

# Authenticate
gh auth login

# List open pull requests
gh pr list

# View a specific PR
gh pr view <PR-NUMBER>

# Merge a PR (after approval)
gh pr merge <PR-NUMBER> --merge  # Create merge commit
gh pr merge <PR-NUMBER> --squash # Squash and merge
gh pr merge <PR-NUMBER> --rebase # Rebase and merge

# Merge and delete branch
gh pr merge <PR-NUMBER> --merge --delete-branch
```

## Using Git Commands (Local Merge)

If you need to merge locally without GitHub UI:

```bash
# Make sure you're on the main branch
git checkout main

# Pull latest changes
git pull origin main

# Merge the Copilot branch
git merge copilot/your-feature-branch

# Push to GitHub
git push origin main

# Delete the feature branch (optional)
git branch -d copilot/your-feature-branch
git push origin --delete copilot/your-feature-branch
```

## Troubleshooting

### "Merge button is disabled"

**Possible reasons:**
- Required reviews not completed → Request/complete reviews
- Required checks are failing → Fix issues and push changes
- Branch protection rules → Check repository settings
- No write access → Contact repository admin

### "Branch has conflicts"

**Solution:**
1. Use the GitHub UI conflict resolver (easy)
2. Or merge main into your branch locally (see Scenario 1 above)

### "Can't find my PR"

**Check:**
- Look in the "Pull requests" tab
- Check if it's already closed/merged (filter by status)
- Verify you're in the correct repository
- Search by PR number or branch name

### "Already merged but changes not showing"

**Possible causes:**
- Cache: Hard refresh the page (Ctrl+Shift+R or Cmd+Shift+R)
- Wrong branch: Make sure you're viewing the main branch
- Different repository: Verify you're in the right repo

## Best Practices

1. **Always review changes before merging** - Even if tests pass, manually review the code
2. **Keep PRs small and focused** - Easier to review and less likely to have conflicts
3. **Update your branch regularly** - Keep feature branches in sync with main
4. **Write clear commit messages** - Future you will thank you
5. **Delete merged branches** - Keeps repository clean and organized
6. **Use protected branches** - Set up branch protection on main to require reviews

## Quick Reference

| Action | Location | Button Text |
|--------|----------|-------------|
| View PRs | Repository → Pull requests tab | - |
| Merge PR | PR page bottom | "Merge pull request" |
| Resolve conflicts | PR page | "Resolve conflicts" |
| Update branch | PR page | "Update branch" |
| Delete branch | After merge | "Delete branch" |
| Approve PR | PR page → Files changed tab | "Review changes" → "Approve" |

## Additional Resources

- [GitHub Docs: Merging a pull request](https://docs.github.com/en/pull-requests/collaborating-with-pull-requests/incorporating-changes-from-a-pull-request/merging-a-pull-request)
- [GitHub Docs: About pull request merges](https://docs.github.com/en/pull-requests/collaborating-with-pull-requests/incorporating-changes-from-a-pull-request/about-pull-request-merges)
- [GitHub Docs: Resolving merge conflicts](https://docs.github.com/en/pull-requests/collaborating-with-pull-requests/addressing-merge-conflicts)

## Summary

**The simplest workflow:**
1. Open your repository on GitHub
2. Go to "Pull requests" tab
3. Click on your PR
4. Scroll to the bottom
5. Click the green "Merge pull request" button
6. Click "Confirm merge"
7. Click "Delete branch" (optional but recommended)
8. Done! Your changes are now in main ✅

---

Need help? Check the [GitHub Community](https://github.community/) or open an issue in this repository.
