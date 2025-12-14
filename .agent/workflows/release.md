---
description: Build Release version and Publish to GitHub
---

1. Bump Version and Sync Notes
   # Auto-bump version
   python3 scripts/bump_version.py
   
   # Extract new version
   version=$(grep 'version:' pubspec.yaml | awk '{print $2}' | cut -d'+' -f1)
   
   # Handle Release Notes
   if [ -f "RELEASE_DRAFT.md" ]; then
     echo "Found draft notes. Updating history..."
     # Prepend new notes to history (release_notes.md)
     echo -e "\n" | cat - release_notes.md > history_tmp.md
     cat RELEASE_DRAFT.md history_tmp.md > release_notes.md
     rm history_tmp.md
   fi
   
   # Commit and Push
   # 1. Add ALL changes (including user code and history)
   git add .
   # 2. Unstage the draft file (never commit it)
   if [ -f "RELEASE_DRAFT.md" ]; then
     git reset HEAD RELEASE_DRAFT.md
   fi
   # 3. Commit and Push
   git commit -m "chore: release v$version"
   git push

2. Build the macOS App
   flutter clean && flutter build macos --release

3. Create the distribution Zip archives
   cd build/macos/Build/Products/Release
   rm -f *.zip
   zip -r MCPSwitch-macOS.zip "MCP Switch.app"
   cd -

4. Publish to GitHub
   version=$(grep 'version:' pubspec.yaml | awk '{print $2}' | cut -d'+' -f1)
   
   if [ -f "RELEASE_DRAFT.md" ]; then
     # Use the draft notes for the GitHub Release body
     gh release create "v$version" build/macos/Build/Products/Release/MCPSwitch-macOS.zip --title "v$version" --notes-file RELEASE_DRAFT.md
     
     # Archive user release notes (Optional: move or delete)
     # We delete it to keep workspace clean
     rm RELEASE_DRAFT.md
     echo "Release published and draft notes cleaned up."
   else
     # Fallback to auto-generated notes
     gh release create "v$version" build/macos/Build/Products/Release/MCPSwitch-macOS.zip --title "v$version" --generate-notes
   fi