#!/bin/bash
set -e

# draft_release_notes.sh logic
if [ ! -f "RELEASE_DRAFT.md" ]; then
  echo "Draft missing. Fetching logs for auto-generation..."
  # Note: The actual generation of Chinese notes needs an LLM or manual agent step if not fully automated.
  # For this script, we assume the Agent/User has ensured the draft exists or we generate a placeholder/raw log.
  # Since the previous workflow relied on the Agent to "intelligently summarize", purely automated script might lack that.
  # However, for "turbo-all" automation, we can dump the log. 
  # Ideally, this script is run BY the agent or user after they are satisfied with a draft, OR we automate the log dump.
  # Let's retain the log dump behavior from the workflow for now.
  
  echo "## vMain" > RELEASE_DRAFT.md
  echo "" >> RELEASE_DRAFT.md
  echo "### Changes" >> RELEASE_DRAFT.md
  git log $(git describe --tags --abbrev=0)..HEAD --no-merges --pretty=format:"- %s" >> RELEASE_DRAFT.md
  
  echo "⚠️  Created raw RELEASE_DRAFT.md. Please review it before re-running if you want manual edits."
  # We don't exit here to allow fully automated flows if desired, but typically one wants to review notes.
  # But the user asked for "fully automated". Let's proceed.
else
  echo "Draft found. Proceeding."
fi

# Select release type
if [ -n "$1" ]; then
  case $1 in
    major|minor|patch)
      type=$1
      echo "Release type set to '$type' via argument."
      ;;
    *)
      echo "Error: Invalid argument '$1'. Usage: ./release_workflow.sh [major|minor|patch]"
      exit 1
      ;;
  esac
else
  echo "Select release type:"
  echo "1) patch (default)"
  echo "2) minor"
  echo "3) major"
  read -p "Enter choice (1-3): " choice

  case $choice in
      2) type="minor" ;;
      3) type="major" ;;
      *) type="patch" ;;
  esac
fi

# Record old version for comparison
old_full=$(grep 'version:' pubspec.yaml | awk '{print $2}')
old_build=$(echo "$old_full" | cut -d'+' -f2)

# bump_version logic
echo "Bumping version ($type)..."
python3 scripts/bump_version.py --type $type

# Extract new version (full and semver-only)
full_version=$(grep 'version:' pubspec.yaml | awk '{print $2}')
version=$(echo "$full_version" | cut -d'+' -f1)
new_build=$(echo "$full_version" | cut -d'+' -f2)

echo "New version: $full_version (semver=$version, build=$new_build)"

# Verify build number was actually incremented
if [ "$new_build" = "$old_build" ] || [ -z "$new_build" ]; then
  echo "❌ ERROR: Build number was NOT incremented! old=$old_build new=$new_build"
  echo "   pubspec.yaml version must be MAJOR.MINOR.PATCH+BUILD with BUILD always incrementing."
  exit 1
fi
echo "✅ Build number verified: $old_build -> $new_build"

# Sync notes
if [ -f "RELEASE_DRAFT.md" ]; then
  echo "Syncing version header..."
  if [[ "$OSTYPE" == "darwin"* ]]; then
    sed -i '' "1s/^## v.*/## v$version/" RELEASE_DRAFT.md
  else
    sed -i "1s/^## v.*/## v$version/" RELEASE_DRAFT.md
  fi

  echo "Updating history..."
  echo -e "\n" | cat - release_notes.md > history_tmp.md
  cat RELEASE_DRAFT.md history_tmp.md > release_notes.md
  rm history_tmp.md
fi

# Commit and Push
echo "Committing and pushing..."
git add .
if [ -f "RELEASE_DRAFT.md" ]; then
  git reset HEAD RELEASE_DRAFT.md
fi
git commit -m "chore: release v$version"
git tag -a "v$version" -m "Release v$version"
git push
git push --tags

# Publish release shell; macOS/Windows builds are attached by GitHub Actions
echo "Publishing release to GitHub (CI will attach macOS and Windows builds)..."
if [ -f "RELEASE_DRAFT.md" ]; then
  if gh release view "v$version" >/dev/null 2>&1; then
    gh release edit "v$version" --title "v$version" --notes-file RELEASE_DRAFT.md
  else
    gh release create "v$version" --title "v$version" --notes-file RELEASE_DRAFT.md
  fi
  rm RELEASE_DRAFT.md
  echo "Release published. Check Actions for build progress:"
  echo "  https://github.com/lovelyJason/mcp-switch/actions"
else
  echo "❌ Error: RELEASE_DRAFT.md missing at publish stage."
  exit 1
fi
