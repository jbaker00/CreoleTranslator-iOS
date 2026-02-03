# Quick Reference: Merging Pull Requests

## The 3-Step Process

```
┌─────────────────────────────────────────────────────────┐
│  Step 1: Open GitHub & Navigate to PR                  │
│  ↓                                                      │
│  • Go to: github.com/jbaker00/CreoleTranslator-iOS     │
│  • Click: "Pull requests" tab                          │
│  • Select: Your PR                                     │
└─────────────────────────────────────────────────────────┘
                         ↓
┌─────────────────────────────────────────────────────────┐
│  Step 2: Review Status                                  │
│  ↓                                                      │
│  ✅ Reviews approved                                    │
│  ✅ Checks passing                                      │
│  ✅ No conflicts                                        │
└─────────────────────────────────────────────────────────┘
                         ↓
┌─────────────────────────────────────────────────────────┐
│  Step 3: Merge!                                         │
│  ↓                                                      │
│  • Scroll to bottom of PR page                         │
│  • Click: "Merge pull request" (green button)          │
│  • Click: "Confirm merge"                              │
│  • Optional: Click "Delete branch"                     │
└─────────────────────────────────────────────────────────┘
                         ↓
                    ✨ DONE! ✨
```

## Common Commands

### GitHub UI (Recommended)
```
Navigate → Review → Click "Merge pull request" → Confirm
```

### GitHub CLI
```bash
gh pr merge <PR-NUMBER> --merge --delete-branch
```

### Git Command Line
```bash
git checkout main
git merge copilot/your-branch
git push origin main
```

## Merge Options

| Method | Description | Use When |
|--------|-------------|----------|
| **Merge commit** | Creates a merge commit | You want full history |
| **Squash** | Combines all commits into one | PR has many small commits |
| **Rebase** | Replays commits on main | You want linear history |

## Troubleshooting

| Problem | Quick Fix |
|---------|-----------|
| 🔒 Merge button disabled | Check for required reviews or failing checks |
| ⚠️ Conflicts exist | Click "Resolve conflicts" button |
| 🔄 Branch out of date | Click "Update branch" button |
| ❌ Checks failing | Fix issues and push changes |

## Where to Find Things

```
GitHub Repository
├── Code tab ..................... View merged changes here
├── Pull requests tab ............ Find your PR here
│   └── [Your PR]
│       ├── Conversation ......... Comments and status
│       ├── Commits .............. List of commits
│       ├── Checks ............... CI/CD status
│       └── Files changed ........ Code diff
└── Settings
    └── Branches ................. Branch protection rules
```

## Need More Help?

📖 See the full **[GitHub Merge Guide](GITHUB_MERGE_GUIDE.md)** for detailed instructions.

---

## Visual Walkthrough

**Finding Your Pull Request:**
```
GitHub.com → Your Repository → "Pull requests" tab → Select PR
```

**The Merge Button Location:**
```
[Scroll to bottom of PR page]

┌────────────────────────────────────────────┐
│ This branch has no conflicts with the base │
│ branch                                      │
│                                             │
│  [Merge pull request ▼]  [green button]   │
└────────────────────────────────────────────┘
```

**After Clicking Merge:**
```
┌────────────────────────────────────────────┐
│ Merge pull request #123 from               │
│ copilot/your-branch                        │
│                                             │
│ [Commit message field]                     │
│                                             │
│  [Confirm merge]  [green button]          │
└────────────────────────────────────────────┘
```

**Success Screen:**
```
┌────────────────────────────────────────────┐
│ ✓ Pull request successfully merged         │
│   and closed                                │
│                                             │
│ The branch can be deleted.                 │
│                                             │
│  [Delete branch]                           │
└────────────────────────────────────────────┘
```

## Status Indicators

```
✅ All checks have passed
⚠️ Some checks were not successful  
🔄 Some checks are still in progress
❌ Some checks failed
🟢 Approved
🟡 Changes requested
⚪ Review required
```

## Best Practices Checklist

Before merging, ensure:
- [ ] You've reviewed all code changes
- [ ] All tests pass
- [ ] No merge conflicts exist
- [ ] PR description is clear
- [ ] Commit messages are meaningful
- [ ] No sensitive data (API keys, passwords) committed
- [ ] Documentation updated (if needed)

After merging:
- [ ] Delete the branch to keep repo clean
- [ ] Verify changes appear in main branch
- [ ] Pull latest main to your local machine: `git pull origin main`

---

**Remember:** The simplest way is through GitHub UI - it's designed to be user-friendly! 🚀
