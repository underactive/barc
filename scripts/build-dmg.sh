#!/bin/bash
set -e

# Configuration
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_NAME="Barc"
SCHEME="Barc"
INFO_PLIST="$PROJECT_DIR/Barc/Info.plist"

# Output location
OUTPUT_DIR="$PROJECT_DIR/dist"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# -----------------------------------------------------------------------------
# Functions
# -----------------------------------------------------------------------------

show_help() {
    echo ""
    echo "Usage: $(basename "$0") [OPTIONS]"
    echo ""
    echo "Build Barc and create a DMG for distribution."
    echo ""
    echo "Options:"
    echo "  --bump major     Bump major version (1.0.0 → 2.0.0)"
    echo "  --bump minor     Bump minor version (1.0.0 → 1.1.0)"
    echo "  --bump patch     Bump patch version (1.0.0 → 1.0.1)"
    echo "  --set VERSION    Set version to specific value (e.g., --set 2.1.0)"
    echo "  --release        Create GitHub release after building"
    echo "  --notes \"TEXT\"   Release notes (used with --release)"
    echo "  --help           Show this help message"
    echo ""
    echo "Examples:"
    echo "  $(basename "$0")                        # Build with current version"
    echo "  $(basename "$0") --bump patch           # Bump 1.0.0 → 1.0.1, then build"
    echo "  $(basename "$0") --bump minor --release # Bump, build, and release to GitHub"
    echo ""
}

get_version() {
    /usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$INFO_PLIST" 2>/dev/null || echo "1.0.0"
}

get_build() {
    /usr/libexec/PlistBuddy -c "Print CFBundleVersion" "$INFO_PLIST" 2>/dev/null || echo "1"
}

set_version() {
    local version="$1"
    /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $version" "$INFO_PLIST"
}

set_build() {
    local build="$1"
    /usr/libexec/PlistBuddy -c "Set :CFBundleVersion $build" "$INFO_PLIST"
}

bump_version() {
    local bump_type="$1"
    local current=$(get_version)

    # Parse version components (handle 1.0 as 1.0.0)
    IFS='.' read -r major minor patch <<< "$current"
    major=${major:-0}
    minor=${minor:-0}
    patch=${patch:-0}

    case "$bump_type" in
        major)
            major=$((major + 1))
            minor=0
            patch=0
            ;;
        minor)
            minor=$((minor + 1))
            patch=0
            ;;
        patch)
            patch=$((patch + 1))
            ;;
        *)
            echo -e "${RED}ERROR: Invalid bump type '$bump_type'. Use major, minor, or patch.${NC}"
            exit 1
            ;;
    esac

    echo "${major}.${minor}.${patch}"
}

increment_build() {
    local current=$(get_build)
    echo $((current + 1))
}

check_release_requirements() {
    # Check for gh CLI
    if ! command -v gh &> /dev/null; then
        echo -e "${RED}ERROR: GitHub CLI (gh) is not installed.${NC}"
        echo "Install it with: brew install gh"
        exit 1
    fi

    # Check gh authentication
    if ! gh auth status &> /dev/null; then
        echo -e "${RED}ERROR: Not authenticated with GitHub CLI.${NC}"
        echo "Run: gh auth login"
        exit 1
    fi

    # Check for git remote
    if ! git remote get-url origin &> /dev/null; then
        echo -e "${RED}ERROR: No git remote 'origin' configured.${NC}"
        echo "Add one with: git remote add origin https://github.com/USERNAME/REPO.git"
        echo "Or create a new repo: gh repo create"
        exit 1
    fi

    # Check for uncommitted changes (excluding Info.plist which we'll change)
    local changes=$(git status --porcelain | grep -v "Barc/Info.plist" | grep -v "^??" || true)
    if [ -n "$changes" ]; then
        echo -e "${RED}ERROR: You have uncommitted changes.${NC}"
        echo "Please commit or stash them before releasing:"
        echo "$changes"
        exit 1
    fi
}

create_github_release() {
    local version="$1"
    local dmg_path="$2"
    local notes="$3"
    local tag="v${version}"

    echo -e "${YELLOW}[4/6]${NC} Committing version bump..."
    git add "$INFO_PLIST"
    git commit -m "Bump version to ${version}"
    echo -e "${GREEN}✓ Committed${NC}"

    echo -e "${YELLOW}[5/6]${NC} Creating and pushing tag ${tag}..."
    git tag "$tag"

    # Get current branch
    local branch=$(git rev-parse --abbrev-ref HEAD)

    # Push commit and tag
    git push origin "$branch"
    git push origin "$tag"
    echo -e "${GREEN}✓ Pushed to origin${NC}"

    echo -e "${YELLOW}[6/6]${NC} Creating GitHub release..."

    # Build release notes
    local release_notes="## Installation

1. Download **${PROJECT_NAME}-${version}.dmg**
2. Open the DMG and drag **${PROJECT_NAME}** to **Applications**
3. **First launch:** Right-click → Open (to bypass Gatekeeper)

After the first launch, the app opens normally with a double-click."

    if [ -n "$notes" ]; then
        release_notes="$notes

$release_notes"
    fi

    gh release create "$tag" "$dmg_path" \
        --title "${PROJECT_NAME} ${version}" \
        --notes "$release_notes"

    echo -e "${GREEN}✓ Release created${NC}"

    # Get release URL
    local release_url=$(gh release view "$tag" --json url -q '.url')
    echo ""
    echo -e "${GREEN}Release URL:${NC} $release_url"
}

# -----------------------------------------------------------------------------
# Parse Arguments
# -----------------------------------------------------------------------------

BUMP_TYPE=""
SET_VERSION=""
DO_RELEASE=false
RELEASE_NOTES=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --bump)
            BUMP_TYPE="$2"
            shift 2
            ;;
        --set)
            SET_VERSION="$2"
            shift 2
            ;;
        --release)
            DO_RELEASE=true
            shift
            ;;
        --notes)
            RELEASE_NOTES="$2"
            shift 2
            ;;
        --help|-h)
            show_help
            exit 0
            ;;
        *)
            echo -e "${RED}ERROR: Unknown option '$1'${NC}"
            show_help
            exit 1
            ;;
    esac
done

# -----------------------------------------------------------------------------
# Pre-flight Checks
# -----------------------------------------------------------------------------

# If releasing, check requirements before doing any work
if [ "$DO_RELEASE" = true ]; then
    # Require version bump for releases
    if [ -z "$BUMP_TYPE" ] && [ -z "$SET_VERSION" ]; then
        echo -e "${RED}ERROR: --release requires --bump or --set to specify version${NC}"
        echo "Example: $(basename "$0") --bump patch --release"
        exit 1
    fi

    check_release_requirements
fi

# -----------------------------------------------------------------------------
# Main Script
# -----------------------------------------------------------------------------

echo ""
echo "========================================="
echo "  Building $PROJECT_NAME"
echo "========================================="

# Determine total steps
if [ "$DO_RELEASE" = true ]; then
    TOTAL_STEPS=6
else
    TOTAL_STEPS=3
fi

# Get current version before any changes
OLD_VERSION=$(get_version)
OLD_BUILD=$(get_build)

# Handle version changes
if [ -n "$SET_VERSION" ]; then
    # Set specific version
    echo ""
    echo -e "${CYAN}Setting version: $OLD_VERSION → $SET_VERSION${NC}"
    set_version "$SET_VERSION"
    NEW_VERSION="$SET_VERSION"
elif [ -n "$BUMP_TYPE" ]; then
    # Bump version
    NEW_VERSION=$(bump_version "$BUMP_TYPE")
    echo ""
    echo -e "${CYAN}Bumping $BUMP_TYPE version: $OLD_VERSION → $NEW_VERSION${NC}"
    set_version "$NEW_VERSION"
else
    NEW_VERSION="$OLD_VERSION"
fi

# Always increment build number when building
NEW_BUILD=$(increment_build)
set_build "$NEW_BUILD"
echo -e "${CYAN}Build number: $OLD_BUILD → $NEW_BUILD${NC}"

echo ""

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Build Release version
echo -e "${YELLOW}[1/$TOTAL_STEPS]${NC} Building Release..."
xcodebuild -project "$PROJECT_DIR/$PROJECT_NAME.xcodeproj" \
    -scheme "$SCHEME" \
    -configuration Release \
    -derivedDataPath "$PROJECT_DIR/.build" \
    build \
    2>&1 | grep -E "(BUILD|error:|warning:)" || true

# Check if build succeeded
APP_PATH="$PROJECT_DIR/.build/Build/Products/Release/$PROJECT_NAME.app"
if [ ! -d "$APP_PATH" ]; then
    echo -e "${RED}ERROR: Build failed. App not found at $APP_PATH${NC}"
    # Revert version changes on failure
    set_version "$OLD_VERSION"
    set_build "$OLD_BUILD"
    exit 1
fi

echo -e "${GREEN}✓ Build succeeded${NC}"
echo "  Version: $NEW_VERSION (Build $NEW_BUILD)"

# Create DMG with version in filename
DMG_NAME="${PROJECT_NAME}-${NEW_VERSION}.dmg"
DMG_PATH="$OUTPUT_DIR/$DMG_NAME"

echo -e "${YELLOW}[2/$TOTAL_STEPS]${NC} Creating DMG..."

# Create temp directory for DMG contents
DMG_TEMP=$(mktemp -d)
cp -R "$APP_PATH" "$DMG_TEMP/"
ln -s /Applications "$DMG_TEMP/Applications"

# Remove old DMG if exists
rm -f "$DMG_PATH"

# Create DMG
hdiutil create \
    -volname "$PROJECT_NAME $NEW_VERSION" \
    -srcfolder "$DMG_TEMP" \
    -ov \
    -format UDZO \
    "$DMG_PATH" \
    > /dev/null

# Clean up
rm -rf "$DMG_TEMP"

echo -e "${GREEN}✓ DMG created${NC}"

# Create GitHub release if requested
if [ "$DO_RELEASE" = true ]; then
    echo -e "${YELLOW}[3/$TOTAL_STEPS]${NC} Preparing release..."
    create_github_release "$NEW_VERSION" "$DMG_PATH" "$RELEASE_NOTES"
else
    echo -e "${YELLOW}[3/$TOTAL_STEPS]${NC} Done!"
fi

# Show result
echo ""
DMG_SIZE=$(ls -lh "$DMG_PATH" | awk '{print $5}')
echo "========================================="
echo -e "  ${GREEN}Version:${NC} $NEW_VERSION (Build $NEW_BUILD)"
echo -e "  ${GREEN}Output:${NC}  $DMG_PATH"
echo -e "  ${GREEN}Size:${NC}    $DMG_SIZE"
echo "========================================="
echo ""

if [ "$DO_RELEASE" = true ]; then
    echo "Release complete! Users can now download from GitHub."
else
    echo "To distribute:"
    echo "  1. Upload $DMG_NAME to GitHub Releases, your website, etc."
    echo "  2. Tell users to right-click → Open on first launch"
    echo ""

    # Remind to commit version change
    if [ -n "$SET_VERSION" ] || [ -n "$BUMP_TYPE" ]; then
        echo -e "${CYAN}Don't forget to commit the version bump:${NC}"
        echo "  git add Barc/Info.plist"
        echo "  git commit -m \"Bump version to $NEW_VERSION\""
        echo ""
        echo -e "${CYAN}Or release to GitHub automatically:${NC}"
        echo "  $(basename "$0") --bump patch --release"
        echo ""
    fi
fi
