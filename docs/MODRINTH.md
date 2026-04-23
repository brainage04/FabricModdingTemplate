# Modrinth publishing

This template includes an optional Modrinth publishing workflow in `.github/workflows/modrinth.yml`.

It runs when a GitHub release is published and does two things:

1. Creates the Modrinth project if a project with slug `mod_id` does not already exist.
2. Uploads the built release jar as a Modrinth version if that `mod_version` has not already been uploaded.

The workflow is skipped unless the repository has a `MODRINTH_TOKEN` secret configured.

## Required secret

Create a Modrinth personal access token and add it to the GitHub repository as `MODRINTH_TOKEN`.

Minimum useful scopes:

- `PROJECT_CREATE`
- `VERSION_CREATE`

The workflow uses the Modrinth API directly:

- Project creation: `POST /project`
- Version upload: `POST /version`

## Project metadata

The workflow reads:

- `.modrinth/project.json` for project and version metadata
- `.modrinth/body.md` for the long project description
- `gradle.properties` for `mod_id`, `mod_name`, `mod_description`, `mod_license`, and `minecraft_version`

Defaults:

- The Modrinth slug is `mod_id`
- The project is created as `draft`
- The GitHub repo URL is used for `source_url`
- The GitHub issues URL is used for `issues_url`
- `fabric` is used as the default loader/category

## Side support defaults

The template adjusts `.modrinth/project.json` during `init.sh`:

- `--side=both`: `client_side=optional`, `server_side=optional`
- `--side=server`: `client_side=unsupported`, `server_side=required`
- `--side=client`: `client_side=required`, `server_side=unsupported`

You can edit these values after initialisation if your real compatibility story differs.

## Release notes

The Modrinth changelog is taken from the GitHub release body.

With the current release flow, that means:

1. Create an annotated git tag such as `git tag -a v1.2.3 -F RELEASE_NOTES.md`
2. Push the tag
3. Let the release workflow create the GitHub release
4. Let the Modrinth workflow reuse the same notes as the version changelog

## Notes

- The workflow uploads the main release jar from `build/libs` and ignores `*-dev.jar` and `*-sources.jar`.
- If the Modrinth project already exists, it is reused instead of recreated.
- If the Modrinth version already exists for the current `mod_version`, publishing is skipped.
