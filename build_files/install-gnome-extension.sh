set -euo pipefail

uuid="${1:?Extension UUID is required}"
shell_major="${2:?GNOME Shell major version is required}"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

archive="${tmpdir}/extension.zip"
unpacked="${tmpdir}/unpacked"
target="/usr/share/gnome-shell/extensions/${uuid}"

url="https://extensions.gnome.org/download-extension/${uuid}.shell-extension.zip?shell_version=${shell_major}"

mkdir -p "$unpacked"

curl \
    --fail \
    --location \
    --retry 3 \
    --retry-delay 5 \
    --output "$archive" \
    "$url"

unzip -q "$archive" -d "$unpacked"

metadata="$(find "$unpacked" -maxdepth 2 -type f -name metadata.json -print -quit)"

if [[ -z "$metadata" ]]; then
    echo "The downloaded archive for ${uuid} has no metadata.json file."
    exit 1
fi

source_dir="$(dirname "$metadata")"
actual_uuid="$(jq -r '.uuid // empty' "$metadata")"

if [[ "$actual_uuid" != "$uuid" ]]; then
    echo "Expected extension UUID ${uuid}, but downloaded ${actual_uuid}."
    exit 1
fi

if ! jq -e --arg version "$shell_major" \
    '(."shell-version" // []) | map(tostring) | index($version) != null' \
    "$metadata" >/dev/null; then
    echo "Extension ${uuid} does not declare GNOME Shell ${shell_major} support."
    exit 1
fi

rm -rf "$target"
install -d -m 0755 "$target"
cp -a "${source_dir}/." "$target/"
chmod -R a+rX "$target"

if find "$target" -path '*/schemas/*.gschema.xml' -type f -print -quit | grep -q .; then
    glib-compile-schemas "$target/schemas"
fi

version_name="$(jq -r '."version-name" // .version // "unknown"' "$target/metadata.json")"
echo "Installed ${uuid}, version ${version_name}, for GNOME Shell ${shell_major}."
