# Radial Menu

Radial app launcher widget for KDE Plasma 6. Three layouts: hexagonal, wheel, semi-circle.

Plugin id: `org.kde.radialmenu`

## Requirements

- KDE Plasma 6
- KDE Frameworks 6 QML modules: `org.kde.iconthemes`, `org.kde.kquickcontrols` (ship with most Plasma 6 installs)
- `kstart` (used to launch apps)

## Install

From the repo root:

```sh
kpackagetool6 --type Plasma/Applet --install .
```

Then add it: right-click the panel or desktop → **Add Widgets…** → search **Radial Menu** → drag it into place.

## Update

After pulling new code, from the repo root:

```sh
kpackagetool6 --type Plasma/Applet --upgrade .
systemctl --user restart plasma-plasmashell
```

Plasma caches QML, so the restart is needed for changes to show.

## Remove

Remove the widget from your panel/desktop first (right-click it → **Remove**), then:

```sh
kpackagetool6 --type Plasma/Applet --remove org.kde.radialmenu
```

## Try without installing

```sh
plasmoidviewer -a .
```

## Keyboard shortcut

Right-click the widget → **Configure Shortcuts…** and assign a key. To make the menu open only via the shortcut, enable **Appearance → Only open via keyboard shortcut**.
