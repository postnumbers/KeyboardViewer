# KeyboardViewer

A macOS menu bar app that shows a keyboard overlay of your Karabiner-Elements
Hyper bindings. While Caps Lock (Hyper) is held, every key shows what it does,
and the layout updates as you add ⇧, ⌘ and ⌥.

## How it works

```
Karabiner ──send_user_command──▶ UserCommandReceiver ─┐
  {"hyper": true|false}            (/tmp/hyper-overlay.sock)│
  {"command": "toggle"}                                     ├─▶ OverlayState ─▶ KeyboardView in OverlayPanel
NSEvent flagsChanged ──▶ ModifierMonitor (⇧⌃⌥⌘, debounced) ─┤
karabiner.json ──▶ ConfigWatcher ──▶ BindingIndex ──────────┘
```

- **Hyper state comes from Karabiner.** Your Caps Lock rule only sets the
  `HYPER` variable, and macOS never sees it as a modifier. So Karabiner sends
  a message on press and release through `send_user_command`.
- **⇧ ⌘ ⌥ are real modifiers**, read with a global `flagsChanged` monitor.
  Changes are debounced by 60 ms. When a Hyper binding fires, Karabiner
  briefly posts other modifiers (⌃⌥⇧⌘ for Hyper+W, say), and the debounce
  keeps the overlay from flickering between layers.
- **Matching mirrors Karabiner.** A binding applies when its mandatory
  modifiers are exactly what's held. The exception is `"optional": ["any"]`,
  which allows extra modifiers. The first match in file order wins, and
  disabled rules are skipped.
- **Global rules count too.** A rule with no conditions (like
  *shift + spacebar → underscore*) also fires while Hyper is held. If it
  comes first in the file it wins the chord, so the overlay shows it with a
  dashed outline. Hyper+⇧+Space types `_`, for example.
- **Labels** come from the text after `->` in each manipulator's
  description. The second line shows the actual output (`⌃⌥⇧⌘W`, `open Bike`).
  Keys are coloured by the karabiner.json section they come from.
- **The panel** is a non-activating floating `NSPanel`, so it never steals
  focus. Drag it from anywhere to move it, and drag an edge or corner to
  resize it. The keyboard scales to fit and keeps its proportions. Size and
  position are remembered; **Reset Size and Position** in the menu restores
  the default.

## Setup

1. **Update `karabiner.json`** (already done in your current config) by
   merging from `karabiner-snippets.json`:
   - Replace the Caps Lock manipulator (the first one in
     **[HyperIJKL] Capslock to Hyper**) with
     `replacement_capslock_manipulator`. It behaves the same, and also sends
     `{"hyper": true/false}`.
   - Add `new_rule`. It makes **Hyper + /** toggle the overlay on and off.
   - `send_user_command` needs a recent Karabiner-Elements. If the rule
     shows an error in Karabiner's settings, update Karabiner.
2. **Build:** `./make-app.sh`, then open `KeyboardViewer.app`.
   - You can also `swift run`, but Accessibility then gets granted to
     Terminal instead of the app.
3. **Grant permission:** System Settings › Privacy & Security ›
   **Device Control and Data Access** (called **Accessibility** before
   macOS 27), or choose **Open Permission Settings…** in the app's menu. Use
   **+** to add `KeyboardViewer.app` if it isn't listed, switch it on, then quit
   and reopen the app.

To check that Karabiner's messages arrive without running the app:

```sh
socat -u UNIX-RECVFROM:/tmp/hyper-overlay.sock,fork STDOUT
```

Hold Caps Lock and you should see `{"hyper":true}`. (Quit the app first, since
only one process can own the socket.)

## Using it

- **Hold Caps Lock.** After about 180 ms the overlay appears, showing the
  Hyper layer. Quick taps (Escape) don't trigger it.
- **Add ⇧, ⌘ or ⌥ while holding** to switch layers.
- **Pin it** to keep it on screen without holding Hyper: click the pin in
  the window's top-right corner, press **Hyper + /**, or choose **Pin
  Keyboard** in the menu bar. The pinned state is remembered between launches.
  - While pinned and Hyper isn't held, it shows what keys do without Hyper.
- **Colours show which section of karabiner.json** a binding comes from.
  Each rule carries two extra fields, which Karabiner ignores:
  `"color name": "blue"` is a note for you; `"color": "#3B82F6"` is the hex
  colour the overlay actually uses. Description text is that colour darkened
  in Light Mode and lightened in Dark Mode. Rules without a `color` (or with
  one the app can't read) get a colour automatically, picked from a fixed
  palette in file order and different from the colours your other rules use.
  The legend under the keyboard lists the coloured sections with bindings.
- **Long labels split onto two lines** at underscores (`page_down`) and,
  for words of 9+ letters, at inner capitals (`OmniOutliner`, `FontCreator`).
- **Show While Hyper Is Held** in the menu turns the hold-to-show behaviour
  off if you only want the pinned window.
- Edits to `karabiner.json` reload automatically.

## Shortcuts and options

| | Built-in | With Karabiner |
|---|---|---|
| Pin / unpin the keyboard | ⌃⌥⇧K | Hyper + / |
| App & system shortcuts on/off | ⌃⌥⇧L | Hyper + ⇧ + / |

The built-in shortcuts work without Karabiner and need no permission. Turn
them off with **Built-in Shortcuts** in the menu if they clash with another
app; the menu also shows a note if another app already owns one.

Menu bar options (all remembered between launches):
- **Show While ⌘ ⌥ ⌃ Are Held** (off by default): the keyboard pops up after
  you hold ⌘, ⌥ or ⌃ for about half a second and hides when you let go.
  ⇧ on its own doesn't trigger it, so typing capitals won't.
- **Show While Hyper Is Held** (on by default).
- **Caps Lock Label**: Automatic (default), Hyper or Caps Lock. See below.

## Which key is Hyper

The Hyper layer is shown only if karabiner.json has a key that opens it: a
manipulator that sets `HYPER` to 1 (yours does this on Caps Lock). If no key
does, the Hyper bindings are left out, since nothing could trigger them, and
the app works as it does without Karabiner. Rules that apply without Hyper are
still shown.

Caps Lock is labelled **Hyper** only when it is one:
- karabiner.json sets `HYPER` from it, or maps it to ⌃⌥⇧⌘, or
- an app that turns it into a Hyper key is running (Hyperkey or Superkey).

Otherwise it shows ⇪. If another app makes Caps Lock a Hyper key
(BetterTouchTool, Keyboard Maestro, a `hidutil` script…), set **Caps Lock
Label** to Hyper in the menu; set it to Caps Lock to never call it Hyper. If
karabiner.json makes a different key the Hyper key, that key is labelled Hyper
instead.

## Without Karabiner

KeyboardViewer also runs without Karabiner-Elements. With no
`~/.config/karabiner/karabiner.json`, or no Hyper key in it, it hides the Hyper parts and works as an
app and system shortcut viewer: pin it (⌃⌥⇧K or the menu), or turn on **Show
While ⌘ ⌥ ⌃ Are Held**, then hold modifiers to see what they do in the
frontmost app. Install Karabiner later and choose **Reload karabiner.json**.

## App, macOS and character shortcuts

Switch this on or off with **⌃⌥⇧L**, **Hyper + ⇧ + /** or **Show App & System
Shortcuts** in the menu bar menu (remembered between launches; on by default).
When it's off, holding ⌘ ⌥ ⌃ ⇧ shows only the Karabiner rules that apply
without Hyper.

The top row shows what F1–F12 do: brightness, Mission Control, Spotlight,
media and volume, or Karabiner's **Function keys** settings when Karabiner is
installed (yours sets F4 to Launchpad). They're on the plain layer, and the
F-key shortcuts (F11 Show Desktop…) move to the fn layer, unless **Use F1, F2,
etc. keys as standard function keys** is on in Keyboard settings, in which case
it's the other way round.

With nothing held, the keyboard shows what each key does when pressed on its
own: a key with no action shows the character it types ("a" under A, "["
under [). Holding ⇧ switches these to "A", "{" and so on, using your
keyboard layout. Single-key shortcuts listed in
the frontmost app's menus (J for Next Article, say) are shown too. Shortcuts an
app handles without listing them in a menu can't be seen from outside the app. The Hyper layer
appears only while Hyper is held.

When the window is pinned and you hold ⌘, ⌥, ⌃ or ⇧ **without** Hyper, the
keyboard shows what those keys do in the frontmost app. The header reads, for
example, "⌘ · Safari". Each key shows the first match, in the order the
keypress actually reaches them:

1. **Karabiner rules** that apply without Hyper (Karabiner sees keys first).
2. **macOS shortcuts** (indigo): Mission Control, Spotlight, screenshots,
   keyboard focus and the like, read from System Settings › Keyboard
   Shortcuts. Shortcuts you've never changed come from a built-in table.
3. **The app's menu shortcuts** (teal), read from its menu bar. Hover a key to
   see the menu path. These need the Device Control and Data Access permission,
   are read when the app comes to the front, and refresh when you hold a
   modifier if they're more than five seconds old.
4. **Characters** (grey), for ⌥ and ⇧⌥ alone: what each key types in your
   current keyboard layout. Dead keys (´ ¨ ˆ ˜ `) are marked in the tooltip.

Not shown: shortcuts an app handles without a menu item (such as ⌘1–9 tab
switching in browsers), and other apps' global hotkeys (Moom, 1Password…),
since neither is published anywhere.

## Files

| File | Role |
|---|---|
| `App/KeyboardViewerApp.swift` | `@main`, menu bar extra, app delegate |
| `App/AppController.swift` | Wiring, visibility rules, Accessibility prompt |
| `App/OverlayState.swift` | Observable state the view renders |
| `Config/KarabinerConfig.swift` | Codable model; tolerates object-or-array and string-or-array fields |
| `Config/BindingIndex.swift` | Hyper bindings in file order; `layer(for:)` does the matching |
| `Config/Describe.swift` | Labels: description text, `open -a` app names, keystroke symbols |
| `Config/Mods.swift` | ⌃⌥⇧⌘fn option set and name mapping |
| `Input/ModifierMonitor.swift` | Global `flagsChanged` monitor with debounce |
| `Input/UserCommandReceiver.swift` | UNIX datagram socket for Karabiner messages |
| `Input/ConfigWatcher.swift` | Watches `karabiner.json` (directory and file, follows atomic saves and symlinks) |
| `UI/KeyboardLayout.swift` | ANSI layout and key widths |
| `UI/KeyboardView.swift` | SwiftUI keyboard and key caps |
| `System/HyperKeyApps.swift` | Detects Hyperkey/Superkey; the Caps Lock Label setting |
| `UI/SectionPalette.swift` | Reads each rule's hex `color`; derives readable text colours |
| `UI/LabelFormatter.swift` | Splits long labels at underscores and inner capitals |
| `System/MenuShortcutReader.swift` | Reads the frontmost app's menu shortcuts (Accessibility API) |
| `System/SystemShortcuts.swift` | Reads macOS's own shortcuts (`com.apple.symbolichotkeys`) |
| `System/KeyboardLayoutReader.swift` | ⌥ / ⇧⌥ characters and character→key lookup for the current layout |
| `System/KeyCodes.swift` | macOS virtual key codes for the keys on screen |
| `Input/GlobalHotKeys.swift` | Built-in system-wide shortcuts (Carbon hot keys) |
| `UI/OverlayPanel.swift` | Floating, non-activating panel |
| `Icon/make_icon.py` | Draws the app icon (`AppIcon.png`, `AppIcon.icns`); `make-app.sh` bundles it |

## Not handled yet

- Manipulators with conditions beyond `HYPER` (frontmost app, device, other
  variables) are skipped. Showing them would mean tracking that state.
- `to_if_alone`, `to_if_held_down` and `simultaneous` aren't shown.
- Only the selected profile is read.
- Only the ANSI layout is drawn, matching your `keyboard_type_v2`.
