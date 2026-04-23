#!/bin/bash

usage() {
  echo "Usage: $0 [--side=both|server|client] <owner> <mod_name>"
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
      if [ -z "$2" ]; then
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
mod_name="${positionals[1]}"
mod_name_spaces=$(
  printf '%s\n' "$mod_name" \
  | sed -E 's/([A-Z])/ \1/g' \
  | sed -E 's/^ //'
)
mod_id=$(
  printf '%s\n' "$mod_name_spaces" \
  | tr 'A-Z' 'a-z' \
  | tr ' ' '_'
)
package_name="com.github.${owner,,}.${mod_id,,}"
package_dir=$(echo "$package_name" | tr . /)

echo "Setting owner to $owner"
echo "Setting mod name to $mod_name ($mod_name_spaces)"
echo "Setting mod id to $mod_id"
echo "Setting side to $side"
echo "Setting package name to $package_name"
echo "Setting package dir to $package_dir"

(
  # enable debug tracing
  set -x

  find_paths=(
    "$base/src/main"
    "$base/src/test"
    "$base/src/gametest"
    "$base/src/client"
  )

  # refactor mod id, mod name, owner and package name strings
  # important that owner is done before package name
  # as owner may or may not be in the package name string
  # which will cause issues if replaced
  find "${find_paths[@]}" -type f -exec sed -i \
      -e "s/fabrictemplateserver/$mod_id/g" \
      -e "s/FabricTemplateServer/$mod_name/g" \
      -e "s/brainage04/$owner/g" \
      -e "s/com\.example/$package_name/g" {} +

  sed -i \
        -e "s/fabrictemplateserver/$mod_id/g" \
        -e "s/FabricTemplateServer/$mod_name/g" \
        -e "s/brainage04/$owner/g" "$base/build.gradle"

  sed -i \
      -e "s/com\.example/$package_name/g" \
      -e "s/fabrictemplateserver/$mod_id/g" \
      -e "s/FabricTemplateServer/$mod_name/g" \
      -e "s/brainage04/$owner/g" "$base/gradle.properties"

  sed -i \
      -e "s/fabrictemplateserver/$mod_id/g" \
      -e "s/FabricTemplateServer/$mod_name/g" \
      -e "s/brainage04/$owner/g" "$base/README.md"

  sed -i \
        -e "s/brainage04/$owner/g" "$base/LICENSE"

  # refactor accesswidener and mixin file names
  mv "$base"/src/main/resources/fabrictemplateserver.accesswidener "$base"/src/main/resources/"$mod_id".accesswidener
  mv "$base"/src/main/resources/fabrictemplateserver.mixins.json "$base"/src/main/resources/"$mod_id".mixins.json

  # refactor assets directory
  mv "$base"/src/main/resources/assets/fabrictemplateserver "$base"/src/main/resources/assets/"$mod_id"
  mv "$base"/src/client/resources/assets/fabrictemplateserver "$base"/src/client/resources/assets/"$mod_id"

  # rename main class
  mv "$base"/src/main/java/com/example/FabricTemplateServer.java "$base"/src/main/java/com/example/"$mod_name".java
  mv "$base"/src/test/java/com/example/FabricTemplateServerMetadataTest.java "$base"/src/test/java/com/example/"$mod_name"MetadataTest.java
  mv "$base"/src/gametest/java/com/example/FabricTemplateServerGameTest.java "$base"/src/gametest/java/com/example/"$mod_name"GameTest.java
  mv "$base"/src/gametest/java/com/example/FabricTemplateServerClientGameTest.java "$base"/src/gametest/java/com/example/"$mod_name"ClientGameTest.java
  if [ "$side" != "server" ]; then
    mv "$base"/src/client/java/com/example/FabricTemplateServerClient.java "$base"/src/client/java/com/example/"$mod_name"Client.java
  fi

  # lastly, refactor package directory
  mkdir -p "$base"/src/main/java/"$package_dir"
  mv "$base"/src/main/java/com/example/* "$base"/src/main/java/"$package_dir"
  rmdir "$base"/src/main/java/com/example
  rmdir --ignore-fail-on-non-empty "$base"/src/main/java/com

  mkdir -p "$base"/src/test/java/"$package_dir"
  mv "$base"/src/test/java/com/example/* "$base"/src/test/java/"$package_dir"
  rmdir "$base"/src/test/java/com/example
  rmdir --ignore-fail-on-non-empty "$base"/src/test/java/com

  mkdir -p "$base"/src/gametest/java/"$package_dir"
  mv "$base"/src/gametest/java/com/example/* "$base"/src/gametest/java/"$package_dir"
  rmdir "$base"/src/gametest/java/com/example
  rmdir --ignore-fail-on-non-empty "$base"/src/gametest/java/com

  if [ "$side" != "server" ]; then
    mkdir -p "$base"/src/client/java/"$package_dir"
    mv "$base"/src/client/java/com/example/* "$base"/src/client/java/"$package_dir"
    rmdir "$base"/src/client/java/com/example
    rmdir --ignore-fail-on-non-empty "$base"/src/client/java/com
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
