#!/usr/bin/env bash

set -euo pipefail

. "$(dirname "$0")/modrinth_common.sh"

require_command curl
require_command jq
require_env GITHUB_EVENT_PATH GITHUB_REPOSITORY MODRINTH_TOKEN

config_file="$MODRINTH_PROJECT_CONFIG"

if [ ! -f "$config_file" ]; then
  config_file="$(mktemp)"
  printf '{}\n' > "$config_file"
fi

mod_id="$(gradle_property mod_id)"
mod_name="$(gradle_property mod_name)"
mod_version="$(gradle_property mod_version)"
minecraft_version="$(gradle_property minecraft_version)"
release_tag="$(release_field '.release.tag_name')"
release_body="$(release_field '.release.body')"
release_prerelease="$(release_field '.release.prerelease')"
project_id="${MODRINTH_PROJECT_ID:-}"

if [ -z "$project_id" ]; then
  project_id="$(resolve_project_id "$mod_id")"
fi

if [ "${release_tag}" != "v${mod_version}" ]; then
  echo "Expected release tag v${mod_version}, got ${release_tag}" >&2
  exit 1
fi

response_file="$(mktemp)"
status="$(modrinth_request GET "/project/${mod_id}/version?include_changelog=false" "$response_file")"

if [ "$status" != "200" ]; then
  echo "Failed to list Modrinth versions for ${mod_id}: HTTP ${status}" >&2
  cat "$response_file" >&2
  exit 1
fi

if jq -e --arg version_number "$mod_version" '.[] | select(.version_number == $version_number)' "$response_file" >/dev/null; then
  echo "Modrinth version ${mod_version} already exists for ${mod_id}; skipping publish."
  exit 0
fi

mapfile -t release_jars < <(find build/libs -maxdepth 1 -type f -name '*.jar' ! -name '*-dev.jar' ! -name '*-sources.jar' | sort)

if [ "${#release_jars[@]}" -eq 0 ]; then
  echo "No release jar found in build/libs" >&2
  exit 1
fi

if [ "${#release_jars[@]}" -ne 1 ]; then
  printf 'Expected exactly one release jar, found %s:\n' "${#release_jars[@]}" >&2
  printf '  %s\n' "${release_jars[@]}" >&2
  exit 1
fi

version_type="release"

case "${release_tag,,}" in
  *alpha*)
    version_type="alpha"
    ;;
  *beta*|*rc*|*pre*)
    version_type="beta"
    ;;
  *)
    if [ "$release_prerelease" = "true" ]; then
      version_type="beta"
    fi
    ;;
esac

version_payload="$(
  jq -n \
    --arg project_id "$project_id" \
    --arg name "${mod_name} ${mod_version}" \
    --arg version_number "$mod_version" \
    --arg changelog "$release_body" \
    --arg minecraft_version "$minecraft_version" \
    --arg version_type "$version_type" \
    --slurpfile config "$config_file" \
    '
      ($config[0]) as $config |
      {
        project_id: $project_id,
        name: $name,
        version_number: $version_number,
        changelog: (if $changelog == "" then null else $changelog end),
        dependencies: ($config.version.dependencies // []),
        game_versions: (if ($config.version.game_versions // [] | length) > 0 then $config.version.game_versions else [$minecraft_version] end),
        version_type: $version_type,
        loaders: (if ($config.version.loaders // [] | length) > 0 then $config.version.loaders else ["fabric"] end),
        featured: ($config.version.featured // true),
        file_parts: ["primary"],
        primary_file: "primary",
        status: ($config.version.status // "listed")
      }
    '
)"

response_file="$(mktemp)"
status="$(modrinth_request POST "/version" "$response_file" \
  -F "data=${version_payload};type=application/json" \
  -F "primary=@${release_jars[0]}")

if [ "$status" != "200" ]; then
  echo "Failed to publish Modrinth version ${mod_version}: HTTP ${status}" >&2
  cat "$response_file" >&2
  exit 1
fi

echo "Published Modrinth version ${mod_version} for project ${project_id}"
