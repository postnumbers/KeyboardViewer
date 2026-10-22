# KeyboardViewer

A macOS menu bar app that shows a keyboard overlay of what every key does
right now: the character it types, the frontmost app's menu shortcuts, macOS's
own shortcuts and the top-row media keys. Hold ⇧, ⌘, ⌥, ⌃ or fn and the keys
update to show that layer.

**Karabiner-Elements is optional.** KeyboardViewer works on its own. If you
also use [Karabiner-Elements](https://karabiner-elements.pqrs.org), it reads
your `karabiner.json` too and adds your Karabiner rules, including a Hyper key
layer if you've set one up (see [With Karabiner-Elements](#with-karabiner-elements-optional)).

## Setup

1. **Build:** `./make-app.sh`, then open `KeyboardViewer.app`.
   - You can also `swift run`, but the permission below then gets granted to
     Terminal instead of the app.
2. **Grant permission** so KeyboardViewer can read apps' menu shortcuts:
   System Settings › Privacy & Security › **Device Control and Data Access**
   (called **Accessibility** before macOS 27), or choose **Open Permission
   Settings…** in the app's menu. Use **+** to add `KeyboardViewer.app` if it
   isn't listed, switch it on, then quit and reopen the app.
   - The app is signed ad hoc, so each rebuild looks like a new app to macOS.
     After rebuilding, remove the old entry with **−** and add the new build
     with **+**; switching the old entry off and on isn't enough.

Without the permission, everything except apps' menu shortcuts still works.

## Using it

- **Pin the keyboard** to keep it on screen: press **⌃⌥⇧K**, click the pin in
  the window's top-right corner, or choose **Pin Keyboard** in the menu bar.
- **Or show it while modifiers are held:** turn on **Show While ⌘ ⌥ ⌃ Are
  Held**, and the keyboard pops up after you hold ⌘, ⌥ or ⌃ for about half a
  second and hides when you let go. ⇧ on its own doesn't trigger it, so typing
  capitals won't.
- **Hold modifiers to switch layers.** The header shows what's held and the
  frontmost app, e.g. "⌘ · Safari".
- **The panel** never steals focus. Drag it from anywhere to move it, and drag
  an edge or corner to resize it; the keyboard scales to fit and keeps its
  proportions. Size and position are remembered; **Reset Size and Position**
  in the menu restores the default.
- **Long labels split onto two lines** at underscores (`page_down`) and, for
  words of 9+ letters, at inner capitals (`OmniOutliner`).

## What each key shows

Each key shows the first match, in the order a keypress actually reaches them:

1. **Karabiner rules** (only if you use Karabiner-Elements): rules that apply
   without Hyper, since Karabiner sees keys first. Drawn with a dashed outline.
2. **The top row** (slate): F1–F12 show the symbols printed on the keys:
   brightness, Mission Control, Spotlight, Dictation, Do Not Disturb, media
   and volume. These are on the plain layer, and F-key shortcuts (F11 Show
   Desktop…) move to the fn layer, unless **Use F1, F2, etc. keys as standard
   function keys** is on in Keyboard settings, in which case it's the other
   way round. If you use Karabiner-Elements, its **Function keys** settings
   decide the top row instead.
3. **macOS shortcuts** (indigo): Mission Control, Spotlight, screenshots,
   keyboard focus, window tiling (Globe+⌃+arrows…) and the like, read from
   System Settings › Keyboard Shortcuts. Shortcuts you've never changed come
   from a built-in table.
4. **App Shortcuts you've set** (sky blue) in System Settings › Keyboard ›
   App Shortcuts, for one app or all apps.
5. **The app's menu shortcuts** (teal), read from its menu bar, including
   single-key ones (J for Next Article, say) and ones using Globe. Hover a key
   to see the menu path. These need the permission above, are read when the
   app comes to the front, and refresh when you hold a modifier if they're
   more than five seconds old. If none are found, the header and the menu say
   why.
6. **Characters**: with nothing held or ⇧, what the key types ("a" under A,
   "{" under [ with ⇧), drawn on a plain key. With ⌥ or ⇧⌥ (grey), the
   special characters; dead keys (´ ¨ ˆ ˜ `) are marked in the tooltip.

Switch the app, macOS and menu shortcuts on or off with **⌃⌥⇧L** or **Show
App & System Shortcuts** in the menu (remembered; on by default).

Not shown: shortcuts an app handles without a menu item (such as ⌘1–9 tab
switching in browsers), and other apps' global hotkeys (Moom, 1Password…),
since neither is published anywhere.

## Keyboard layouts

- **Shape:** ANSI (US: wide Return, short left ⇧) or ISO (European: tall
  L-shaped Return, § left of 1, an extra key left of Z). **Keyboard Shape** in
  the menu is Automatic by default, using the keyboard you last typed on, or
  can be set to either. JIS keyboards are drawn as ANSI for now.
- **Language:** key names and characters follow your current input source, so
  with AZERTY the A key is labelled Q, and they update when you switch input
  sources.

## Shortcuts and options

| | Built in | With Karabiner (optional) |
|---|---|---|
| Pin / unpin the keyboard | ⌃⌥⇧K | Hyper + / |
| App & system shortcuts on/off | ⌃⌥⇧L | Hyper + ⇧ + / |

The built-in shortcuts need neither Karabiner nor any permission. Turn them
off with **Built-in Shortcuts** in the menu if they clash with another app;
the menu also shows a note if another app already owns one.

Menu bar options (all remembered between launches):
- **Show While ⌘ ⌥ ⌃ Are Held** (off by default).
- **Show While Hyper Is Held** (on by default; only with a Hyper key).
- **Keyboard Shape**: Automatic (default), ANSI or ISO.
- **Caps Lock Label**: Automatic (default), Hyper or Caps Lock. See below.

## With Karabiner-Elements (optional)

Everything in this section applies only if you use Karabiner-Elements.
KeyboardViewer reads `~/.config/karabiner/karabiner.json`; if the file isn't
there, these features stay hidden. Install Karabiner later and choose
**Reload karabiner.json** in the menu. Edits to the file reload automatically.

### What it adds

- **Your Karabiner rules** on the keys they apply to. Each key's label comes
  from the manipulator's `description`: the text after `->` if there is one
  (`"w -> Safari"` shows "Safari"), otherwise the whole description. A manipulator
  without a description uses its rule's description if that has a `->`, and
  otherwise shows what it sends. Hover a key to see the actual
  output (`⌃⌥⇧⌘W`, `open Bike`).
- **A Hyper layer**, if a key sets a `HYPER` variable. While it's held, every
  key shows its Hyper binding, and adding ⇧, ⌘ or ⌥ switches layers.
- **Colours by section.** Each rule can carry two extra fields, which
  Karabiner ignores: `"color name": "blue"` is a note for you, and
  `"color": "#3B82F6"` is the hex colour the overlay uses. Rules without a
  usable `color` get one automatically, different from the colours your other
  rules use. The legend under the keyboard lists the sections on screen.

### Setting up the Hyper layer

Merge from `karabiner-snippets.json`:
- Replace the manipulator that turns Caps Lock into Hyper with
  `replacement_capslock_manipulator`. It behaves the same, and also sends
  `{"hyper": true/false}` so KeyboardViewer knows when Hyper is held.
- Add `new_rule`. It makes **Hyper + /** pin the keyboard and **Hyper + ⇧ + /**
  switch app & system shortcuts on and off.
- `send_user_command` needs a recent Karabiner-Elements. If the rule shows an
  error in Karabiner's settings, update Karabiner.

Then hold Caps Lock: after about 180 ms the overlay shows the Hyper layer.
Quick taps (Escape) don't trigger it.

To check that Karabiner's messages arrive without running the app:

```sh
socat -u UNIX-RECVFROM:/tmp/hyper-overlay.sock,fork STDOUT
```

Hold Caps Lock and you should see `{"hyper":true}`. (Quit the app first, since
only one process can own the socket.)

### Which key is Hyper

The Hyper layer is shown only if karabiner.json has a key that opens it: a
manipulator that sets `HYPER` to 1. If no key does, the Hyper bindings are
left out, since nothing could trigger them. Rules that apply without Hyper are
still shown.

Caps Lock is labelled **Hyper** only when it is one:
- karabiner.json sets `HYPER` from it, or maps it to ⌃⌥⇧⌘, or
- an app that turns it into a Hyper key is running (Hyperkey or Superkey).

Otherwise it shows ⇪. If another app makes Caps Lock a Hyper key
(BetterTouchTool, Keyboard Maestro, a `hidutil` script…), set **Caps Lock
Label** to Hyper in the menu; set it to Caps Lock to never call it Hyper. If
karabiner.json makes a different key the Hyper key, that key is labelled Hyper
instead.

### How Karabiner support works

```
Karabiner ──send_user_command──▶ UserCommandReceiver ─┐
  {"hyper": true|false}            (/tmp/hyper-overlay.sock)│
  {"command": "toggle"}                                     ├─▶ OverlayState ─▶ KeyboardView in OverlayPanel
NSEvent flagsChanged ──▶ ModifierMonitor (⇧⌃⌥⌘, debounced) ─┤
karabiner.json ──▶ ConfigWatcher ──▶ BindingIndex ──────────┘
```

- **Hyper state comes from Karabiner.** A Caps Lock rule only sets the `HYPER`
  variable, and macOS never sees it as a modifier, so Karabiner sends a
  message on press and release through `send_user_command`.
- **⇧ ⌘ ⌥ are real modifiers**, read with a global `flagsChanged` monitor and
  debounced by 60 ms. When a Hyper binding fires, Karabiner briefly posts other
  modifiers (⌃⌥⇧⌘ for Hyper+W, say), and the debounce keeps the overlay from
  flickering between layers.
- **Matching mirrors Karabiner.** A binding applies when its mandatory
  modifiers are exactly what's held, unless it has `"optional": ["any"]`. The
  first match in file order wins, and disabled rules are skipped.
- **Global rules count too.** A rule with no conditions (like *shift +
  spacebar → underscore*) also fires while Hyper is held. If it comes first in
  the file it wins the chord, so the overlay shows it with a dashed outline.

## Files

| File | Role |
|---|---|
| `App/KeyboardViewerApp.swift` | `@main`, menu bar extra, app delegate |
| `App/AppController.swift` | Wiring, visibility rules, permission prompt |
| `App/OverlayState.swift` | Observable state the view renders |
| `Config/KarabinerConfig.swift` | Codable model of `karabiner.json` (optional) |
| `Config/BindingIndex.swift` | Karabiner bindings in file order; `layer(for:)` does the matching |
| `Config/Describe.swift` | Labels: description text, `open -a` app names, keystroke symbols |
| `Config/Mods.swift` | ⌃⌥⇧⌘fn option set and name mapping |
| `Input/ModifierMonitor.swift` | Global `flagsChanged` monitor with debounce |
| `Input/UserCommandReceiver.swift` | UNIX datagram socket for Karabiner messages |
| `Input/ConfigWatcher.swift` | Watches `karabiner.json` (follows atomic saves and symlinks) |
| `Input/GlobalHotKeys.swift` | Built-in system-wide shortcuts (Carbon hot keys) |
| `UI/KeyboardLayout.swift` | ANSI and ISO layouts and key widths |
| `UI/KeyboardView.swift` | SwiftUI keyboard and key caps (including the L-shaped ISO Return) |
| `UI/SectionPalette.swift` | Section colours; derives readable text colours |
| `UI/LabelFormatter.swift` | Splits long labels at underscores and inner capitals |
| `UI/OverlayPanel.swift` | Floating, non-activating panel |
| `System/MenuShortcutReader.swift` | Reads the frontmost app's menu shortcuts (Accessibility API) |
| `System/SystemShortcuts.swift` | Reads macOS's own shortcuts (`com.apple.symbolichotkeys`) |
| `System/UserKeyEquivalents.swift` | Reads App Shortcuts set in System Settings |
| `System/FunctionKeys.swift` | The top row's brightness, media and volume actions |
| `System/KeyboardLayoutReader.swift` | Characters, key names and keyboard shape for the current input source |
| `System/KeyCodes.swift` | macOS virtual key codes for the keys on screen |
| `System/HyperKeyApps.swift` | Detects Hyperkey/Superkey; the Caps Lock Label setting |
| `Icon/make_icon.py` | Draws the app icon (`AppIcon.png`, `AppIcon.icns`); `make-app.sh` bundles it |

## Not handled yet

- JIS keyboards are drawn as ANSI.
- Karabiner manipulators with conditions beyond `HYPER` (frontmost app,
  device, other variables) are skipped; showing them would mean tracking that
  state. `to_if_alone`, `to_if_held_down` and `simultaneous` aren't shown, and
  only the selected profile is read.
