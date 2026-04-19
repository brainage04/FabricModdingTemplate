# About

My template for Minecraft Fabric mods, with common code in `src/main`, client-only code in `src/client`, and GameTests in `src/gametest`. The easiest way to use this is to click `Use this template` and GitHub Actions will take care of the rest for you.

However, if you are using a Linux-based operating system, it is possible to clone this repository, and perform a refactor by triggering the `init.sh` script like so:

```shell
./init.sh [--side=both|server|client] <owner> <mod_name>
```

Where `<owner>` is your GitHub username and `<mod_name>` is your GitHub repository name/mod name.
The optional `--side` flag defaults to `both`.
Use `--side=server` to generate a server-only repo and remove the client entrypoint/source set from the generated project.
Use `--side=client` to generate a client-only repo and remove the dedicated-server GameTest path from the generated project.

This script is designed to work both with GitHub Actions and manual usage, and will safely delete:
  - Leftover unused folders that are not tracked by Git (such as `src/main/java/com/example`, `src/client/java/com/example`, and `src/main/resources/examplemod`).
  - The `init` workflow and script after successful execution.

For local development after initialisation:
  - `./gradlew runServer` launches the common/server side when you keep `--side=both` or choose `--side=server`.
  - `./gradlew runClient` launches the client side when you keep `--side=both` or choose `--side=client`.
  - Mod Menu is included as a development dependency and a minimal `modmenu` entrypoint is kept in the generated mod metadata so you can test the integration during local client development without having to re-add it by hand.

# Testing

Run:

```shell
./gradlew test
```

The template includes example tests under `src/test/java` that show two useful patterns:
  - Fabric-aware tests that boot Fabric Loader and inspect loaded mod metadata.
  - Plain unit tests for your own code, such as command registration.

For integration-style server tests, run:

```shell
./gradlew runGameTest
```

The template includes a separate `src/gametest` source set with a minimal server GameTest that checks the example command was registered on the server.
Server GameTests also run automatically as part of `./gradlew build`, which is what the included GitHub Actions workflow executes.

For client-side GameTests, run:

```shell
./gradlew runClientGameTest
```

The template also includes a minimal client GameTest that opens a singleplayer world and checks that the client and integrated server are both reachable from the test context.
When you initialise with `--side=client`, the generated repo keeps this client GameTest path and removes the dedicated-server GameTest path.

# Credits

Thank you to [nea89o](https://github.com/nea89o)
for developing the GitHub Actions [workflow](https://github.com/nea89o/Forge1.8.9Template/blob/master/.github/workflows/init.yml)
and [script](https://github.com/nea89o/Forge1.8.9Template/blob/master/make-my-own.sh)
from which I based my workflow and script off of.
