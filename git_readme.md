# SkyTrails Git Workflow

This document outlines the Git branching strategy and workflow for the SkyTrails project. Following these guidelines will help us work in parallel and maintain a clean and understandable commit history.

## Branching Model

We will use a simple branching model with the following branches:

-   `main`: This branch represents the production-ready code. Direct commits to `main` are not allowed. Merges to `main` will be done from the `develop` branch after thorough testing.
-   `develop`: This is the main development branch. All feature branches are created from `develop` and merged back into it. This branch should always be in a state where it can be deployed to a staging environment.
-   `feature/<feature-name>`: These branches are for developing new features. Each developer will work on a separate feature branch.

## Workflow

### 1. Creating a Feature Branch

Before starting work on a new feature, make sure your local `develop` branch is up-to-date:

```bash
# Switch to the develop branch
git switch develop

# Pull the latest changes from the remote repository
git pull origin develop
```

Then, create a new feature branch from `develop`:

```bash
# Create and switch to a new feature branch
git switch -c feature/<your-feature-name>
```

Replace `<your-feature-name>` with a short, descriptive name for your feature (e.g., `feature/user-authentication`).

### 2. Working on Your Feature

Commit your changes to your feature branch. Make small, atomic commits with clear and concise commit messages.

```bash
# Stage your changes
git add .

# Commit your changes
git commit -m "feat: Add user login screen"
```

### 3. Keeping Your Feature Branch Up-to-Date

While you are working on your feature, the `develop` branch may be updated with other developers' changes. To incorporate these changes into your feature branch and avoid complex merge conflicts later, you should regularly rebase your branch on `develop`.

```bash
# Switch to the develop branch
git switch develop

# Pull the latest changes
git pull origin develop

# Switch back to your feature branch
git switch feature/<your-feature-name>

# Rebase your feature branch on top of develop
git rebase develop
```

This will replay your commits on top of the latest `develop` branch. You may need to resolve conflicts during the rebase process.

### 4. Merging Your Feature Branch

Once your feature is complete and tested, you can merge it into the `develop` branch.

First, make sure your feature branch is up-to-date with `develop` by rebasing (see step 3).

Then, switch to the `develop` branch and merge your feature branch:

```bash
# Switch to the develop branch
git switch develop

# Merge your feature branch
git merge --no-ff feature/<your-feature-name>
```

The `--no-ff` flag creates a merge commit, which helps to group the feature's commits together in the history.

Finally, push the `develop` branch to the remote repository:

```bash
git push origin develop
```

And delete your local feature branch:
```bash
git branch -d feature/<your-feature-name>
```

## Useful Git Commands

-   `git switch <branch-name>`: Switch to an existing branch.
-   `git switch -c <branch-name>`: Create and switch to a new branch.
-   `git checkout <branch-name>`: An older command to switch branches. `git switch` is preferred.
-   `git pull`: Fetch changes from the remote repository and merge them into your current branch.
-   `git push`: Push your committed changes to the remote repository.
-   `git rebase <branch-name>`: Re-apply commits from your current branch onto another branch.
-   `git status`: Show the working tree status.
-   `git log`: Show the commit history.

By following this workflow, we can ensure a clean and linear project history, making it easier to track changes and collaborate effectively.
