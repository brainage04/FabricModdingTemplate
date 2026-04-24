#!/usr/bin/env bash

set -euo pipefail

usage() {
  echo "Usage: $0 [--side=both|server|client] <owner> <mod_name>"
}

sanitize_mod_id() {
  local value

  value=$(
    printf '%s\n' "$1" \
    | tr '[:upper:]' '[:lower:]' \
    | sed -E 's/[^a-z0-9]+/_/g; s/^_+//; s/_+$//; s/_+/_/g'
  )

  if [ -z "$value" ]; then
    value="mod"
  elif [[ ! "$value" =~ ^[a-z] ]]; then
    value="mod_${value}"
  fi

  printf '%s\n' "$value"
}

sanitize_package_segment() {
  local value

  value=$(
    printf '%s\n' "$1" \
    | tr '[:upper:]' '[:lower:]' \
    | sed -E 's/[^a-z0-9_]+/_/g; s/^_+//; s/_+$//; s/_+/_/g'
  )

  if [ -z "$value" ]; then
    value="owner"
  elif [[ "$value" =~ ^[0-9] ]]; then
    value="_${value}"
  fi

  case "$value" in
    abstract|assert|boolean|break|byte|case|catch|char|class|const|continue|default|do|double|else|enum|extends|final|finally|float|for|goto|if|implements|import|instanceof|int|interface|long|native|new|package|private|protected|public|return|short|static|strictfp|super|switch|synchronized|this|throw|throws|transient|try|void|volatile|while|true|false|null)
      value="_${value}"
      ;;
  esac

  printf '%s\n' "$value"
}

sanitize_class_name() {
  local value

  value=$(
    printf '%s\n' "$1" \
    | awk '
      {
        gsub(/[^[:alnum:]]+/, " ")
        for (i = 1; i <= NF; i++) {
          word = tolower($i)
          out = out toupper(substr(word, 1, 1)) substr(word, 2)
        }
      }
      END {
        if (out == "") {
          out = "Mod"
        } else if (out ~ /^[0-9]/) {
          out = "Mod" out
        }
        print out
      }
    '
  )

  printf '%s\n' "$value"
}

sed_escape_replacement() {
  printf '%s\n' "$1" | sed -e 's/[\/&]/\\&/g'
}

sed_escape_path_replacement() {
  printf '%s\n' "$1" | sed -e 's/[#&]/\\&/g'
}

side="both"
positionals=()

while [ "$#" -gt 0 ]; do
  case "$1" in
    --side=*)
      side="${1#*=}"
      shift
      ;;
    --side)
      if [ "$#" -lt 2 ]; then
        usage
        exit 1
      fi
      side="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --*)
      echo "Unknown option: $1"
      usage
      exit 1
      ;;
    *)
      positionals+=("$1")
      shift
      ;;
  esac
done

if [ "${#positionals[@]}" -ne 2 ]; then
  usage
  exit 1
fi

case "$side" in
  both|server|client)
    ;;
  *)
    echo "Invalid side: $side"
    usage
    exit 1
    ;;
esac

base=$(dirname "$(readlink -f "$0")")
echo "Updating $base"

owner="${positionals[0]}"
mod_name_raw="${positionals[1]}"
mod_name_spaces=$(
  printf '%s\n' "$mod_name_raw" \
  | sed -E 's/([A-Z])/ \1/g' \
  | sed -E 's/[^[:alnum:]]+/ /g' \
  | sed -E 's/^ //'
)
mod_name="$(sanitize_class_name "$mod_name_raw")"
mod_id="$(sanitize_mod_id "$mod_name_raw")"
package_owner="$(sanitize_package_segment "$owner")"
package_name="io.github.${package_owner}.${mod_id}"
package_dir=$(echo "$package_name" | tr . /)

owner_replacement="$(sed_escape_replacement "$owner")"
mod_name_replacement="$(sed_escape_replacement "$mod_name")"
mod_id_replacement="$(sed_escape_replacement "$mod_id")"
package_name_replacement="$(sed_escape_replacement "$package_name")"
package_dir_replacement="$(sed_escape_path_replacement "$package_dir")"
repo_url_replacement="$(sed_escape_path_replacement "https://github.com/${owner}/${mod_name_raw}")"

echo "Setting owner to $owner"
echo "Setting mod name to $mod_name_raw ($mod_name_spaces)"
echo "Setting main class name to $mod_name"
echo "Setting mod id to $mod_id"
echo "Setting side to $side"
echo "Setting package name to $package_name"
echo "Setting package dir to $package_dir"

(
  if [ "${INIT_TRACE:-false}" = "true" ]; then
    set -x
  fi

  move_package_tree() {
    local source_root="$1"
    local target_root="$2"
    local staging_root
    local module_root
    local current

    if [ "$source_root" = "$target_root" ]; then
      return
    fi

    staging_root=$(mktemp -d "$base"/.init-package-tree.XXXXXX)
    shopt -s dotglob nullglob
    mv "$source_root"/* "$staging_root"/
    shopt -u dotglob nullglob

    mkdir -p "$(dirname "$target_root")"
    mv "$staging_root" "$target_root"

    module_root=$(dirname "$(dirname "$(dirname "$source_root")")")
    current="$source_root"
    while [ "$current" != "$module_root" ]; do
      rmdir --ignore-fail-on-non-empty "$current"
      current=$(dirname "$current")
    done
  }

  find_paths=(
    "$base/src/main"
    "$base/src/test"
    "$base/src/gametest"
    "$base/src/client"
  )

  # Refactor the package before the raw owner, otherwise hyphenated owners can
  # turn Java package declarations into invalid identifiers.
  find "${find_paths[@]}" -type f -exec sed -i \
      -e "s/io\.github\.brainage04/$package_name_replacement/g" \
      -e "s/fabrictemplateserver/$mod_id_replacement/g" \
      -e "s/FabricTemplateServer/$mod_name_replacement/g" \
      -e "s/brainage04/$owner_replacement/g" {} +

  sed -i \
      -E "s#https://github.com/[^/]+/${mod_name_replacement}#${repo_url_replacement}#g" \
      "$base/src/main/resources/fabric.mod.json"

  sed -i \
        -e "s/fabrictemplateserver/$mod_id_replacement/g" \
        -e "s/FabricTemplateServer/$mod_name_replacement/g" \
        -e "s/brainage04/$owner_replacement/g" "$base/build.gradle"

  sed -i \
      -e "s/io\.github\.brainage04/$package_name_replacement/g" \
      -e "s/fabrictemplateserver/$mod_id_replacement/g" \
      -e "s/FabricTemplateServer/$mod_name_replacement/g" \
      -e "s/brainage04/$owner_replacement/g" "$base/gradle.properties"

  sed -i \
      -e "s#io/github/brainage04#$package_dir_replacement#g" \
      -e "s/fabrictemplateserver/$mod_id_replacement/g" \
      -e "s/FabricTemplateServer/$mod_name_replacement/g" \
      -e "s/brainage04/$owner_replacement/g" "$base/README.md"

  sed -i \
        -e "s/brainage04/$owner_replacement/g" "$base/LICENSE"

  # refactor accesswidener and mixin file names
  mv "$base"/src/main/resources/fabrictemplateserver.accesswidener "$base"/src/main/resources/"$mod_id".accesswidener
  mv "$base"/src/main/resources/fabrictemplateserver.mixins.json "$base"/src/main/resources/"$mod_id".mixins.json

  # refactor assets directory
  mv "$base"/src/main/resources/assets/fabrictemplateserver "$base"/src/main/resources/assets/"$mod_id"
  mv "$base"/src/client/resources/assets/fabrictemplateserver "$base"/src/client/resources/assets/"$mod_id"

  # rename main class
  mv "$base"/src/main/java/io/github/brainage04/FabricTemplateServer.java "$base"/src/main/java/io/github/brainage04/"$mod_name".java
  mv "$base"/src/test/java/io/github/brainage04/FabricTemplateServerMetadataTest.java "$base"/src/test/java/io/github/brainage04/"$mod_name"MetadataTest.java
  mv "$base"/src/gametest/java/io/github/brainage04/FabricTemplateServerGameTest.java "$base"/src/gametest/java/io/github/brainage04/"$mod_name"GameTest.java
  mv "$base"/src/gametest/java/io/github/brainage04/FabricTemplateServerClientGameTest.java "$base"/src/gametest/java/io/github/brainage04/"$mod_name"ClientGameTest.java
  if [ "$side" != "server" ]; then
    mv "$base"/src/client/java/io/github/brainage04/FabricTemplateServerClient.java "$base"/src/client/java/io/github/brainage04/"$mod_name"Client.java
  fi

  # lastly, refactor package directory
  move_package_tree "$base"/src/main/java/io/github/brainage04 "$base"/src/main/java/"$package_dir"
  move_package_tree "$base"/src/test/java/io/github/brainage04 "$base"/src/test/java/"$package_dir"
  move_package_tree "$base"/src/gametest/java/io/github/brainage04 "$base"/src/gametest/java/"$package_dir"

  if [ "$side" != "server" ]; then
    move_package_tree "$base"/src/client/java/io/github/brainage04 "$base"/src/client/java/"$package_dir"
  fi

  case "$side" in
    both)
      ;;
    server)
      perl -0pi -e 's/,\n\t\t"client": \[\n\t\t\t"[^"]+"\n\t\t\]//s' "$base"/src/main/resources/fabric.mod.json
      perl -0pi -e 's/,\n\t\t"fabric-client-gametest": \[\n\t\t\t"[^"]+"\n\t\t\]//s' "$base"/src/gametest/resources/fabric.mod.json
      sed -i \
        -e '/splitEnvironmentSourceSets()/d' \
        -e '/sourceSet sourceSets.client/d' \
        -e 's/enableClientGameTests = true/enableClientGameTests = false/' "$base"/build.gradle
      perl -0pi -e 's/\n\tloom\.runs\.named\("clientGameTest"\) \{\n\t\trunDir = "build\/run\/clientGameTest"\n\t\}//s' "$base"/build.gradle
      perl -0pi -e 's/common code in `src\/main`, client-only code in `src\/client`, and GameTests in `src\/gametest`/common code in `src\/main` and GameTests in `src\/gametest`/' "$base"/README.md
      sed -i '/launches the client side/d' "$base"/README.md
      perl -0pi -e 's/For client-side GameTests, run:\n\n```shell\n\.\/gradlew runClientGameTest\n```\n\nThe template also includes a minimal client GameTest that opens a singleplayer world and checks that the client and integrated server are both reachable from the test context\.\nWhen you initialise with `--side=client`, the generated repo keeps this client GameTest path and removes the dedicated-server GameTest path\.\n\n//' "$base"/README.md
      rm -f "$base"/src/gametest/java/"$package_dir"/"$mod_name"ClientGameTest.java
      rm -rf "$base"/src/client
      ;;
    client)
      sed -i \
        -e 's/"environment": "\\*"/"environment": "client"/' \
        -e 's/"environment": "\*"/"environment": "client"/' "$base"/src/main/resources/fabric.mod.json
      sed -i \
        -e 's/"environment": "\\*"/"environment": "client"/' \
        -e 's/"environment": "\*"/"environment": "client"/' "$base"/src/gametest/resources/fabric.mod.json \
        -e '/"fabric-gametest": \[/,/\]/d' "$base"/src/gametest/resources/fabric.mod.json
      sed -i \
        -e 's/enableGameTests = true/enableGameTests = false/' \
        -e 's/systemProperty "fabric.side", "server"/systemProperty "fabric.side", "client"/' "$base"/build.gradle
      perl -0pi -e 's/\n\tloom\.runs\.named\("gameTest"\) \{\n\t\trunDir = "build\/run\/gameTest"\n\t\}//s' "$base"/build.gradle
      sed -i \
        -e 's/assertEquals(EnvType.SERVER/assertEquals(EnvType.CLIENT/' "$base"/src/test/java/"$package_dir"/"$mod_name"MetadataTest.java
      perl -0pi -e 's/common code in `src\/main`, client-only code in `src\/client`, and GameTests in `src\/gametest`/common code in `src\/main`, client-only code in `src\/client`, and client-side GameTests in `src\/gametest`/' "$base"/README.md
      sed -i '/launches the common\/server side/d' "$base"/README.md
      perl -0pi -e 's/For integration-style server tests, run:\n\n```shell\n\.\/gradlew runGameTest\n```\n\nThe template includes a separate `src\/gametest` source set with a minimal server GameTest that checks the example command was registered on the server\.\nServer GameTests also run automatically as part of `\.\/gradlew build`, which is what the included GitHub Actions workflow executes\.\n\n//' "$base"/README.md
      rm -f "$base"/src/gametest/java/"$package_dir"/"$mod_name"GameTest.java
      ;;
  esac

  rm "$base"/.github/workflows/init.yml
  rm "$(readlink -f "$0")"
)

echo "Refactor completed successfully"
