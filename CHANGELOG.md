# Changelog

All notable changes to Worth Remembering are documented here.

## [1.0.1] - 2026-11-10

### Added
- Directed Emotes (Options > Auto-Track) are now your own list of rules instead of a fixed Wave/Thank/Bow: each rule logs when another player's emote contains a phrase you choose (e.g. "salute" or "cheers at you"), with its own rep gain, note, and cooldown. Add up to 20, remove any. A "Must say 'you'" checkbox per rule (on by default) skips emotes not aimed at you; turn it off for game languages that don't use the word "you". Your existing Wave/Thank/Bow settings carry over as the first three rules.
- New "Require a mouseover" option for auto-adding nearby players (Options > Auto-Track > Nearby Players): when checked, only players you mouse over get auto-added, instead of every player whose nameplate shows up.
- New "Featured Note" choice for the tooltip (Options > General > Tooltip & Context Menu, off by default): shows one of the player's featured notes at random, in quotes, like the quote on the Details tab. It picks once each time the tooltip appears, so it doesn't flicker between notes while you hover. Long notes are cut short, and with Last Note also on, it won't repeat the same note twice.

### Fixed
- Right-clicking the minimap icon opened its menu, but none of the menu's options did anything when the icon had been collected into a minimap button bag (like EllesmereUI's).
- Whispering a notable player from their name in chat (right-click > Whisper, or clicking the name) put their standing tag, like "[+2]", into the whisper target, so the whisper failed. The tag now only changes the name you see.

## [1.0] - 2026-11-04

This is a huge update! There are bound to be bugs, please don't hesitate to report them! Discord, email, curseforge comments, and github issues all work to get in touch with me.
I worked hard to get this ready for WoW: Forever's launch, and tested a lot on Retail. While Retail and Forever share an API, it's very possible some stuff is broken on Forever, so please please report anything you find, and I will be in immediately on launch to test things myself and will get any necessary patching out ASAP.

Hope y'all are as excited to meet some people worth remembering as I am! See you in Azeroth!

### Highlights
- Now also supports retail WoW, alongside Forever.
- Recent Allies tracking: automatically log the people you run dungeons, raids, delves, battlegrounds, duels, and trades with, straight from the game's own Recent Allies history.
- Duel tracking, with your own wording for wins and losses.
- Bracket color sets, including Colorblind-Friendly, plus fully custom colors (and labels) with a one-click reset to any built-in set.
- Drag table column headers to reorder columns, with a live preview as you drag.
- More specific entry sources (Manual, Survey, General, Emote, Instance, Allies, Nearby), filterable on the History tab.
- The survey now has its own Options tab, and Auto-Track is reorganized into collapsible sections.
- Up to 8 presets per radial, and a new "Everything" mode when using two radials.
- "Reset UI" and "Reset All Options" buttons, patch notes that open once after each update, and a big performance pass for large databases.

### Added
- Retail WoW support: the addon now loads on the retail client as well as Forever, including retail's multi-word race names (Blood Elf, Kul Tiran, etc).
- Players' body type is now tracked, in a new column right before Race on the Players tab (their most recently seen one) and the History tab (theirs at the time of each entry). You can filter by it (including Unknown, for players it hasn't been seen for yet) from a new dropdown next to Class on both tabs, or by clicking a cell. Options > General > Main lets you choose how it's shown (Male/Female or 1/2) and what it's called (Body Type or Sex), which the column and filter both follow.
- Two new dropdowns in Options > General > Global Hotkey: "With a target, open" and "While hovering, open", each choosing Quick-Note / History Tab / Details Tab. Replaces the old hardcoded "always Quick-Note" tap behavior, and applies to the radial quick-add menu's tap as well, not just a plain tap.
- New "Tooltip & Context Menu" section in Options > General: a checkbox to show (or fully disable) Worth Remembering info in notable players' tooltips, with a multiselect for which fields to show (Rating, Bracket, Last Note, Times Seen, Note Count), and a separate checkbox to disable the right-click "Worth Remembering" menu entirely.
- New "Recent Allies" section in Options > Auto-Track: logs entries from the game's own Recent Allies history (dungeon completions, raid boss kills, delves, battlegrounds, arenas, duels, trades, fighting together, and more). Pick which kinds count, set a rep gain, note, and cooldown. The game only hands this data over when you open its Recent Allies tab or log in, so entries arrive in batches, dated to when each interaction actually happened (a batch only plays the new-entry sound once). Only interactions from after it's turned on are logged.
- New "Dueled" Auto-Track trigger, logged when a duel you're in ends. Its note supports a new {{duelresult}} placeholder that becomes your own Victory or Loss text ("beat them"/"lost to them" by default, editable for any wording or language). Fleeing counts as losing.
- A "Colors" dropdown next to the bracket label Preset in Options > Reputation: Green & Red, Cool & Warm, Colorblind-Friendly, or Custom. Editing any color swatch switches to Custom and saves your set, so picking Custom again later brings it back. The neutral bracket now has its own color swatch too. Standing-change colors (the +/- numbers in History and Details, and the Statistics totals) follow the chosen color set too, instead of always green/red. When either the labels or colors are set to Custom, a "Reset custom ... to:" dropdown appears under it, to replace your custom set with one of the built-in ones (asks first).
- A "Show patch notes for new versions" checkbox on the About tab (on by default): after updating, the window opens to the About tab once, with every version you missed expanded (no matter how many you skipped, it only opens once). A first-time install just shows the newest version.
- A short welcome message on the About tab, and contact info for feedback, bug reports, and feature requests in its top right. The email and Discord name can be selected and copied.
- Table columns can be rearranged: drag a column header left or right to move it, and the columns rearrange live as you drag, with the one you're holding highlighted. Your order is saved per table, and Options > General > Danger Zone > Reset UI puts it back. Clicking a header still sorts.
- The Quick-Add, Edit Entry, and Dungeon/Raid Survey windows now remember where you dragged them, across reloads and logins.
- Two new buttons in Options > General > Danger Zone: "Reset UI" (every window's position, size, scale, opacity, and visibility, column widths/visibility/order, the Nearby window's layout, the minimap button, and the nameplate icon's size/offset) and "Reset All Options" (every option back to its default, your players, notes, and standings are kept). Both ask first and reload your UI.

### Changed
- Performance: the History and Statistics tabs no longer rebuild themselves in the background while you're on another tab (or the window is closed); they refresh when you switch to them. Sorting a table is cheaper, refreshes triggered many times at once (a whole party logged, a crowd of nameplates appearing) now run once, and party-member checks for the Nearby window are cached.
- Narrower default column widths on the Players and History tabs, so more columns fit in a smaller window.
- The main window's first-open size now fits your screen (about 70% of the available space, always a 16:9 shape, between 960x540 and 1440x810) instead of a fixed size.
- The bracket ranges on Options > Reputation now show the real ranges for your neutral band (e.g. neutral -3 to 3, then 4 to 25 and -4 to -25), and update as you change it. Negative ranges read from the mild end outward ("-4 to -25" rather than "-25 to -4").
- New "Single click" and "Double click" options for the Nearby window's rows (Options > General > Nearby Window): each opens Details, Quick-Add, or Nothing (defaults: Quick-Add and Details, as before). A "Double-click speed" setting next to them (300ms by default, was a fixed 400ms) controls how quickly a second click has to follow; with double click set to Nothing, a single click responds instantly.
- The Nearby window's title now shows how many players it's listing, e.g. "WR - Nearby (3)", so a short window that only fits one row still tells you there's more to scroll to.
- New Width and Height sliders for the Nearby window (Options > General > Nearby Window), and it can now be made smaller (down to 125 wide and 55 tall). They stay in sync with dragging the window's resize grip. Width now also applies when the window auto-sizes; Height only applies with a static size (auto-sizing sets its own height), so it grays out otherwise.
- "Use a fixed, resizable size" is now "Use a static, resizable size", and the Nearby window's "Visible row limit" setting grays out while it's on, since it doesn't apply then.
- Every box on Options > General and Options > Auto-Track is now collapsible (including the Danger Zone), all starting collapsed, and collapsible boxes everywhere toggle from a +/- button at the start of their title instead of a separate "Show settings" line.
- The main window's default opacity is now 100%, and Options > General's "Window" box is now called "Main".
- Options > Auto-Track is reorganized: "Auto-Add" is renamed "General" and is now collapsible, Directed Emotes (Wave/Thank/Bow) moved to its own collapsible box, and the placeholder help button now sits on its own "[?] Notes" line under "Enable auto-add module", since it applies to every note on that tab.
- The dungeon/raid survey and its presets moved from Auto-Track to their own new Survey tab in Options, since the survey is filled out by hand.
- "Enable auto-add module" now covers every automatic entry: dungeon/raid auto-logging, Recent Allies, and auto-adding nearby players now also turn off with it. The survey isn't affected.
- The "Enable auto-add module" and "[?] Notes" lines now scroll with the rest of the Auto-Track tab instead of staying pinned at the top.
- Mouse-wheel scrolling moves half as far per click (a quarter of the visible area instead of half), in Options, the tables, Statistics, the About tab, the Nearby window, and the survey.
- "Questing together" is now "Quested together", matching the other triggers.
- The radial quick-add menu now allows up to 8 presets per radial (was 5).
- New "Character name color" option (Options > Radial Menu): show the player's name above the radial in their class color (default) or their bracket color.
- With two radials enabled, a new "Multiple radial behavior" dropdown (Options > Radial Menu) chooses between Positive/Negative (radial 1 gets presets that add rep, radial 2 ones that take it away, as before) and Everything (either radial can hold any preset). Each choice keeps its own preset selections. Holding the key for a second radial with no presets picked yet opens it with a hint instead of acting like a tap.
- Survey "role presets" are now just "Survey Presets".
- Removed the "Note and/or standing delta - fill either or both" line from the Quick-Add window.
- New-install defaults for 1.0: every Auto-Track General trigger is on (Partied, Rezzed, Quested together, Buffed me, Dueled); dungeon/raid auto-logging is on, logging when a run starts ("Started {{loc}} together.", +2); Recent Allies is on, also counting duels and trades, with the note "{{interaction}} in {{loc}} at level {{yourlvl}}."; the survey popup is on; "Entry created" chat messages are on; the hotkey with no target opens History; Auto-Prune is on, removing players with no notes and zero standing who haven't been seen in a day; and the Nearby window's opacity is 50% idle and 90% on hover, with a default size of 200 wide (and 125 tall when static).
- Removed "Last Seen" from the tooltip options, since anyone you're hovering has always just been seen.
- Removed "Pet battle" and "Partied/raided" from the Recent Allies kinds (partying is already covered by "Partied with").
- Every Auto-Track trigger's note box is now the same width, with Cooldown always on the same line to its right (including Quested together, whose Cooldown used to sit on its own line).
- The "Partied with" default note is now "Partied in {{loc}}.", and "Buffed me" is now "Buffed me in {{loc}}.".
- Every default quick-add and survey preset text now ends with a period, and there's a new "Loot Ninja" survey preset (-10).
- Default auto-logged notes no longer start with "[Auto]", since each entry's Source already says how it was logged.
- Entry sources are more specific: instead of just Manual/Auto, entries now show Manual, Survey (from the dungeon/raid survey), or for auto-logged ones General, Emote, Instance, Allies, or Nearby, on both the History and Details tabs. Survey entries show in light green, other manual entries in grey, and auto-logged ones in blue. Survey entries saved before this update still show as Manual. History's source filter is now a "Source" dropdown where you can pick any mix of these, with an "All auto" option that toggles every auto source at once.
- "Rezed" is now spelled "Rezzed" everywhere, including the Rezzed Me quick-add preset.
- A player's race is now also saved as the game's own race ID, so it shows in your game's language and the same race can't split into two entries in filters and Statistics after a language change. Existing players pick it up the next time you see them.

### Fixed
- Minimizing the main window shrank it toward the middle of where it was. It now collapses into its top-right corner and restores to the same spot.
- The "WR Rep" line in player tooltips didn't use your bracket colors.
- Nearby window: the title could crowd the close button, a scrollbar's worth of space was reserved even with nothing to scroll, the resize grip drifted away from the cursor while dragging, the window could be shrunk small enough for its text to overlap, and in a very short window the scrollbar's up arrow poked into the header under the close button (it now hides until there's room for it; the mouse wheel still scrolls).
- Two-word races like Blood Elf, Night Elf, or Kul Tiran were cut down to their last word ("Elf"). Players already saved that way are corrected the next time you see them.
- Auto-Prune's "Not seen in X days" treated a player with no date at all as long gone, so a player you'd just opened Quick-Note on (then closed without saving) could be pruned on the next login. Players now count as seen when first added, and one with no date at all is never pruned for it.
- Saving a survey played the new-entry sound once per player saved (loud with a full party, very loud with a raid). It now plays once per save, and only if anything was saved. The same goes for dungeon/raid auto-logging, "Quested together", and Recent Allies, which also log a whole group at once.
- The Players tab's bracket filter kept showing old bracket names after renaming them or switching label presets, until a reload.
- On the "fill out the survey?" prompt, "Don't ask me again" + Skip turned surveys off entirely instead of just skipping the prompt from then on. It now always means "skip the prompt" (the same as the Survey tab's checkbox), and a new "Disable instance surveys" checkbox turns surveys off. The prompt also has a bit more breathing room.
- Selected text stayed highlighted in a text box after clicking away, so several boxes could show a selection at once. Clicking away now clears it, and double-clicking a box selects everything in it.
- Small input boxes' borders could vanish along one edge after scrolling an Options tab.
- Unchecking "Show one-click preset buttons in the quick-add popup" also emptied the radial menu and grayed out the preset list. It now only hides the popup's buttons; the presets stay editable and the radial keeps using them.
- The Quick-Add window kept whatever you'd typed (note, rep, featured) after closing it without saving, and showed it again for the next player. It now clears on close, and when switching to a different player.

## [0.5.11] - 2026-10-21

### Fixed
- Left clicks could get completely blocked everywhere until a right click, if the radial quick-add menu's invisible cancel-catcher got stuck enabled. Any click now closes it immediately instead of only a right click or Escape.

## [0.5.10] - 2026-10-20

### Fixed
- Dying in a dungeon/raid and releasing to the graveyard could trigger the completion auto-log and survey prompt mid-run, since it looks the same as actually leaving.

## [0.5.9] - 2026-10-20

### Fixed
- The "Buffed me" Auto-Track trigger could log an entry crediting yourself when a buff you applied to yourself (a racial, trinket, enchant, food, etc) had no one else partied with you to exclude it against.

## [0.5.8] - 2026-10-19

### Fixed
- Holding the radial quick-add hotkey while in combat, with "Disable radial menu during combat" enabled, could throw an ADDON_ACTION_BLOCKED error instead of just declining to open.

## [0.5.7] - 2026-10-19

### Added
- Two checkboxes in Options > General > Window: "Hide the +/- standing buttons (Players tab)" and "Hide the New entry button (Players tab)", independently toggleable, off by default. The Standing and Notes columns can now shrink further once their button is hidden, and widen back out automatically if you re-enable a button after shrinking the column while it was hidden, so it can't end up floating over the next column.
- New Auto-Track trigger, "Buffed me": logs when another player casts a helpful buff on you, as long as they aren't partied with you. Only catches it if the game can currently identify them (your target, or a visible nameplate), not anyone nearby regardless of visibility. Off by default, +2 rep.
- New checkbox in Options > General > Chat & Minimap: "Show 'Entry created' message in chat window". When on, prints "Entry created for <name>" for every new entry with a note or rep change attached, regardless of source (manual, auto-track, the dungeon survey, etc). Off by default.

## [0.5.6] - 2026-10-18

### Changed
- The dungeon survey's Preset dropdown now alphabetizes within each group (good/bad/neutral) instead of leaving them in whatever order they're listed in Options.
- Minor UI adjustments.
- Minor phrasing adjustments.

### Fixed
- The group finder's Browse tab could throw a Lua error on every row update, when the game handed back a member count WR isn't allowed to use as a loop bound. Its background update loop could also keep running after the LFG panel was actually closed, since the sub-frame it checked doesn't always get hidden along with its parent window.

## [0.5.5] - 2026-10-16

### Fixed
- The Cooldown field on the Auto-Track rows (Waved/Thanked/Bowed at Me, Questing Together) rendered overlapping the Note box instead of beside it.
- Raising UI scale on an already-tall main window could push its bottom edge, resize grip included, off the bottom of the screen with no way to drag it back. Also self-heals a window already stuck like this from before this fix.
- A thin gap on the top, right, and bottom of the main window let whatever's behind it show through between the border and the background.

## [0.5.4] - 2026-10-15

### Added
- New "Dungeon/Raid Tracking" section in Options > Auto-Track (collapsed by default, like Directed Emotes): optional auto-log for dungeon/raid runs with your party (logs on entering, or on leaving with "Only log on completion"), and an optional survey popup on completion listing your party/raid with a note box, a configurable role-preset dropdown (colored and grouped by rep gain/loss), and standing +/- buttons per member, with standing shown colored by bracket same as everywhere else. The survey window is resizable and remembers its size, and its Name/Note columns size themselves to fit. The survey asks first with a small "Would you like to fill out the post-instance survey?" prompt (own saved position, a "Don't ask me again" checkbox to skip straight to the survey in future, also settable directly in Options). Both auto-log and survey off by default, independently toggleable, and can run together. `/wr testsurvey [count]` tests the whole flow, confirm prompt included, with fake data, no real run needed.

### Changed
- The Nearby alert "Cooldown per player" field (Options > Alerts) is now entered in minutes instead of seconds, matching every other cooldown setting in the addon.
- Nearby Players (Options > Auto-Track): "Don't auto-add while resting" is now "Auto-add while resting (inns/cities) too" instead, unchecked by default (same effective behavior). Added a performance warning and hover text on both checkboxes.
- Minor UI adjustments.

### Fixed
- A tooltip hovering certain world objects could throw a Lua error on every update instead of silently skipping, when the game handed back a unit value WR isn't allowed to inspect.
- WhisperMessenger (a commonly-installed addon) also claims the bare "/wr" slash command for its own reply shortcut, and can win the collision depending on load order. `/wrem` works as a guaranteed-unique alias.

## [0.5.3] - 2026-10-14

### Added
- Nearby window: double-clicking a name now opens that player's Details tab (a single click still opens the quick-add popup).
- Details tab: added a Delete Player button next to New Entry.

### Fixed
- Clicking an entry in the Players tab's Bracket column added that bracket to the "All brackets" filter dropdown, but didn't actually filter the table to it.
- Radial menu: holding the hotkey could occasionally do nothing until release, then just open the main window, with no visible wheel in between. A loading-screen transition could make the engine's own mouse-position check briefly return nothing right as the hotkey was pressed, which silently dropped that entire keypress.
- Radial menu: tap/drag detection relied on a tiny 4px probe under the cursor that any hand jitter while pressing the key could trip, misreading a genuine tap as a drag and silently cancelling it instead of quick-noting. Now compares cursor movement against the same deadzone radius used for picks.
- Radial menu: tapping the hotkey with nobody targeted or hovered required the mouse to be perfectly still to open the main window; ordinary cursor movement while tapping could make it do nothing.
- Radial Menu options tab: toggling a preset on or off in the Radial 1/2 preset dropdown didn't refresh the wheel's own binding, so a newly added preset could show up on the wheel but silently fail to apply until a UI reload.
- Players tab: hiding the Standing or Notes column (via the column picker) left their +/-/New buttons behind instead of hiding them too.
- The Standing +/- box (Quick Add and Edit Entry) let you type a change past the real +/-100 cap; it's now clamped at both entry points, matching the cap it was always supposed to respect.

## [0.5.2] - 2026-10-11

### Fixed
- Unchecking "Quick-Note a player on hover, not just when targeting" (Options > General) stopped doing anything for taps once the radial menu was enabled. A tap now reuses an identity the radial already captured early (to dodge a separate staleness issue), but that capture was gated by the Radial Menu tab's own hover setting instead of this one. A tap's captured identity is now resolved against the correct setting, independently of whichever one the radial wheel itself uses.

## [0.5.1] - 2026-10-11

### Changed
- New-install defaults: the radial menu is now on by default. Rezzed Me (+3) and Waved/Thanked/Bowed at Me (+1 each) auto-add rep gains are no longer zero. The Nearby window's "flash too" option is now on by default. The Positive/Negative nearby alert sounds now default to Trading Post Menu Open / Pathfinding, both of which actually show as selected in their own dropdown (the previous defaults didn't appear in their own list of choices).

### Fixed
- The Radial Menu tab's preset-assignment dropdowns didn't pick up changes made on the Presets tab until a full UI reload. Every Options sub-tab is actually built once, up front, when Options first opens, and switching tabs just shows/hides it rather than rebuilding it, so the dropdown's list of presets was a one-time snapshot. Now refreshes every time you switch to that tab.

## [0.5] - 2026-10-09

### Added
- New radial quick-add menu: hold the global keybind (Options > General) to open a radial of your quick-add presets at the cursor. Drag toward one and release to apply it to your target, or whoever you're hovering, or release without moving to fall back to the normal tap behavior (Quick Note) instead. Hover support is independently toggleable for the radial and for plain Quick Note.
- Optional second "negative" radial, held with a configurable modifier (Ctrl by default). With only one radial enabled it shows your whole preset list in neutral colors; with both enabled, presets split automatically between radials by their positive/negative delta, or can be assigned manually per radial in the new Radial Menu options tab, up to 5 presets per radial.
- New Radial Menu tab in Options: enable/disable, second radial and its modifier, per-radial preset assignment, a minimum hold time before a drag counts as a pick (so a quick or imprecise press doesn't get misread as one), hide-tooltip-while-open, and disable-in-combat (on by default; tapping for plain Quick Note still works mid-fight either way).
- The radial uses Blizzard's own ping-wheel art: a soft background glow, a divider between each slice, a wedge-shaped highlight (colored green/red/neutral per preset) over whichever slice you're pointing at, a ring marking the dead zone, and a glowing pointer that tracks the cursor. Escape or a right-click cancels without applying anything.
- The Key Bindings screen now lists a single "Worth Remembering" binding instead of a separate Quick Note entry, used for both the tap and hold behaviors.
- The group finder's Browse tab now shows WR standing right in the list: a colored tag next to each listing's leader, plus a bracket-colored asterisk for every other notable party member. Hovering a listing shows the same tag for every individual member in the preview, not just the leader.
- Hitting the global hotkey while hovering a listing in the LFG window will pull up the Players tab, filtered to that party's roster.
- Multi-select toggle (Players and History tabs, next to "All Characters" / "Any Time") adds a checkbox column for checking several rows at once. Right-click with more than one checked for a bulk "Delete Selected" option.
- The "Worth Remembering" right-click menu (chat names, unit frames, etc) now also offers "Show Details" alongside Add Note, for anyone you've already got a record for (same as the existing Delete Player option).

### Changed
- The Quick Note keybind settings are now labeled "Global Hotkey" and moved to the top of Options > General, with a new "?" button explaining its full tap/hold/Group Finder behavior. A new checkbox next to "With no target, open window to" lets that fallback be turned off entirely (the hotkey then does nothing at all with no target or hover, instead of opening the window), and the hover checkbox is reworded to "Quick-Note a player on hover, not just when targeting".
- Every "?" help button in Options now also shows its popup's text as a hover tooltip, not just on click.
- Minor UI adjustments.

## [0.4.3] - 2026-10-09

### Added
- Edit Entry now has the same quick delta buttons (-10/-5/-1/+1/+5/+10) as Quick Add, next to the Standing field.

### Changed
- The on-login chat message is now a plain "loaded. /wr to open the window." instead of leading with slash command syntax. If you don't have a hotkey set yet, it adds a nudge to set one in Options > General.

### Fixed
- Quick Add's note box (and everything below it: Featured, Standing, the delta buttons) sat off-center, unlike Edit Entry's matching layout. Now lines up the same way.

## [0.4.2] - 2026-10-07

### Added
- "Questing together" auto-add option (Options > Auto-Track), off by default: logs an entry for each party/raid member when you turn in a quest while grouped with them. +5 standing and a 30-minute per-player cooldown by default, both configurable. A "Min. time grouped" field (10 minutes by default, 0 disables it) skips anyone who only just joined your group, instead of counting them the instant you turn in a quest together.
- The directed-emote options (Waved/Thanked/Bowed at me) are now tucked into a collapsible "Directed Emotes" section in Options > Auto-Track. Each one now has its own "Cooldown" field next to its Note box instead of sharing one cooldown across all three, so e.g. waving and thanking the same player back to back can log both instead of only the first.
- The Quick Note keybind, when nothing's targeted, now opens the main window instead of just printing "No player targeted." to chat. Which tab it opens to (Players or History) is configurable in Options > General. Pressing it again while the window's already open closes it.
- New "About" tab: shows the addon's logo, current version, and full patch notes history. Each past version is collapsible, with the most recent one expanded by default.

### Changed
- The main window's border is now a warmer brownish gold instead of bright yellow-gold, and its header/footer bands have a subtle parchment-grain texture instead of a flat color fill. The footer band is also now the same height as the header.
- The Directed Emotes section's collapse toggle is now a proper button matching the Players tab's +/- button style, instead of plain bracketed text.

### Fixed
- The Quick Note keybind's entry in Blizzard's Key Bindings list showed raw placeholder text ("HEADER_Worth Remembering") instead of a real label, since this client doesn't resolve a custom binding header the normal way. It's now filed under the existing "AddOns" category instead, with a proper "WR Quick Note" name.
- Pressing the Quick Note keybind while a note box grabbed focus could leak that same keystroke's letter into the note text, since the game still delivers the triggering key's character after a keybind handler focuses an edit box in the same tick.
- The Players tab's column headers (e.g. "Last Seen", "Last Location") could still bleed past the window's border at the smallest window size. Word wrap alone can't break a single word too long for its column, and this table's columns can collectively need more width than the window's own minimum allows; both are now hard-clipped to their own bounds instead of drawing past them.

## [0.4.1] - 2026-10-06

### Fixed
- Performing /wave, /thank, or /bow yourself could log a bogus auto-tracked entry against whoever you targeted, as if they'd done it to you. On Forever, a self-performed emote's chat event comes through with a blank sender name instead of your own name, so the existing self-check never caught it. Now also checks the sender's GUID, which is reported correctly even when the name isn't.

## [0.4] - 2026-10-06

### Added
- "Prune" button on the Players tab, next to the player count, deletes every record currently matching your active filters, with a confirmation prompt naming exactly how many. Grayed out (with an explanatory tooltip) until at least one filter is selected, as protection against accidentally wiping the whole database.
- Auto-Prune (Options > General > Danger Zone): optionally deletes player records automatically on login that match every checked criterion (no notes, zero standing, neutral-band standing, not seen in a configurable number of days). Off by default. Prints a chat message with the count if anything got pruned.
- Minor UI adjustments.

### Fixed
- A player added by right-clicking their name in chat (no Race/Class/Faction known yet) never picked that info up later, even after seeing their nameplate in the world. A nameplate sighting now backfills it for any player already in your database.
- The Players tab's table header text (e.g. "Last Location") could bleed past its column and overlap the window's edge at narrow widths.
- Dragging the Players tab's scrollbar was noticeably laggier than using the mouse wheel. The table now sizes its rows-per-page to however many actually fit the window's current height instead of a fixed count, which also means the scrollbar itself is gone since there's never anything left to scroll within a page.

## [0.3.1] - 2026-10-05

### Added
- `/wrquick <preset label>` applies a quick-add preset to your current target in one step, no popup needed. Works with or without quotes around the label.
- Preset and Auto-Add note text can now include `{{loc}}`, `{{yourlvl}}`, and `{{theirlvl}}` placeholders, filled in with the real value when the note is logged (e.g. "Healed me in {{loc}}" becomes "Healed me in The Barrens"). A new "?" button next to Presets and Auto-Add explains them.
- Four new Auto-Add options (Options > Auto-Track), all off by default: "Rezzed me" (another player resurrects you), "Waved at me", "Thanked me", and "Bowed to me". A shared "Emote cooldown" setting (5 minutes by default) prevents a player from spamming repeat entries by chaining emotes at you.
- A new "?" next to "Button label" in Options > Presets explains how to use a preset's label in a macro with `/wrquick`.

### Fixed
- On the Details and History tables, the "Featured" column (and its own text/checkbox) could float outside the window, overlap earlier columns, or just not move at all when the window was resized.
- Resizing the main window didn't actually update table column layout until something else happened to trigger a refresh, so columns could stay positioned for the old size well after the drag.
- The Auto-Track "Rep gain" field (and several other number fields across Options) silently discarded a typed change if you clicked away instead of pressing Enter.

## [0.3] - 2026-10-05

### Changed
- Updated the options pages to improve organization and make them a bit more compact.
- All dropdown filters on the Players and History tabs are now multi-select, matching the existing "All Brackets" dropdown; select multiple values at once (e.g. several classes, or both factions) instead of being limited to one.
- Redesigned the Details tab's header: centered name with class/faction icons beside it, reorganized stats lines, and a "Last Location" line showing where the player was last seen.
- Removed the Details tab's "Manual & auto" source filter dropdown in favor of the existing New Entry button.
- Renamed the History tab's "Zone" column to "Location".
- Replaced the Players tab's "Notes only" checkbox with a "Notes" dropdown (Noted/Un-noted/Featured/Un-featured, multi-select).
- Clicking a player's name on the History tab now opens their Details page, matching the Players tab, instead of filtering History's search box to just that name.

### Added
- "Last Location" column on the Players tab.
- Players/History table column widths and visibility are now remembered, with a "Columns" dropdown to show/hide any of them.
- Entries can now be marked "Featured" (a checkbox on the New Entry and Edit Entry popups, only available once a note is typed). The Details tab's header shows a random featured note in a quote, re-rolled every time you visit the tab, and both Details and History have a "Featured" column to see/toggle it per entry.

### Fixed
- Party members could still get a duplicate auto-party entry after being grouped with them the whole time, since the join-tracking state was only ever kept in memory and got wiped by any `/reload` or loading screen (even one not caused by leaving the group), making an already-ongoing group look like a batch of fresh joins afterward. It's now seeded with whoever's already grouped at load time.
- Resizing the main window or the Nearby floating window could instantly balloon it to an enormous size with no drag motion, when the UI scale setting wasn't 1.0.
- The "Columns" visibility dropdown's checkboxes didn't actually hide/show columns.
- Clicking inside the note box on the New Entry and Edit Entry popups often didn't place the typing cursor, unless you clicked exactly on the first line.
- A long note could visually run past its column into whatever sat next to it instead of getting cut off.
- Resizing the main window could leave the Details/History tables' last column floating in its old spot instead of following the edge like every other column.

## [0.2.1] - 2026-10-04

### Fixed
- The minimap icon sat inside the map ring instead of on/just outside it (when not picked up by a button-collector addon), since its distance from center was a hardcoded pixel value instead of derived from the minimap's actual size.
- The chat standing tag never actually appeared. Two separate bugs: it split a sender's name on a hyphen to find their surname, but Forever actually joins names with a space (right-clicking a name in chat had the same wrong assumption and is fixed too); and appending the tag to the sender's name corrupted that name's clickable hyperlink, since the tag's color code injected a stray escape character into it. The tag is now plain (uncolored) text so it can safely sit right after the name again, e.g. "[Name] [+10]:".

## [0.2.0] - 2026-10-04

### Added
- Updated sound alert options with 5 provided sounds for each notification type (positive/negative/entry); custom sound IDs can now be used (you can use something like Leatrix Sounds to get sound IDs).
- "Last Note" column on the Players tab, showing the most recent note left for that player.
- "Times Seen" tracking: a counter that bumps each time a player's nameplate is seen, gated by a configurable cooldown (Options > Auto-Track, default 5 minutes) so briefly losing and regaining their nameplate doesn't inflate it. Optionally skipped while resting (on by default). Shown as a new sortable column on the Players tab. Ignores party/raid members, same as the Nearby window and nameplate icon.
- Optional note on auto-tracked entries (Options > Auto-Track), e.g. "[Auto] Partied", instead of the entry showing up blank.

### Fixed
- A note longer than its box would bleed out past the border with no way to scroll and read/edit the rest of it (affected both Quick Add and Edit Entry).
- Selecting "Custom sound ID" left the previously-selected preset still technically active underneath, so Test (and the dropdown itself) kept reflecting the old choice instead of the new one.
- The Test button only played whatever was already saved, not whatever was currently typed in the custom field, so it looked like Test ignored new entries unless Enter was pressed first.
- The built-in preset sounds (Write Quest, Spellbook Open, etc.) were referenced by file path and silently failed to play on this server; switched to referencing them by their actual numeric sound ID, which does work.
- Tightened a sizable gap of dead space between the tab row and tab content in the main window.
- The "Nearby window" section in Options > Auto-Track was mislabeled: it has nothing to do with the Nearby window, and its checkbox's description had the behavior backwards. Relabeled the section "Nearby players" and reworded the checkbox to "Auto-add missing nearby players (added with 0 standing)".
- Adjusted phrasing/descriptions in various places.
- The Details tab's "Select a player" placeholder now links back to the Players tab.
- Clicking "History" from the Quick Add popup did nothing visible if the main window wasn't already open, since that path never actually showed the window.
- Being partied with someone for an extended period could periodically re-log a bogus auto-party entry (note and rep) for them, since any single roster update that failed to resolve a still-present member's full identity would drop them from the tracked set and treat their next appearance as a new join. Rebuilt the tracking around unit GUIDs, which resolve far more reliably than full identity, and it's no longer rebuilt from scratch on every update.
- Editing a quick-add preset's label or note text in Options > Presets silently discarded the change if you clicked away instead of pressing Enter; those fields (and the rep delta field) now also save on click-away, matching the reputation bracket label editor.
- Deleting a quick-add preset could cause a default preset to silently reappear at the end of the list on the next login, since the settings-merge logic matched user-editable lists against the shipped defaults by numeric index rather than leaving an existing list alone.
- Checkbox spacing on the Auto-Track tab was cramped enough to visually overlap.
- Minor UI adjustments.

## [0.1] - Initial release

- Core notes and standing tracking (-100 to +100), with account-wide data shared across all characters.
- Players, History, Details, Statistics, and Options tabs.
- Reputation brackets with 4 label presets plus a fully custom one, and customizable colors.
- Click-to-filter table columns throughout Players and History.
- Nearby window: a small floating list of notable players currently on-screen, with optional sound/flash alerts.
- Nameplate icons color-coded by standing bracket.
- Chat integration: a colored standing tag after notable players' names.
- Quick-add popup with one-click presets and a dedicated note/keybind command.
- Optional automatic logging on party joins and/or any nearby player.
- Rebranded from "Dossier" to "Worth Remembering" (`/wr`, `/wrnote`) after finding the old name was already taken.
- Draggable minimap button with a right-click menu (Open Window / Options / Hide Minimap Icon) and a matching icon in the in-game AddOns list.
- Configurable keybind picker for the quick-note action, right in Options > General, instead of relying solely on Blizzard's separate Key Bindings screen.
- "Clear Database" and "Clear Non-Notable" buttons in a new Options > General "Danger zone" section, each with a confirmation prompt.
- Real "last seen" tracking: nameplate sightings now update a player's last-seen time independently of whether a note gets logged, instead of that date just reflecting the last logged entry.
- "Last Seen" filter dropdown (Last hour/day/week/month/year) on the Players tab, plus an "Invert (not seen)" checkbox to flip it around.
- "Zero only" and "Non-zero only" entries added to the Players tab's standing filter.
- Right-click menu on players now groups under a "Worth Remembering" header with separate "Add Note" and "Delete Player" options, matching the convention other note-tracking addons use.
- Minimize button on the main window: collapses it to a small draggable title bar instead of closing it outright.
- Footer now shows a third, tab-aware "shown" count alongside the account-wide totals.
- Fixed: right-clicking a player's name in a chat message didn't offer the "Add Note" option (chat links don't carry a usable name/realm pair, only a line ID that has to be resolved differently).
- Fixed: grabbing the main window's resize corner could instantly balloon it to an enormous size with zero drag motion, due to a missing resize-bounds maximum and the window still being anchored by a non-corner point.
- Fixed: scrollbars on the Details, Statistics, and Options tabs sat flush against the window's border instead of inset like History/Players.
- Fixed: "Last Seen" could read "today" for something that happened the previous calendar day, since it used a rolling 24-hour window; now shows minutes/hours/days ago instead.
- Fixed: the account-wide totals in the footer could get silently overwritten by History's counts even while viewing a different tab.
