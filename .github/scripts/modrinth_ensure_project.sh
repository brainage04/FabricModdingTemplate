#!/usr/bin/env bash

set -euo pipefail

. "$(dirname "$0")/modrinth_common.sh"

require_command curl
require_command jq
require_env GITHUB_EVENT_PATH GITHUB_REPOSITORY MODRINTH_TOKEN

if [ ! -f "$MODRINTH_PROJECT_CONFIG" ]; then
  echo "Missing Modrinth config: $MODRINTH_PROJECT_CONFIG" >&2
  exit 1
fi

if [ ! -f "$MODRINTH_PROJECT_BODY" ]; then
  echo "Missing Modrinth project body: $MODRINTH_PROJECT_BODY" >&2
  exit 1
fi

mod_id="$(gradle_property mod_id)"
mod_name="$(gradle_property mod_name)"
mod_description="$(gradle_property mod_description)"
mod_license="$(gradle_property mod_license)"
repo_url="https://github.com/${GITHUB_REPOSITORY}"
issues_url="${repo_url}/issues"
icon_path="src/main/resources/assets/${mod_id}/icon.png"

if project_id="$(resolve_project_id "$mod_id")"; then
  echo "Modrinth project already exists: ${project_id}"
  echo "MODRINTH_PROJECT_ID=${project_id}" >> "$GITHUB_ENV"
  exit 0
fi

project_payload="$(
  jq -n \
    --arg slug "$mod_id" \
    --arg title "$mod_name" \
    --arg description "$mod_description" \
    --arg license_id "$mod_license" \
    --arg repo_url "$repo_url" \
    --arg issues_url "$issues_url" \
    --rawfile body "$MODRINTH_PROJECT_BODY" \
    --slurpfile config "$MODRINTH_PROJECT_CONFIG" \
    '
      ($config[0]) as $config |
      {
        slug: $slug,
        title: $title,
        description: $description,
        body: $body,
        categories: (if ($config.categories // [] | length) > 0 then $config.categories else ["fabric"] end),
        client_side: ($config.client_side // "optional"),
        server_side: ($config.server_side // "optional"),
        status: ($config.status // "draft"),
        requested_status: ($config.requested_status // null),
        additional_categories: ($config.additional_categories // []),
        issues_url: ($config.issues_url // $issues_url),
        source_url: ($config.source_url // $repo_url),
        wiki_url: ($config.wiki_url // null),
        discord_url: ($config.discord_url // null),
        donation_urls: ($config.donation_urls // []),
        license_id: $license_id,
        license_url: ($config.license_url // null),
        project_type: ($config.project_type // "mod")
      }
    '
)"

response_file="$(mktemp)"
curl_args=(
  -F "data=${project_payload};type=application/json"
)

if [ -f "$icon_path" ]; then
  curl_args+=(-F "icon=@${icon_path}")
fi

status="$(modrinth_request POST "/project" "$response_file" "${curl_args[@]}")"

if [ "$status" != "200" ]; then
  echo "Failed to create Modrinth project for slug ${mod_id}: HTTP ${status}" >&2
  cat "$response_file" >&2
  exit 1
fi

project_id="$(jq -r '.id' "$response_file")"
echo "Created Modrinth project: ${project_id}"
echo "MODRINTH_PROJECT_ID=${project_id}" >> "$GITHUB_ENV"
