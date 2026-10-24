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

## Body map shapes

`app/lib/ui2/body_map_data.dart` contains the anterior and posterior muscle polygons from
[react-body-highlighter](https://github.com/giavinh79/react-body-highlighter) 2.0.5,
under the MIT License:

> MIT License
>
> Copyright (c) 2020 GV79
>
> Permission is hereby granted, free of charge, to any person obtaining a copy of this
> software and associated documentation files (the "Software"), to deal in the Software
> without restriction, including without limitation the rights to use, copy, modify,
> merge, publish, distribute, sublicense, and/or sell copies of the Software, and to
> permit persons to whom the Software is furnished to do so, subject to the following
> conditions:
>
> The above copyright notice and this permission notice shall be included in all copies
> or substantial portions of the Software.
>
> THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
> INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A
> PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
> HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF
> CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE
> OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
