#!/usr/bin/env bash

set -euo pipefail

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

gradle_property() {
  local key="$1"

  awk -F= -v key="$key" '$1 == key { print substr($0, index($0, $2)); exit }' gradle.properties
}

sed_escape_replacement() {
  printf '%s\n' "$1" | sed -e 's/[\/&]/\\&/g'
}

require_command jq
require_command awk
require_command sed

repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
tmp_root="$(mktemp -d "${TMPDIR:-/tmp}/modrinth-script-test.XXXXXX")"
fake_bin="$tmp_root/bin"
stub_state="$tmp_root/state"
default_stub_state="$tmp_root/default-state"
github_env="$tmp_root/github-env"
release_jar_dir="$tmp_root/build-libs"

trap 'rm -rf "$tmp_root"' EXIT

mkdir -p "$fake_bin" "$stub_state" "$default_stub_state" "$release_jar_dir"

cat >"$fake_bin/curl" <<'STUB'
#!/usr/bin/env bash

set -euo pipefail

method="GET"
output_file=""
url=""
payload=""
primary_file=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    -o)
      output_file="$2"
      shift 2
      ;;
    -w)
      shift 2
      ;;
    -X)
      method="$2"
      shift 2
      ;;
    -H)
      shift 2
      ;;
    -F)
      form_part="$2"
      case "$form_part" in
        data=*)
          payload="${form_part#data=}"
          payload="${payload%;type=application/json}"
          ;;
        primary=@*)
          primary_file="${form_part#primary=@}"
          ;;
      esac
      shift 2
      ;;
    --data-binary)
      payload="$2"
      shift 2
      ;;
    -*)
      shift
      ;;
    *)
      url="$1"
      shift
      ;;
  esac
done

path="${url#https://modrinth.test/v2}"
status="500"
body='{"error":"unhandled stub request"}'
project_path="/project/${MODRINTH_STUB_PROJECT_SLUG}"
version_path="${project_path}/version?include_changelog=false"

if [ "${method} ${path}" = "GET ${project_path}" ]; then
    if [ -f "$MODRINTH_STUB_DIR/project-created" ]; then
      status="200"
      body="{\"id\":\"${MODRINTH_STUB_PROJECT_ID}\"}"
    else
      status="404"
      body='{"error":"not found"}'
    fi
elif [ "${method} ${path}" = "POST /project" ]; then
    status="200"
    body="{\"id\":\"${MODRINTH_STUB_PROJECT_ID}\"}"
    touch "$MODRINTH_STUB_DIR/project-created"
    printf '%s\n' "$payload" > "$MODRINTH_STUB_DIR/create-project.json"
elif [ "${method} ${path}" = "PATCH ${project_path}" ]; then
    status="204"
    body=""
    printf '%s\n' "$payload" > "$MODRINTH_STUB_DIR/patch-project.json"
elif [ "${method} ${path}" = "GET ${version_path}" ]; then
    status="200"
    body='[]'
else
  case "${method} ${path}" in
    "GET /project/fabric-api")
    status="200"
    body='{"id":"fabric-api-project"}'
      ;;
    "GET /project/fzzy_config")
      status="404"
      body='{"error":"not found"}'
      ;;
    "GET /project/fzzy-config")
      status="200"
      body='{"id":"fzzy-config-project"}'
      ;;
    "POST /version")
      if [ ! -f "$primary_file" ]; then
        status="400"
        body='{"error":"missing primary file"}'
      else
        status="200"
        body='{"id":"published-version"}'
        printf '%s\n' "$payload" > "$MODRINTH_STUB_DIR/create-version.json"
      fi
      ;;
  esac
fi

if [ -n "$output_file" ]; then
  printf '%s' "$body" > "$output_file"
fi

printf '%s' "$status"
STUB

chmod +x "$fake_bin/curl"

(
  cd "$repo_root"

  mod_version="$(gradle_property mod_version)"
  mod_id="$(gradle_property mod_id)"
  mod_name="$(gradle_property mod_name)"
  minecraft_version="$(gradle_property minecraft_version)"
  loader_version="$(gradle_property loader_version)"
  archives_base_name="$(gradle_property archives_base_name)"
  repo_for_test="${GITHUB_REPOSITORY:-brainage04/FabricModdingTemplate}"
  project_id_for_test="${mod_id}-project"

  mkdir -p build/resources/main
  sed \
    -e "s/\${mod_id}/$(sed_escape_replacement "$mod_id")/g" \
    -e "s/\${mod_version}/$(sed_escape_replacement "$mod_version")/g" \
    -e "s/\${mod_name}/$(sed_escape_replacement "$mod_name")/g" \
    -e "s/\${minecraft_version}/$(sed_escape_replacement "$minecraft_version")/g" \
    -e "s/\${loader_version}/$(sed_escape_replacement "$loader_version")/g" \
    src/main/resources/fabric.mod.json >build/resources/main/fabric.mod.json

  touch "$release_jar_dir/${archives_base_name}-${mod_version}.jar"

  PATH="$fake_bin:$PATH" \
    MODRINTH_STUB_DIR="$stub_state" \
    MODRINTH_STUB_PROJECT_SLUG="$mod_id" \
    MODRINTH_STUB_PROJECT_ID="$project_id_for_test" \
    MODRINTH_API="https://modrinth.test/v2" \
    MODRINTH_TOKEN="stub-token" \
    GITHUB_REPOSITORY="$repo_for_test" \
    GITHUB_ENV="$github_env" \
    bash ./.github/scripts/modrinth_ensure_project.sh

  env -u GITHUB_ENV \
    PATH="$fake_bin:$PATH" \
    MODRINTH_STUB_DIR="$default_stub_state" \
    MODRINTH_STUB_PROJECT_SLUG="$mod_id" \
    MODRINTH_STUB_PROJECT_ID="$project_id_for_test" \
    MODRINTH_API="https://modrinth.test/v2" \
    MODRINTH_PROJECT_CONFIG="$tmp_root/missing-project.json" \
    MODRINTH_TOKEN="stub-token" \
    GITHUB_REPOSITORY="$repo_for_test" \
    bash ./.github/scripts/modrinth_ensure_project.sh

  set -a
  # shellcheck disable=SC1090
  . "$github_env"
  set +a

  PATH="$fake_bin:$PATH" \
    MODRINTH_STUB_DIR="$stub_state" \
    MODRINTH_STUB_PROJECT_SLUG="$mod_id" \
    MODRINTH_STUB_PROJECT_ID="$project_id_for_test" \
    MODRINTH_API="https://modrinth.test/v2" \
    MODRINTH_RELEASE_JAR_DIR="$release_jar_dir" \
    MODRINTH_TOKEN="stub-token" \
    GITHUB_REPOSITORY="$repo_for_test" \
    RELEASE_TAG="v${mod_version}" \
    RELEASE_BODY="Smoke Modrinth release" \
    RELEASE_PRERELEASE="false" \
    bash ./.github/scripts/modrinth_publish_version.sh

  printf '%s\n' "$mod_id" >"$stub_state/expected-mod-id"
  printf '%s\n' "$mod_version" >"$stub_state/expected-mod-version"
  printf '%s\n' "$repo_for_test" >"$stub_state/expected-repo"
  printf '%s\n' "$project_id_for_test" >"$stub_state/expected-project-id"
)

mod_id="$(cat "$stub_state/expected-mod-id")"
mod_version="$(cat "$stub_state/expected-mod-version")"
repo_for_test="$(cat "$stub_state/expected-repo")"
project_id_for_test="$(cat "$stub_state/expected-project-id")"
repo_url="https://github.com/${repo_for_test}"

jq -e '
  .slug == $mod_id and
  .categories == ["library"] and
  .source_url == $repo_url and
  .issues_url == ($repo_url + "/issues") and
  .wiki_url == ($repo_url + "/wiki") and
  .license_url == ($repo_url + "/blob/HEAD/LICENSE") and
  .discord_url == "https://discord.gg/N4zfhBx8Fm" and
  .initial_versions == []
' --arg mod_id "$mod_id" --arg repo_url "$repo_url" "$stub_state/create-project.json" >/dev/null

jq -e '
  .slug == $mod_id and
  .categories == ["utility"]
' --arg mod_id "$mod_id" "$default_stub_state/create-project.json" >/dev/null

jq -e '
  .source_url == $repo_url and
  .issues_url == ($repo_url + "/issues") and
  .wiki_url == ($repo_url + "/wiki") and
  .license_url == ($repo_url + "/blob/HEAD/LICENSE") and
  .client_side == "required" and
  .server_side == "required"
' --arg repo_url "$repo_url" "$stub_state/patch-project.json" >/dev/null

jq -e '
  .project_id == $project_id and
  .version_number == $mod_version and
  .changelog == "Smoke Modrinth release" and
  (.dependencies | any(.project_id == "fabric-api-project" and .dependency_type == "required")) and
  (.dependencies | any(.project_id == "fzzy-config-project" and .dependency_type == "required"))
' --arg project_id "$project_id_for_test" --arg mod_version "$mod_version" "$stub_state/create-version.json" >/dev/null

echo "Modrinth script tests passed."
