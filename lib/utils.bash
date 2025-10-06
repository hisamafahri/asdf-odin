#!/usr/bin/env bash

set -euo pipefail

GH_REPO="https://github.com/odin-lang/Odin"
TOOL_NAME="odin"
TOOL_TEST="odin version"

fail() {
	echo -e "asdf-$TOOL_NAME: $*"
	exit 1
}

curl_opts=(-fsSL)

# NOTE: You might want to remove this if odin is not hosted on GitHub releases.
if [ -n "${GITHUB_API_TOKEN:-}" ]; then
	curl_opts=("${curl_opts[@]}" -H "Authorization: token $GITHUB_API_TOKEN")
fi

sort_versions() {
	sed 'h; s/[+-]/./g; s/.p\([[:digit:]]\)/.z\1/; s/$/.z/; G; s/\n/ /' |
		LC_ALL=C sort -t. -k 1,1 -k 2,2n -k 3,3n -k 4,4n -k 5,5n | awk '{print $2}'
}

list_github_tags() {
	# IMPORTANT:
	# Only list tags that have the 'dev-' prefix
	# This filters out stable releases and only shows development versions
	git ls-remote --tags --refs "$GH_REPO" |
		grep -o 'refs/tags/.*' | cut -d/ -f3- |
		sed 's/^v//' | # Remove 'v' prefix if present
		grep '^dev-'   # Only include tags starting with 'dev-'
}

list_all_versions() {
	list_github_tags
}

download_release() {
	local version
	version="$1"

	# Handle "latest" version by resolving it to the actual latest tag
	if [ "$version" = "latest" ]; then
		echo "* Resolving latest version..."
		# Use the same logic as latest-stable script
		local redirect_url
		redirect_url=$(curl -sI "$GH_REPO/releases/latest" | sed -n -e "s|^location: *||p" | sed -n -e "s|\r||p")
		version=$(printf "%s\n" "$redirect_url" | sed 's|.*/tag/||')
		echo "* Latest version resolved to: $version"
	fi

	echo "* Downloading $TOOL_NAME source $version..."

	# Clone the repository and checkout the specific version
	git clone --depth 1 --branch "$version" "$GH_REPO" "$ASDF_DOWNLOAD_PATH/odin-source" || fail "Could not clone $GH_REPO at version $version"

	# Build Odin from source
	echo "* Building $TOOL_NAME from source..."
	cd "$ASDF_DOWNLOAD_PATH/odin-source"

	# Check for required dependencies and build based on platform
	case "$(uname -s)" in
	Darwin*)
		# Check for XCode command line tools
		if ! command -v clang &>/dev/null; then
			fail "XCode command line tools are required. Please run: xcode-select --install"
		fi

		# Check for LLVM via Homebrew first, then system
		LLVM_CONFIG=""
		if command -v brew &>/dev/null; then
			# Try to find compatible LLVM versions via Homebrew (in order of preference)
			for version in 20 19 18 17 14 13 12 11; do
				HOMEBREW_LLVM_PREFIX="$(brew --prefix llvm@$version 2>/dev/null || echo "")"
				if [ -n "$HOMEBREW_LLVM_PREFIX" ] && [ -f "$HOMEBREW_LLVM_PREFIX/bin/llvm-config" ]; then
					LLVM_CONFIG="$HOMEBREW_LLVM_PREFIX/bin/llvm-config"
					echo "* Using Homebrew LLVM@$version: $LLVM_CONFIG"
					break
				fi
			done

			# Also try unversioned LLVM (but check if it's a compatible version)
			if [ -z "$LLVM_CONFIG" ]; then
				HOMEBREW_LLVM_PREFIX="$(brew --prefix llvm 2>/dev/null || echo "")"
				if [ -n "$HOMEBREW_LLVM_PREFIX" ] && [ -f "$HOMEBREW_LLVM_PREFIX/bin/llvm-config" ]; then
					# Check if the version is compatible
					LLVM_VERSION="$("$HOMEBREW_LLVM_PREFIX"/bin/llvm-config --version | cut -d. -f1)"
					case "$LLVM_VERSION" in
					11 | 12 | 13 | 14 | 17 | 18 | 19 | 20)
						LLVM_CONFIG="$HOMEBREW_LLVM_PREFIX/bin/llvm-config"
						echo "* Using Homebrew LLVM $LLVM_VERSION: $LLVM_CONFIG"
						;;
					*)
						echo "* Found LLVM $LLVM_VERSION but Odin requires version 11, 12, 13, 14, 17, 18, 19, or 20"
						;;
					esac
				fi
			fi
		fi

		# Fallback to system llvm-config
		if [ -z "$LLVM_CONFIG" ] && command -v llvm-config &>/dev/null; then
			LLVM_CONFIG="$(command -v llvm-config)"
			echo "* Using system LLVM: $LLVM_CONFIG"
		fi

		# If no LLVM found, provide installation instructions
		if [ -z "$LLVM_CONFIG" ]; then
			echo "* LLVM not found. Installing compatible version via Homebrew..."
			if command -v brew &>/dev/null; then
				# Install a specific compatible LLVM version (20 is the latest supported)
				brew install llvm@20 || fail "Failed to install LLVM@20 via Homebrew"
				HOMEBREW_LLVM_PREFIX="$(brew --prefix llvm@20)"
				LLVM_CONFIG="$HOMEBREW_LLVM_PREFIX/bin/llvm-config"
				echo "* Installed LLVM@20 via Homebrew: $LLVM_CONFIG"
			else
				fail "LLVM is required but Homebrew is not installed. Please install Homebrew and then run: brew install llvm@20"
			fi
		fi

		# Build with the found LLVM
		LLVM_CONFIG="$LLVM_CONFIG" make release-native || fail "Could not build Odin for macOS"
		;;
	Linux*)
		# Check for clang and LLVM
		if ! command -v clang &>/dev/null; then
			echo "* Clang not found. Installing via package manager..."
			if command -v apt-get &>/dev/null; then
				sudo apt-get update && (sudo apt-get install -y clang || fail "Failed to install clang via apt-get")
			elif command -v dnf &>/dev/null; then
				sudo dnf install -y clang || fail "Failed to install clang via dnf"
			elif command -v yum &>/dev/null; then
				sudo yum install -y clang || fail "Failed to install clang via yum"
			else
				fail "Clang is required. Please install clang (e.g., apt install clang or dnf install clang)"
			fi
		fi

		if ! command -v llvm-config &>/dev/null; then
			echo "* LLVM development tools not found. Installing via package manager..."
			if command -v apt-get &>/dev/null; then
				sudo apt-get install -y llvm-dev || fail "Failed to install llvm-dev via apt-get"
			elif command -v dnf &>/dev/null; then
				sudo dnf install -y llvm-devel || fail "Failed to install llvm-devel via dnf"
			elif command -v yum &>/dev/null; then
				sudo yum install -y llvm-devel || fail "Failed to install llvm-devel via yum"
			else
				fail "LLVM development tools are required. Please install llvm-dev or llvm-devel"
			fi
		fi

		echo "* Using system LLVM: $(command -v llvm-config)"
		make release-native || fail "Could not build Odin for Linux"
		;;
	*)
		fail "Unsupported platform: $(uname -s). Please build manually and submit a PR for this platform."
		;;
	esac

	# Move the built binary and required folders to the expected location
	mkdir -p "$ASDF_DOWNLOAD_PATH"
	cp odin "$ASDF_DOWNLOAD_PATH/"
	cp -r base core vendor "$ASDF_DOWNLOAD_PATH/"

	# Clean up source directory
	cd "$ASDF_DOWNLOAD_PATH"
	rm -rf odin-source
}

install_version() {
	local install_type="$1"
	local version="$2"
	local install_path="${3%/bin}/bin"

	if [ "$install_type" != "version" ]; then
		fail "asdf-$TOOL_NAME supports release installs only"
	fi

	(
		mkdir -p "$install_path"

		# Copy the odin binary
		cp "$ASDF_DOWNLOAD_PATH/odin" "$install_path/odin.bin"

		# Copy the required folders (base, core, vendor) to the parent directory
		# These need to be next to the binary for Odin to work properly
		local odin_root="${install_path%/bin}"
		cp -r "$ASDF_DOWNLOAD_PATH/base" "$odin_root/"
		cp -r "$ASDF_DOWNLOAD_PATH/core" "$odin_root/"
		cp -r "$ASDF_DOWNLOAD_PATH/vendor" "$odin_root/"

		# Create a wrapper script that sets ODIN_ROOT
		cat >"$install_path/odin" <<'EOF'
#!/usr/bin/env bash
# Odin wrapper script that sets ODIN_ROOT correctly
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ODIN_ROOT="$(dirname "$SCRIPT_DIR")"
export ODIN_ROOT
exec "$ODIN_ROOT/bin/odin.bin" "$@"
EOF

		# Make the wrapper executable
		chmod +x "$install_path/odin"

		# Test that odin executable exists and is executable.
		local tool_cmd
		tool_cmd="$(echo "$TOOL_TEST" | cut -d' ' -f1)"
		test -x "$install_path/$tool_cmd" || fail "Expected $install_path/$tool_cmd to be executable."

		echo "$TOOL_NAME $version installation was successful!"
	) || (
		rm -rf "$install_path"
		fail "An error occurred while installing $TOOL_NAME $version."
	)
}
