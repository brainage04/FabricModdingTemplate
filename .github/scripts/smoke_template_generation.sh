#!/usr/bin/env bash

set -euo pipefail

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

copy_template() {
  local target="$1"

  mkdir -p "$target"
  tar \
    --exclude=.git \
    --exclude=.gradle \
    --exclude=build \
    --exclude=run \
    --exclude='.init-package-tree.*' \
    -C "$template_root" \
    -cf - . \
    | tar -C "$target" -xf -
}

assert_path_exists() {
  local path="$1"

  if [ ! -e "$path" ]; then
    echo "Expected path to exist: $path" >&2
    exit 1
  fi
}

assert_path_missing() {
  local path="$1"

  if [ -e "$path" ]; then
    echo "Expected path to be absent: $path" >&2
    exit 1
  fi
}

assert_no_match() {
  local pattern="$1"
  shift

  if rg -n "$pattern" "$@" >/tmp/template-smoke-rg.out; then
    cat /tmp/template-smoke-rg.out >&2
    exit 1
  fi
}

smoke_side() {
  local side="$1"
  local target="$tmp_root/$side/Smoke-Template.${side}_42"
  local package_dir="io/github/brain_age_04/smoke_template_${side}_42"
  local package_name="io.github.brain_age_04.smoke_template_${side}_42"
  local main_class="SmokeTemplate${side^}42"
  local -a build_args

  echo "Testing init.sh --side=${side}"
  copy_template "$target"

  (
    cd "$target"

    ./init.sh --side="$side" "brain-age-04" "Smoke-Template.${side}_42"

    assert_path_missing "init.sh"
    assert_path_missing ".github/workflows/init.yml"
    assert_path_exists "src/main/java/${package_dir}/${main_class}.java"
    assert_path_exists "src/test/java/${package_dir}/${main_class}MetadataTest.java"
    assert_path_exists "src/main/resources/smoke_template_${side}_42.accesswidener"
    assert_path_exists "src/main/resources/smoke_template_${side}_42.mixins.json"
    assert_path_exists "src/main/resources/assets/smoke_template_${side}_42/icon.png"

    if [ "$side" = "server" ]; then
      assert_path_missing "src/client"
      assert_path_missing "src/gametest/java/${package_dir}/${main_class}ClientGameTest.java"
    else
      assert_path_exists "src/client/java/${package_dir}/${main_class}Client.java"
      assert_path_exists "src/gametest/java/${package_dir}/${main_class}ClientGameTest.java"
      assert_path_exists "src/client/resources/assets/smoke_template_${side}_42/lang/en_us.json"
    fi

    if [ "$side" = "client" ]; then
      assert_path_missing "src/gametest/java/${package_dir}/${main_class}GameTest.java"
      build_args=(build runClientGameTest)
    elif [ "$side" = "server" ]; then
      build_args=(build)
    else
      assert_path_exists "src/gametest/java/${package_dir}/${main_class}GameTest.java"
      build_args=(build runClientGameTest)
    fi

    grep -qx "maven_group=${package_name}" gradle.properties
    assert_no_match 'com\.example|FabricTemplateServer|fabrictemplateserver' README.md build.gradle gradle.properties LICENSE src
    assert_no_match 'io\.github\.brain-age-04|package [^;]*-' src

    if [ "${TEMPLATE_SMOKE_SKIP_BUILD:-false}" = "true" ]; then
      echo "Skipping generated ${side} Gradle build."
    else
      ./gradlew --no-daemon "${build_args[@]}"
    fi
  )
}

require_command rg
require_command tar

template_root="$(cd "$(dirname "$0")/../.." && pwd)"
tmp_root="${TMPDIR:-/tmp}/fabric-template-smoke.$$"
trap 'rm -rf "$tmp_root" /tmp/template-smoke-rg.out' EXIT

smoke_side both
smoke_side server
smoke_side client

echo "Template generation smoke tests passed."
