#!/usr/bin/env bash

set -euo pipefail

usage() {
  echo "Usage: $0 [--side=both|server|client] <mod_name>"
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

if [ "${#positionals[@]}" -ne 1 ]; then
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

mod_name_raw="${positionals[0]}"
mod_name_spaces=$(
  printf '%s\n' "$mod_name_raw" \
  | sed -E 's/([A-Z])/ \1/g' \
  | sed -E 's/[^[:alnum:]]+/ /g' \
  | sed -E 's/^ //'
)
mod_name="$(sanitize_class_name "$mod_name_raw")"
mod_id="$(sanitize_mod_id "$mod_name_raw")"
package_name="io.github.brainage04.${mod_id}"
package_dir=$(echo "$package_name" | tr . /)

mod_name_replacement="$(sed_escape_replacement "$mod_name")"
mod_id_replacement="$(sed_escape_replacement "$mod_id")"
package_name_replacement="$(sed_escape_replacement "$package_name")"
package_dir_replacement="$(sed_escape_path_replacement "$package_dir")"
repo_url_replacement="$(sed_escape_path_replacement "https://github.com/brainage04/${mod_name_raw}")"
package_name_placeholder="__INIT_PACKAGE_NAME__"
package_dir_placeholder="__INIT_PACKAGE_DIR__"

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

  merge_tree() {
    local source_root="$1"
    local target_root="$2"

    if [ ! -d "$source_root" ]; then
      return
    fi

    mkdir -p "$target_root"
    cp -a "$source_root"/. "$target_root"/
  }

  find_paths=(
    "$base/src/main"
    "$base/src/test"
    "$base/src/gametest"
    "$base/src/client"
  )

  # Use placeholders so later replacements cannot rewrite text inserted by
  # earlier replacements. This matters when the new mod id contains the
  # template mod id as a prefix.
  find "${find_paths[@]}" -type f -exec sed -i \
      -e "s/io\.github\.brainage04\.fabricmoddingtemplate/$package_name_placeholder/g" \
      -e "s/fabricmoddingtemplate/$mod_id_replacement/g" \
      -e "s/FabricModdingTemplate/$mod_name_replacement/g" \
      -e "s/$package_name_placeholder/$package_name_replacement/g" {} +

  sed -i \
      -E "s#https://github.com/brainage04/${mod_name_replacement}#${repo_url_replacement}#g" \
      "$base/src/main/resources/fabric.mod.json"

  sed -i \
        -e "s/fabricmoddingtemplate/$mod_id_replacement/g" \
        -e "s/FabricModdingTemplate/$mod_name_replacement/g" "$base/build.gradle"

  sed -i \
      -e "s/io\.github\.brainage04\.fabricmoddingtemplate/$package_name_placeholder/g" \
      -e "s/fabricmoddingtemplate/$mod_id_replacement/g" \
      -e "s/FabricModdingTemplate/$mod_name_replacement/g" \
      -e "s/$package_name_placeholder/$package_name_replacement/g" "$base/gradle.properties"

  sed -i \
      -e "s#io/github/brainage04/fabricmoddingtemplate#$package_dir_placeholder#g" \
      -e "s/fabricmoddingtemplate/$mod_id_replacement/g" \
      -e "s/FabricModdingTemplate/$mod_name_replacement/g" \
      -e "s#$package_dir_placeholder#$package_dir_replacement#g" "$base/README.md"

  # refactor accesswidener and mixin file names
  mv "$base"/src/main/resources/fabricmoddingtemplate.accesswidener "$base"/src/main/resources/"$mod_id".accesswidener
  mv "$base"/src/main/resources/fabricmoddingtemplate.mixins.json "$base"/src/main/resources/"$mod_id".mixins.json
  mv "$base"/src/client/resources/fabricmoddingtemplate.client.mixins.json "$base"/src/client/resources/"$mod_id".client.mixins.json

  # refactor assets directory
  mv "$base"/src/main/resources/assets/fabricmoddingtemplate "$base"/src/main/resources/assets/"$mod_id"
  mv "$base"/src/client/resources/assets/fabricmoddingtemplate "$base"/src/client/resources/assets/"$mod_id"

  # rename main class
  mv "$base"/src/main/java/io/github/brainage04/fabricmoddingtemplate/FabricModdingTemplate.java "$base"/src/main/java/io/github/brainage04/fabricmoddingtemplate/"$mod_name".java
  mv "$base"/src/test/java/io/github/brainage04/fabricmoddingtemplate/FabricModdingTemplateMetadataTest.java "$base"/src/test/java/io/github/brainage04/fabricmoddingtemplate/"$mod_name"MetadataTest.java
  mv "$base"/src/gametest/java/io/github/brainage04/fabricmoddingtemplate/FabricModdingTemplateGameTest.java "$base"/src/gametest/java/io/github/brainage04/fabricmoddingtemplate/"$mod_name"GameTest.java
  mv "$base"/src/gametest/java/io/github/brainage04/fabricmoddingtemplate/FabricModdingTemplateClientGameTest.java "$base"/src/gametest/java/io/github/brainage04/fabricmoddingtemplate/"$mod_name"ClientGameTest.java
  if [ "$side" != "server" ]; then
    mv "$base"/src/client/java/io/github/brainage04/fabricmoddingtemplate/FabricModdingTemplateClient.java "$base"/src/client/java/io/github/brainage04/fabricmoddingtemplate/"$mod_name"Client.java
  fi

  # lastly, refactor package directory
  move_package_tree "$base"/src/main/java/io/github/brainage04/fabricmoddingtemplate "$base"/src/main/java/"$package_dir"
  move_package_tree "$base"/src/test/java/io/github/brainage04/fabricmoddingtemplate "$base"/src/test/java/"$package_dir"
  move_package_tree "$base"/src/gametest/java/io/github/brainage04/fabricmoddingtemplate "$base"/src/gametest/java/"$package_dir"

  if [ "$side" != "server" ]; then
    move_package_tree "$base"/src/client/java/io/github/brainage04/fabricmoddingtemplate "$base"/src/client/java/"$package_dir"
  fi

  case "$side" in
    both)
      ;;
    server)
      perl -0pi -e 's/\n\t\t"client": \[\n\t\t\t"[^"]+"\n\t\t\],//s; s/,\n\t\t"client": \[\n\t\t\t"[^"]+"\n\t\t\]//s' "$base"/src/main/resources/fabric.mod.json
      perl -0pi -e 's/,\n\t\t\{\n\t\t\t"config": "[^"]+\.client\.mixins\.json",\n\t\t\t"environment": "client"\n\t\t\}//s' "$base"/src/main/resources/fabric.mod.json
      perl -0pi -e 's/\n\t\t"fabric-client-gametest": \[\n\t\t\t"[^"]+"\n\t\t\],//s; s/,\n\t\t"fabric-client-gametest": \[\n\t\t\t"[^"]+"\n\t\t\]//s' "$base"/src/gametest/resources/fabric.mod.json
      sed -i \
        -e '/splitEnvironmentSourceSets()/d' \
        -e '/sourceSet sourceSets.client/d' \
        -e '/enableClientGameTests = true/d' "$base"/build.gradle
      perl -0pi -e 's/\n\tmods \{\n\t\t[^\n]+ \{\n\t\t\tsourceSet sourceSets\.main\n\t\t\}\n\t\}\n//s' "$base"/build.gradle
      perl -0pi -e 's/\n\tloom\.runs\.named\("clientGameTest"\) \{\n\t\trunDir = "build\/run\/clientGameTest"\n\t\}//s' "$base"/build.gradle
      perl -0pi -e 's/\n\/\/ BEGIN CLIENT GAMETEST RUN SETUP\n.*?\/\/ END CLIENT GAMETEST RUN SETUP\n//s' "$base"/build.gradle
      perl -0pi -e 's/common code in `src\/main`, client-only code in `src\/client`, and GameTests in `src\/gametest`/common code in `src\/main` and GameTests in `src\/gametest`/' "$base"/README.md
      sed -i '/launches the client side/d' "$base"/README.md
      perl -0pi -e 's/For client-side GameTests, run:\n\n```shell\n\.\/gradlew runClientGameTest\n```\n\nThe template also includes a minimal client GameTest that boots the client, connects to an in-process dedicated server, and checks that the client initializer ran in an in-world context\.\nWhen you initialise with `--side=client`, the generated repo keeps this client GameTest path and removes the dedicated-server GameTest path\.\n\n//' "$base"/README.md
      rm -f "$base"/src/gametest/java/"$package_dir"/"$mod_name"ClientGameTest.java
      rm -rf "$base"/src/client
      rm -f "$base"/run/options.txt
      perl -0pi -e 's/\n  workflow_dispatch:\n    inputs:\n      run_client_gametests:\n        description: Run headless client GameTests\n        required: false\n        type: boolean\n        default: true/\n  workflow_dispatch:/s' "$base"/.github/workflows/build.yml
      perl -0pi -e 's/\n  client-gametests:\n.*\z/\n/s' "$base"/.github/workflows/build.yml
      ;;
    client)
      sed -i \
        -e 's/"environment": "\\*"/"environment": "client"/' \
        -e 's/"environment": "\*"/"environment": "client"/' "$base"/src/main/resources/fabric.mod.json
      sed -i \
        -e 's/"environment": "\\*"/"environment": "client"/' \
        -e 's/"environment": "\*"/"environment": "client"/' "$base"/src/gametest/resources/fabric.mod.json
      perl -0pi -e 's/\n\t\t"fabric-gametest": \[\n\t\t\t"[^"]+"\n\t\t\],//s; s/,\n\t\t"fabric-gametest": \[\n\t\t\t"[^"]+"\n\t\t\]//s' "$base"/src/gametest/resources/fabric.mod.json
      perl -0pi -e 's/\n\t\t"[^"]+\.mixins\.json",//s' "$base"/src/main/resources/fabric.mod.json
      sed -i \
        -e '/splitEnvironmentSourceSets()/d' \
        -e '/sourceSet sourceSets.client/d' \
        -e 's/enableGameTests = true/enableGameTests = false/' \
        -e 's/systemProperty "fabric.side", "server"/systemProperty "fabric.side", "client"/' "$base"/build.gradle
      perl -0pi -e 's/\n\tmods \{\n\t\t[^\n]+ \{\n\t\t\tsourceSet sourceSets\.main\n\t\t\}\n\t\}\n//s' "$base"/build.gradle
      perl -0pi -e 's/\n\tloom\.runs\.named\("gameTest"\) \{\n\t\trunDir = "build\/run\/gameTest"\n\t\}//s' "$base"/build.gradle
      sed -i \
        -e 's/assertEquals(EnvType.SERVER/assertEquals(EnvType.CLIENT/' "$base"/src/test/java/"$package_dir"/"$mod_name"MetadataTest.java
      perl -0pi -e 's/common code in `src\/main`, client-only code in `src\/client`, and GameTests in `src\/gametest`/client-only code in `src\/main` and client-side GameTests in `src\/gametest`/' "$base"/README.md
      sed -i '/launches the common\/server side/d' "$base"/README.md
      sed -i '/server command example/d' "$base"/README.md
      sed -i '/Plain unit tests for your own code, such as command registration/d' "$base"/README.md
      perl -0pi -e 's/For integration-style server tests, run:\n\n```shell\n\.\/gradlew runGameTest\n```\n\nThe template includes a separate `src\/gametest` source set with a minimal server GameTest that checks the example command was registered on the server\.\nServer GameTests also run automatically as part of `\.\/gradlew build`, which is what the included GitHub Actions workflow executes\.\n\n//' "$base"/README.md
      sed -i \
        -e '/import .*command\.core\.ModCommands;/d' \
        -e '/ModCommands\.initialize();/d' "$base"/src/main/java/"$package_dir"/"$mod_name".java
	      rm -f "$base"/src/main/java/"$package_dir"/command/ExampleCommand.java
	      rm -f "$base"/src/main/java/"$package_dir"/command/core/ModCommands.java
	      rm -f "$base"/src/main/java/"$package_dir"/mixin/ExampleMixin.java
	      rmdir --ignore-fail-on-non-empty "$base"/src/main/java/"$package_dir"/command/core "$base"/src/main/java/"$package_dir"/command
	      rm -rf "$base"/src/test/java/"$package_dir"/command
	      rm -f "$base"/src/gametest/java/"$package_dir"/"$mod_name"GameTest.java
      rm -f "$base"/src/main/resources/"$mod_id".mixins.json
      merge_tree "$base"/src/client/java "$base"/src/main/java
      merge_tree "$base"/src/client/resources "$base"/src/main/resources
      rm -rf "$base"/src/client
      ;;
  esac

  perl -0pi -e 's/\n      - name: test Modrinth scripts\n        run: bash \.github\/scripts\/test_modrinth_scripts\.sh//s' "$base"/.github/workflows/build.yml
  perl -0pi -e "s/\n      - name: smoke test generated templates\n        if: \\\$\\{\\{ hashFiles\\('init\\.sh'\\) != '' \\}\\}\n        run: bash \\.github\\/scripts\\/smoke_template_generation\\.sh//s" "$base"/.github/workflows/build.yml
  rm -f "$base"/.github/scripts/smoke_template_generation.sh
  rm -f "$base"/.github/scripts/test_modrinth_scripts.sh
  rm "$base"/.github/workflows/init.yml
  rm "$(readlink -f "$0")"
)

echo "Refactor completed successfully"
