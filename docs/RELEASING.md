# Releasing

GitHub Actions is the only publisher. A release begins when a `vX.Y.Z` tag is
pushed; the workflow rejects any tag whose version does not match
`config.json`.

Before the first release, configure the repository at **Settings → Secrets and
variables → Actions**:

| Kind | Name | Value |
| --- | --- | --- |
| Secret | `NEXUSMODS_API_KEY` | A newly generated Nexus Mods API key |
| Variable | `NEXUSMODS_FILE_ID` | The current main file's **Group ID** |

The action calls this identifier `file_id`, while Nexus labels it **Group ID**
in API Info. It identifies the existing main file that receives each new
version. It is deliberately a repository variable rather than a secret. Find
it through **API Info** for the current main file in the mod's Files or Manage
Files view. `56494` in the supplied `/mods/56494` URL is the mod-page ID, not
the required Group ID. At the time this was configured, the current 1.0.23
main file's Group ID is `7712997`.

To create a release from a clean, up-to-date branch:

```bash
./dev.sh deploy --version 1.0.24 --message "Short description of the changes"
```

The script updates `config.json` and `CHANGELOG.md`, creates a `Release
vX.Y.Z` commit, pushes it, and then pushes the tag. The tag workflow then:

1. checks that the tag, `config.json`, and newest changelog section agree;
2. runs Lua syntax checks and every `tests/*_test.lua` test;
3. creates one ZIP from `config.json`'s `packaging.includes` manifest and
   injects the declared `packaging.generated.buildInfo` module, then verifies
   the exact contents;
4. uploads a new Nexus Mods version using the newest changelog entry as its
   description, archives the previous version, and marks the new download as
   the primary mod-manager download;
5. creates the GitHub release only after the Nexus upload succeeds.

For a non-release build, pushes and pull requests create a verified artifact
with a `dev-<commit>` version and never call Nexus Mods. The package-only build
metadata is displayed at the top of the mod's Settings page. A direct source
checkout instead displays `Development build (source checkout)`.

Nexus's upload action does not expose an API operation for editing or pinning a
mod-page post, so the sticky changelog post remains a manual update.

The mod-page **Description** is also a manual update. Its canonical BBCode is
maintained in [`NEXUS_DESCRIPTION.bbcode`](NEXUS_DESCRIPTION.bbcode); copy it
into Nexus when the feature description changes. The workflow's `description`
field applies only to the newly uploaded file version.
