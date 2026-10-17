# Notice

ProjectFit is an independent, open-source project licensed under the GNU Affero General
Public License version 3 (see `LICENSE`).

## Based on OpenStrap

ProjectFit is a modified version of [OpenStrap](https://github.com/OpenStrap):

| ProjectFit folder | Upstream repository | Upstream commit |
|---|---|---|
| `app/` | `OpenStrap/edge` | `1f1025ad98f19972c26a80756ae38b03a421b92c` |
| `packages/protocol/` | `OpenStrap/protocol` | `89080bcfac7767b3a871fd3a7d9307f5f30dad26` |
| `packages/analytics/` | `OpenStrap/analytics` | `77fe373eb819fda235f80610e898a4bc20a7a249` |

Copyright (c) 2026 OpenStrap and its contributors. Licensed under AGPL-3.0.

The upstream `edge` code was MIT-licensed up to commit
`1140dac1508397ad9ccd2c36396b7209d30044c4` and AGPL-3.0 after it. ProjectFit is based on
a later commit, so the AGPL-3.0 applies.

Changes made in ProjectFit (see the git history for every change):

- Renamed to ProjectFit, with new identifiers, app icon and illustrations. The
  OpenStrap name and logo are the upstream project's marks and are not used.
- Combined the three upstream repositories into one, with path dependencies.
- Removed the upstream project's Firebase configuration, issue-report service and
  key, community links and sponsor prompts. Those now default to off.

ProjectFit is not affiliated with, endorsed by, or supported by OpenStrap.

## Not affiliated with device makers

ProjectFit is not affiliated with, sponsored by, or endorsed by WHOOP, Inc., Garmin Ltd.,
or any other device maker. Product names are used only to say which devices the app
works with. No WHOOP or Garmin source code, binaries, firmware, or copyrighted assets
are included in this repository.

## wger exercise data

`app/lib/ui2/activity/wger_exercises.g.dart` contains selected fields (names, aliases,
muscles, equipment, categories) from the [wger](https://wger.de) exercise database,
limited to the movements listed in `app/tool/wger_weightlifting_selection.dart`. Each
entry is available under CC BY-SA 3.0, CC BY-SA 4.0 or CC0, and each row keeps its
source UUID and the author/license credits of its base data and translations. This
data stays under those licenses, separate from the AGPL-licensed code.
