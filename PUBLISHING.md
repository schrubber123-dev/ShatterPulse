# Publishing ShatterPulse

ShatterPulse uses the [BigWigsMods WoW Packager](https://github.com/BigWigsMods/packager) in GitHub Actions to build the addon and publish it to CurseForge.

## One-time setup

1. Add the CurseForge API token as the repository **Actions secret** named `CF_API_KEY`. Never put the token into source code or an issue.
2. Add the numeric CurseForge project ID as the repository **Actions variable** named `CF_PROJECT_ID`.
3. Upload the supplied `ShatterPulse-Media.zip` to the **root of the GitHub repository**, preserving that exact filename. The workflow extracts and verifies all seven bundled frost textures and sounds. Do not upload `ShatterPulse-1.0.0.zip` in its place.
4. Confirm that the existing CurseForge project belongs to your author account and is configured for WoW Forever.

## Test without publishing

Open **Actions → Publish ShatterPulse → Run workflow** and keep **dry_run** checked.

The workflow validates the media files, prepares the addon root, and builds a ZIP without uploading to CurseForge.

## Publish a version

After a successful dry run, create a **new annotated Git tag** such as `v1.0.1` pointing at the tested commit and push it.

The workflow runs on tags matching `v*` and uploads the addon to CurseForge using the `CF_API_KEY` secret. The tag's version should match the version in `ShatterPulse/ShatterPulse.toc` and `ShatterPulse/ShatterPulse.lua`.

The first automated upload should use a **new version number**, rather than republishing an existing CurseForge file.

## Important

The GitHub source folder intentionally does not contain binary assets. The release workflow requires the media ZIP to build a complete installable addon. It fails instead of publishing a broken package when files are missing.

CurseForge moderation and processing still apply. A successful upload does not guarantee immediate public availability.
