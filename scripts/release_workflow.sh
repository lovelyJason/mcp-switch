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

# bump_version logic
echo "Bumping version ($type)..."
python3 scripts/bump_version.py --type $type

# Extract new version
version=$(grep 'version:' pubspec.yaml | awk '{print $2}' | cut -d'+' -f1)
echo "New version: $version"

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

# Build
echo "Building macOS app..."
flutter clean && flutter build macos --release

# Zip
echo "Creating ZIP archive..."
cd build/macos/Build/Products/Release
rm -f *.zip
# Re-read version to be safe or reuse variable
zip_name="MCP_Switch_macOS_v${version}.zip"
zip -r "$zip_name" "MCP Switch.app"
cd -

# Publish
echo "Publishing to GitHub..."
zip_path="build/macos/Build/Products/Release/MCP_Switch_macOS_v${version}.zip"

if [ -f "RELEASE_DRAFT.md" ]; then
  gh release create "v$version" "$zip_path" --title "v$version" --notes-file RELEASE_DRAFT.md
  rm RELEASE_DRAFT.md
  echo "Release published successfully!"
else
  echo "❌ Error: RELEASE_DRAFT.md missing at publish stage."
  exit 1
fi
