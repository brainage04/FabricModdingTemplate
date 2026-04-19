#!/bin/bash

usage() {
  echo "Usage: $0 [--side=both|server] <owner> <mod_name>"
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
  both|server)
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
      -e "s/examplemod/$mod_id/g" \
      -e "s/\"ExampleMod\"/\"$mod_name\"/g" \
      -e "s/ExampleMod/$mod_name/g" \
      -e "s/brainage04/$owner/g" \
      -e "s/com\.example/$package_name/g" {} +

  sed -i \
        -e "s/examplemod/$mod_id/g" \
        -e "s/ExampleMod/$mod_name/g" \
        -e "s/brainage04/$owner/g" "$base/build.gradle"

  sed -i \
      -e "s/com\.example/$package_name/g" \
      -e "s/examplemod/$mod_id/g" \
      -e "s/ExampleMod/$mod_name/g" \
      -e "s/brainage04/$owner/g" "$base/gradle.properties"

  sed -i \
        -e "s/brainage04/$owner/g" "$base/LICENSE"

  # refactor accesswidener and mixin file names
  mv "$base"/src/main/resources/examplemod.accesswidener "$base"/src/main/resources/"$mod_id".accesswidener
  mv "$base"/src/main/resources/examplemod.mixins.json "$base"/src/main/resources/"$mod_id".mixins.json

  # refactor assets directory
  mv "$base"/src/main/resources/assets/examplemod "$base"/src/main/resources/assets/"$mod_id"
  mv "$base"/src/client/resources/assets/examplemod "$base"/src/client/resources/assets/"$mod_id"

  # rename main class
  mv "$base"/src/main/java/com/example/ExampleMod.java "$base"/src/main/java/com/example/"$mod_name".java
  mv "$base"/src/test/java/com/example/ExampleModMetadataTest.java "$base"/src/test/java/com/example/"$mod_name"MetadataTest.java
  mv "$base"/src/gametest/java/com/example/ExampleModGameTest.java "$base"/src/gametest/java/com/example/"$mod_name"GameTest.java
  mv "$base"/src/gametest/java/com/example/ExampleModClientGameTest.java "$base"/src/gametest/java/com/example/"$mod_name"ClientGameTest.java
  if [ "$side" = "both" ]; then
    mv "$base"/src/client/java/com/example/ExampleModClient.java "$base"/src/client/java/com/example/"$mod_name"Client.java
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

  if [ "$side" = "both" ]; then
    mkdir -p "$base"/src/client/java/"$package_dir"
    mv "$base"/src/client/java/com/example/* "$base"/src/client/java/"$package_dir"
    rmdir "$base"/src/client/java/com/example
    rmdir --ignore-fail-on-non-empty "$base"/src/client/java/com
  else
    perl -0pi -e 's/,\n\t\t"client": \[\n\t\t\t"[^"]+"\n\t\t\]//s' "$base"/src/main/resources/fabric.mod.json
    perl -0pi -e 's/,\n\t\t"fabric-client-gametest": \[\n\t\t\t"[^"]+"\n\t\t\]//s' "$base"/src/gametest/resources/fabric.mod.json
    sed -i \
      -e '/splitEnvironmentSourceSets()/d' \
      -e '/sourceSet sourceSets.client/d' \
      -e 's/enableClientGameTests = true/enableClientGameTests = false/' "$base"/build.gradle
    perl -0pi -e 's/, client-only code in `src\/client`//g' "$base"/README.md
    sed -i '/runClient/d' "$base"/README.md
    sed -i '/runClientGameTest/d' "$base"/README.md
    rm -f "$base"/src/gametest/java/"$package_dir"/"$mod_name"ClientGameTest.java
    rm -rf "$base"/src/client
  fi

  rm "$base"/.github/workflows/init.yml
  rm "$(readlink -f "$0")"
)

echo "Refactor completed successfully"
