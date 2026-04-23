# Modrinth publishing

This template includes an optional Modrinth publishing workflow in `.github/workflows/modrinth.yml`.

It runs when a GitHub release is published and does two things:

1. Creates the Modrinth project if a project with slug `mod_id` does not already exist.
2. Uploads the built release jar as a Modrinth version if that `mod_version` has not already been uploaded.

The workflow is skipped unless the repository has a `MODRINTH_TOKEN` secret configured.

## Required secret

Create a Modrinth personal access token and add it as a repository secret to the GitHub repository as `MODRINTH_TOKEN`.

Minimum useful scopes:

- `PROJECT_CREATE`
- `VERSION_CREATE`

The workflow uses the Modrinth API directly:

- Project creation: `POST /project`
- Version upload: `POST /version`

## Project metadata

The workflow reads:

- `src/main/resources/fabric.mod.json` for the project slug, title, description, contact links, licence, and side support inference
- `README.md` for the long project description
- `.modrinth/project.json` for optional Modrinth-specific overrides
- `gradle.properties` for `mod_version` and `minecraft_version`

Defaults:

- The Modrinth slug is `fabric.mod.json.id`
- The project is created as `draft`
- The GitHub repo URL is used when `fabric.mod.json.contact.sources` is absent
- The GitHub issues URL is used when `fabric.mod.json.contact.issues` is absent
- `fabric` is used as the default loader/category when no override is supplied
- `discord_url` is always set to `https://discord.gg/N4zfhBx8Fm`

In practice, `.modrinth/project.json` can be kept very small. The template only needs it when you want to override defaults such as:

- `categories`
- `additional_categories`

Valid values for `categories` and `additional_categories` are as follows:

- `adventure`
- `cursed`
- `decoration`
- `economy`
- `equipment`
- `food`
- `game-mechanics`
- `library`
- `magic`
- `management`
- `minigame`
- `mobs`
- `optimization`
- `social`
- `storage`
- `technology`
- `transportation`
- `utility`
- `worldgen`

`additional_categories` uses the same values as `categories`; the difference is that they are searchable but not shown as primary display categories.

If you do not need any overrides, you can remove `.modrinth/project.json` entirely and the workflow will fall back to defaults.

## Side support defaults

Side support is inferred from `fabric.mod.json`:

- `environment=client`: `client_side=required`, `server_side=unsupported`
- `environment=server`: `client_side=unsupported`, `server_side=required`
- `environment=*` with a client entrypoint: `client_side=optional`, `server_side=optional`
- `environment=*` without a client entrypoint: `client_side=unsupported`, `server_side=required`

You can still override the inferred values in `.modrinth/project.json` if needed.

## Release notes

The Modrinth changelog is taken from the GitHub release body. See [RELEASE.md](RELEASE.md) for more info.

## Notes

- The workflow uploads the main release jar from `build/libs` and ignores `*-dev.jar` and `*-sources.jar`.
- If the Modrinth project already exists, it is reused instead of recreated.
- If the Modrinth version already exists for the current `mod_version`, publishing is skipped.
