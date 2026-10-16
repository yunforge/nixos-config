# Third-party notices / Acknowledgements

The root MIT license covers original configuration, documentation and standalone additions only. Upstream components and derivative files retain their own licenses and notices. Copyright belongs to the respective upstream authors.

| Component / local files | Source | License |
| --- | --- | --- |
| uosc 5.13.0, `scripts/uosc/` (except independent additions), `fonts/uosc_textures.ttf` | https://github.com/tomasklaen/uosc/tree/5.13.0 | GNU LGPL 2.1, see `LICENSES/uosc-LGPL-2.1.txt` |
| `scripts/uosc/lib/fzy.lua` | Seth Warn / upstream uosc | MIT, copyright and full notice retained in the file |
| `scripts/thumbfast.lua` | https://github.com/po5/thumbfast | MPL 2.0, `LICENSES/thumbfast.txt`; source notice retained |
| `fonts/CupertinoIcons.ttf` | https://github.com/flutter/packages/tree/main/third_party/packages/cupertino_icons | MIT, `LICENSES/CupertinoIcons.txt` |
| Cupertino name/codepoint data in `scripts/uosc/lib/cupertino.lua` | https://github.com/flutter/flutter/blob/master/packages/flutter/lib/src/cupertino/icons.dart | Flutter BSD 3-Clause, `LICENSES/Flutter-BSD-3-Clause.txt` |
| `scripts/stats.lua` (unmodified mpv upstream copy) | https://github.com/mpv-player/mpv/blob/master/player/lua/stats.lua | mpv GPL 2.0-or-later distribution terms; see `LICENSES/mpv-Copyright.txt`, `LICENSES/mpv-GPL-2.0.txt` and `LICENSES/mpv-LGPL-2.1.txt` for upstream licensing distinctions |
| MacTahoe traffic-light SVGs and derived button geometry/colors | https://github.com/vinceliuice/MacTahoe-gtk-theme | MIT, WhiteSur Developers notice in `LICENSES/MacTahoe.txt` |

Local uosc modifications (2026-09-29, StatIndet): Cupertino rendering in `lib/ass.lua`, right-button dispatch in `lib/cursor.lua`, and custom layout/rendering in `elements/Controls.lua`, `Speed.lua`, `Timeline.lua`, `TopBar.lua`. These derivative files remain under the uosc license. Their complete editable source is included.

Independent additions: `scripts/seek_feedback.lua` and `scripts/uosc/lib/hold_speed.lua` are MIT. The Cupertino mapping module combines original alias glue with the attributed Flutter icon data.

Platform-specific ziggy binaries and the unused Material icon font are not distributed by this repository. See README for installing upstream helpers. Local backup archives are also excluded.

Thank you to all upstream maintainers and contributors who make this configuration possible.
