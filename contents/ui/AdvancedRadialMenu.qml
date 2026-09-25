import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

import "layouts.js" as Layouts

Item {
    id: root

    signal launchApp(string desktopFile)
    signal closeRequested()
    signal openSettings()

    // ── Config ──────────────────────────────────────────────
    property var menuItems: []
    property int menuSize: 400
    property int cfgIconSize: 26
    property real bgOpacity: 0.88
    property bool showLabels: true
    property bool showSectorLines: true
    property color accentColor: Kirigami.Theme.highlightColor
    // Fixed timing multiplier — durations below are tuned at 1.0
    readonly property real animScale: 1.0
    property string centerIcon: "configure"
    property string menuLayout: "hexagonal"
    property int semicircleRotation: 0
    property int centerGap: 0
    property string menuStyle: "glass"

    // ── Style tokens ────────────────────────────────────────
    // One drawing path per layout; each style is just these knobs.
    //   glow      — hover halo strength multiplier (0 = no halos)
    //   idleGlow  — accent glow on resting items/rims (0…1)
    //   rim       — accent edge brightness multiplier
    //   depth     — top→bottom / inner→outer gradient strength
    //   body      — brightness factor for shape fills (>1 frosted, <1 dark)
    //   edge      — idle outline alpha (non-neon)
    //   sheen     — glossy top-edge highlight alpha (0 = off)
    //   shadow    — soft drop shadow under shapes
    //   pulseMin  — center pulse low point (1 = no pulse)
    readonly property var styles: ({
        glass:   { glow: 0.9, idleGlow: 0, rim: 0.7, depth: 1.0, body: 1.7, edge: 0.4,  sheen: 0.28, shadow: true,  pulseMin: 0.8 },
        neon:    { glow: 1.6, idleGlow: 1, rim: 1.4, depth: 0.3, body: 0.4, edge: 0,    sheen: 0,    shadow: false, pulseMin: 0.45 },
        minimal: { glow: 0,   idleGlow: 0, rim: 0.3, depth: 0,   body: 1.0, edge: 0.18, sheen: 0,    shadow: false, pulseMin: 1.0 }
    })
    readonly property var st: styles[menuStyle] || styles.glass

    // Halo opacity for an item: hover falloff scaled by style, floored by idle glow
    function haloOpacity(idx) {
        return Math.min(1, Math.max(st.idleGlow * 0.4, magnifyGlow(idx) * st.glow))
    }
    function shade(c, f, a) {
        return Qt.rgba(Math.min(1, c.r * f), Math.min(1, c.g * f), Math.min(1, c.b * f), a)
    }
    function withAlpha(c, a) { return Qt.rgba(c.r, c.g, c.b, a) }

    // ── Derived ─────────────────────────────────────────────
    width: menuSize; height: menuSize
    readonly property real centerX: width / 2
    readonly property real centerY: height / 2
    readonly property int itemCount: menuItems.length

    // ── Responsive sizing ───────────────────────────────────
    // menuSize is the single size knob; everything is tuned at 400 px and
    // scales from there. Icon size and ring distance settings are "at 400".
    readonly property real sizeScale: menuSize / 400
    readonly property real ringRadius: menuSize * 0.35
    readonly property int itemSize: Math.round(56 * sizeScale)
    readonly property int centerSize: Math.round(60 * sizeScale)
    readonly property int hubSize: Math.round(40 * sizeScale)
    readonly property int hubIconSize: Math.round(20 * sizeScale)
    readonly property int iconSize: Math.round(cfgIconSize * sizeScale)
    readonly property real gapScaled: centerGap * sizeScale

    // Largest ring radius that still keeps every item (and its background)
    // inside the menuSize box, per layout
    readonly property real maxRadius: {
        var half = menuSize / 2
        if (isWheel) return half - 20
        if (isSemicircle) return (menuSize - itemSize - 30) / 2
        var r = half - itemSize / 2 - 6
        return itemCount > 6 ? r / 1.65 : r   // hex overflow ring sits at r * 1.65
    }

    // Hub (center circle) size never moves with centerGap — only the item
    // ring does, so the slider purely controls the gap between them.
    readonly property real effectiveRadius: Math.max(hubSize, Math.min(ringRadius + gapScaled, maxRadius))

    readonly property var itemPositions:
        Layouts.getPositions(menuLayout, itemCount,
            isWheel ? wheelOuterR : effectiveRadius,
            centerX, centerY, semicircleRotation, wheelSectorInnerR, itemSize)

    // Layout mode flags
    // "radial" was this layout's old id before it was renamed to
    // "hexagonal" — kept as an alias here so configs saved with the old
    // value still render instead of going blank.
    readonly property bool isHexagonal: menuLayout === "hexagonal" || menuLayout === "radial"
    readonly property bool isWheel: menuLayout === "wheel"
    readonly property bool isSemicircle: menuLayout === "semicircle"

    // Wheel geometry — wheelInnerR is the hub/hole, fixed regardless of
    // centerGap. The pie sectors actually start at wheelSectorInnerR, which
    // is the hub pushed out by centerGap — that's the real empty gap the
    // user sees between the hub and the ring. wheelOuterR stays anchored to
    // effectiveRadius so the ring's own thickness never changes with the gap.
    readonly property real wheelInnerR: ringRadius * 0.44
    // Clamped so the ring always keeps at least ~one item of thickness
    readonly property real wheelSectorInnerR: Math.min(wheelInnerR + gapScaled, wheelOuterR - itemSize * 0.9)
    readonly property real wheelOuterR: effectiveRadius + 10

    // ── State ───────────────────────────────────────────────
    property int selectedIndex: -1
    property string activeLabel: ""
    property bool centerHovered: false

    // Last non-negative selectedIndex — lets the wheel highlight / semicircle
    // spotlight fade out in place instead of snapping back to index 0.
    property int lastSelected: 0
    onSelectedIndexChanged: if (selectedIndex >= 0) lastSelected = selectedIndex

    // Press / launch feedback
    property int pressedIndex: -1
    property bool pressedCenter: false
    property bool pressing: false
    property real pressT: pressing ? 1 : 0
    Behavior on pressT { NumberAnimation { duration: 90 * animScale; easing.type: Easing.OutCubic } }
    property int launchIndex: -1
    property real popT: 0
    readonly property bool launching: launchIndex >= 0

    function show() {
        launchAnim.stop()
        selectedIndex = -1; activeLabel = ""; centerHovered = false
        pressedIndex = -1; pressedCenter = false; pressing = false
        launchIndex = -1; popT = 0
        openAnim.restart()
    }

    function startLaunch(idx) {
        launchIndex = idx
        launchAnim.restart()
    }

    // Extra scale layered on top of entrance + magnify: press shrink, launch pop
    function fxScale(idx) {
        var s = 1.0
        if (idx === pressedIndex) s *= 1 - 0.1 * pressT
        if (idx === launchIndex) s *= 1 + 0.15 * popT
        return s
    }
    // Non-launched items dim while the launched one pops
    function fxOpacity(idx) {
        return (launching && idx !== launchIndex) ? 1 - 0.6 * popT : 1.0
    }
    readonly property real centerFxScale: pressedCenter ? 1 - 0.1 * pressT : 1.0
    function hide() { closeAnim.restart() }

    // Dock-style magnification: hovered item pops big, ring-neighbors pop less
    function magnifyScale(idx) {
        if (selectedIndex < 0 || itemCount <= 0) return 1.0
        var d = Math.abs(idx - selectedIndex)
        d = Math.min(d, itemCount - d)
        if (d === 0) return 1.2
        if (d === 1) return 1.14
        if (d === 2) return 1.04
        return 1.0
    }
    // Neon glow strength paired with magnifyScale falloff
    function magnifyGlow(idx) {
        if (selectedIndex < 0 || itemCount <= 0) return 0.0
        var d = Math.abs(idx - selectedIndex)
        d = Math.min(d, itemCount - d)
        if (d === 0) return 1.0
        if (d === 1) return 0.35
        return 0.0
    }

    // ── Animations ──────────────────────────────────────────
    ParallelAnimation {
        id: openAnim
        NumberAnimation { target: root; property: "opacity"; from: 0; to: 1; duration: 250 * animScale; easing.type: Easing.OutCubic }
        NumberAnimation { target: root; property: "scale"; from: 0.6; to: 1.0; duration: 380 * animScale; easing.type: Easing.OutBack; easing.overshoot: 1.2 }
    }
    SequentialAnimation {
        id: closeAnim
        ParallelAnimation {
            NumberAnimation { target: root; property: "opacity"; to: 0; duration: 150 * animScale; easing.type: Easing.InCubic }
            NumberAnimation { target: root; property: "scale"; to: 0.7; duration: 150 * animScale; easing.type: Easing.InCubic }
        }
        ScriptAction { script: root.closeRequested() }
    }
    SequentialAnimation {
        id: launchAnim
        NumberAnimation { target: root; property: "popT"; from: 0; to: 1; duration: 180 * animScale; easing.type: Easing.OutCubic }
        ScriptAction {
            script: {
                var item = menuItems[root.launchIndex]
                if (item) root.launchApp(item.desktop)
            }
        }
    }

    // =====================================================================
    //  HEXAGONAL LAYOUT — Floating hex icons + glow ring center
    //  (Inspired by reference image 1)
    // =====================================================================

    // Hex-shaped item containers — single ring up to 6 items, overflow fans
    // onto a second outer ring (honeycomb look), per Layouts.hexagonal()
    Repeater {
        model: isHexagonal ? itemCount : 0

        Item {
            id: hexItem
            width: root.itemSize; height: root.itemSize
            readonly property bool isSel: root.selectedIndex === index
            readonly property var pos: index < itemPositions.length ? itemPositions[index] : null
            x: pos ? pos.x - width / 2 : 0
            y: pos ? pos.y - height / 2 : 0
            transform: Scale { origin.x: hexItem.width / 2; origin.y: hexItem.height / 2; xScale: root.fxScale(index); yScale: xScale }

            opacity: 0; scale: 0.3
            Component.onCompleted: hexEnter.start()
            SequentialAnimation {
                id: hexEnter
                PauseAnimation { duration: 55 * index * animScale }
                ParallelAnimation {
                    NumberAnimation { target: hexItem; property: "opacity"; to: 1; duration: 220 * animScale; easing.type: Easing.OutCubic }
                    NumberAnimation { target: hexItem; property: "scale"; to: 1.0; duration: 320 * animScale; easing.type: Easing.OutBack; easing.overshoot: 1.4 }
                }
            }

            // Inner wrap owns hover-scale (outer hexItem.scale is driven by entrance anim)
            Item {
                id: hexHoverScale
                anchors.fill: parent
                scale: root.magnifyScale(index)
                opacity: root.fxOpacity(index)
                Behavior on scale { NumberAnimation { duration: 200 * animScale; easing.type: Easing.OutBack; easing.overshoot: 2.4 } }

                // Hex glow behind (on hover, falls off across neighbors)
                Canvas {
                    id: hexGlow
                    anchors.centerIn: parent
                    width: parent.width + 18; height: width
                    opacity: root.haloOpacity(index)
                    visible: opacity > 0
                    onVisibleChanged: if (visible) requestPaint()
                    Behavior on opacity { NumberAnimation { duration: 150 * animScale } }
                    onPaint: {
                        var ctx = getContext("2d")
                        ctx.reset()
                        Layouts.hexPath(ctx, width/2, height/2, width/2 - 1)
                        ctx.fillStyle = Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.35)
                        ctx.fill()
                    }
                    Component.onCompleted: requestPaint()
                }

                // Hex container shape
                // Oversized by 16px so the glass drop shadow isn't clipped
                Canvas {
                    id: hexCanvas
                    anchors.centerIn: parent
                    width: parent.width + 16; height: width
                    // 0 → 1 blend between idle and selected look, animated so
                    // fill/border cross-fade instead of snapping
                    property real selT: hexItem.isSel ? 1 : 0
                    Behavior on selT { NumberAnimation { duration: 140 * animScale; easing.type: Easing.OutCubic } }
                    property real op: root.bgOpacity
                    property var sty: root.st
                    onSelTChanged: requestPaint()
                    onOpChanged: requestPaint()
                    onStyChanged: requestPaint()
                    Component.onCompleted: requestPaint()

                    function mix(c1, a1, c2, a2, t) {
                        return Qt.rgba(c1.r + (c2.r - c1.r) * t, c1.g + (c2.g - c1.g) * t,
                                       c1.b + (c2.b - c1.b) * t, (a1 + (a2 - a1) * t) * root.bgOpacity)
                    }

                    onPaint: {
                        var ctx = getContext("2d")
                        ctx.reset()
                        var cx = width / 2, cy = height / 2
                        var r = root.itemSize / 2 - 2
                        var bg = Kirigami.Theme.backgroundColor

                        // Body: vertical gradient, lighter top / darker bottom by depth
                        ctx.save()
                        if (sty.shadow) {
                            ctx.shadowColor = Qt.rgba(0, 0, 0, 0.35 * op)
                            ctx.shadowBlur = 8
                            ctx.shadowOffsetY = 2
                        }
                        Layouts.hexPath(ctx, cx, cy, r)
                        var body = ctx.createLinearGradient(0, cy - r, 0, cy + r)
                        var top = mix(bg, 0.55, accentColor, 0.4, selT)
                        body.addColorStop(0, root.shade(top, sty.body * (1 + 0.25 * sty.depth), top.a))
                        body.addColorStop(1, root.shade(top, sty.body * (1 - 0.3 * sty.depth), top.a))
                        ctx.fillStyle = body
                        ctx.fill()
                        ctx.restore()

                        // Glossy sheen across the top half
                        if (sty.sheen > 0) {
                            Layouts.hexPath(ctx, cx, cy, r - 2)
                            var sheen = ctx.createLinearGradient(0, cy - r, 0, cy)
                            sheen.addColorStop(0, Qt.rgba(1, 1, 1, sty.sheen * op))
                            sheen.addColorStop(1, Qt.rgba(1, 1, 1, 0))
                            ctx.fillStyle = sheen
                            ctx.fill()
                        }

                        // Outline: neon tints the idle edge toward accent
                        Layouts.hexPath(ctx, cx, cy, r)
                        var idleEdge = mix(Kirigami.Theme.textColor, sty.edge,
                                           accentColor, 0.9, sty.idleGlow)
                        var selEdge = root.withAlpha(accentColor, Math.min(1, 0.85 * sty.rim + 0.15) * op)
                        ctx.strokeStyle = Qt.rgba(idleEdge.r + (selEdge.r - idleEdge.r) * selT,
                                                  idleEdge.g + (selEdge.g - idleEdge.g) * selT,
                                                  idleEdge.b + (selEdge.b - idleEdge.b) * selT,
                                                  idleEdge.a + (selEdge.a - idleEdge.a) * selT)
                        ctx.lineWidth = 1.5 + 0.5 * selT
                        ctx.stroke()
                    }
                }

                Kirigami.Icon {
                    anchors.centerIn: parent
                    source: menuItems[index] ? menuItems[index].icon : ""
                    width: root.iconSize; height: width
                    color: hexItem.isSel ? accentColor : Kirigami.Theme.textColor
                    Behavior on color { ColorAnimation { duration: 120 * animScale } }
                }
            }
        }
    }

    // Glowing center ring (inspired by image 1)
    Item {
        id: hexCenter
        visible: isHexagonal
        anchors.centerIn: parent
        width: root.hubSize; height: root.hubSize
        transform: Scale { origin.x: hexCenter.width / 2; origin.y: hexCenter.height / 2; xScale: root.centerFxScale; yScale: xScale }

        // Outer glow ring
        Canvas {
            id: glowRingCanvas
            anchors.centerIn: parent
            width: parent.width + 12; height: width
            property bool hov: root.centerHovered
            property real op: root.bgOpacity
            property var sty: root.st
            onHovChanged: requestPaint()
            onOpChanged: requestPaint()
            onStyChanged: requestPaint()
            Component.onCompleted: requestPaint()

            onPaint: {
                var ctx = getContext("2d")
                ctx.reset()
                var cx = width/2, cy = height/2
                var outerR = width/2 - 6
                var innerR = outerR * 0.62

                // Dark glass disc inside the ring so the icon reads on any wallpaper
                if (sty.depth > 0) {
                    var disc = ctx.createLinearGradient(0, cy - innerR, 0, cy + innerR)
                    disc.addColorStop(0, root.shade(Kirigami.Theme.backgroundColor, 1.1, 0.7 * op * sty.depth))
                    disc.addColorStop(1, root.shade(Kirigami.Theme.backgroundColor, 0.6, 0.7 * op * sty.depth))
                    ctx.beginPath()
                    ctx.arc(cx, cy, innerR, 0, 2 * Math.PI)
                    ctx.fillStyle = disc
                    ctx.fill()
                }

                // Neon: soft outer halo passes around the ring
                if (sty.idleGlow > 0) {
                    var halo = [{ w: 8, a: 0.1 }, { w: 4, a: 0.2 }]
                    for (var h = 0; h < halo.length; h++) {
                        ctx.beginPath()
                        ctx.arc(cx, cy, outerR, 0, 2 * Math.PI)
                        ctx.strokeStyle = root.withAlpha(accentColor, halo[h].a * op)
                        ctx.lineWidth = halo[h].w
                        ctx.stroke()
                    }
                }

                // Ring shape
                ctx.beginPath()
                ctx.arc(cx, cy, outerR, 0, 2 * Math.PI)
                ctx.arc(cx, cy, innerR, 2 * Math.PI, 0, true)
                ctx.closePath()

                var alpha = Math.min(1, (hov ? 0.8 : 0.5) * (0.5 + 0.5 * sty.rim)) * op
                ctx.fillStyle = Qt.rgba(accentColor.r, accentColor.g, accentColor.b, alpha)
                ctx.fill()

                // Inner bright edge
                ctx.beginPath()
                ctx.arc(cx, cy, innerR + 1, 0, 2 * Math.PI)
                ctx.strokeStyle = Qt.rgba(accentColor.r, accentColor.g, accentColor.b, (hov ? 0.9 : 0.6) * op)
                ctx.lineWidth = 1.5
                ctx.stroke()
            }

            // Pulsing animation — only spend cycles on this while it's actually shown
            SequentialAnimation on opacity {
                running: isHexagonal && root.st.pulseMin < 1
                loops: Animation.Infinite
                onStopped: glowRingCanvas.opacity = 1
                NumberAnimation { to: 1.0; duration: 1800 * animScale; easing.type: Easing.InOutSine }
                NumberAnimation { to: root.st.pulseMin; duration: 1800 * animScale; easing.type: Easing.InOutSine }
            }
        }

        Kirigami.Icon {
            anchors.centerIn: parent
            source: root.centerIcon
            width: root.hubIconSize; height: width
            color: Kirigami.Theme.textColor
        }
    }

    // =====================================================================
    //  WHEEL LAYOUT — Solid pie donut with sectors
    //  (Inspired by reference image 2)
    // =====================================================================

    // Wheel donut background + sectors
    Canvas {
        id: wheelCanvas
        visible: isWheel
        anchors.centerIn: parent
        width: (wheelOuterR + 10) * 2; height: width

        // Selection is drawn by wheelHighlight below, so hovering never
        // repaints this (larger) canvas
        property bool divLines: root.showSectorLines
        property real op: root.bgOpacity
        property real gap: root.wheelSectorInnerR
        property var sty: root.st
        onDivLinesChanged: requestPaint()
        onOpChanged: requestPaint()
        onGapChanged: requestPaint()
        onStyChanged: requestPaint()
        Component.onCompleted: requestPaint()

        onPaint: {
            var ctx = getContext("2d")
            ctx.reset()
            if (itemCount <= 0) return

            var cx = width/2, cy = height/2
            var outerR = root.wheelOuterR
            var innerR = root.wheelSectorInnerR
            var n = itemCount
            var slice = 2 * Math.PI / n

            // Gap between wheel items
            var gap = 0.04
            var halfGap = gap / 2

            // Sector fill: radial gradient, darker at the hub → lighter at the
            // rim by depth (flat when depth is 0). Neon sits a bit darker so
            // its accent rim pops.
            var bg = Kirigami.Theme.backgroundColor
            var baseF = 0.7 * sty.body
            var fill = ctx.createRadialGradient(cx, cy, innerR, cx, cy, outerR)
            fill.addColorStop(0, root.shade(bg, baseF * (1 - 0.25 * sty.depth), op))
            fill.addColorStop(1, root.shade(bg, baseF * (1 + 0.3 * sty.depth), op))

            // Draw each sector
            for (var i = 0; i < n; i++) {
                var startA = slice * i - Math.PI / 2 - slice / 2 + halfGap
                var endA = slice * i - Math.PI / 2 + slice / 2 - halfGap

                // Sector path (annular wedge)
                ctx.beginPath()
                ctx.arc(cx, cy, outerR, startA, endA)
                ctx.arc(cx, cy, innerR, endA, startA, true)
                ctx.closePath()

                ctx.save()
                if (sty.shadow) {
                    ctx.shadowColor = Qt.rgba(0, 0, 0, 0.3 * op)
                    ctx.shadowBlur = 8
                    ctx.shadowOffsetY = 2
                }
                ctx.fillStyle = fill
                ctx.fill()
                ctx.restore()

                // Sector border (divider lines)
                if (divLines) {
                    ctx.strokeStyle = Qt.rgba(0, 0, 0, 0.5 * root.bgOpacity)
                    ctx.lineWidth = 2
                    ctx.stroke()
                }
            }

            // Glossy sheen on the upper half of the ring
            if (sty.sheen > 0) {
                var sheen = ctx.createLinearGradient(0, cy - outerR, 0, cy)
                sheen.addColorStop(0, Qt.rgba(1, 1, 1, 0.6 * sty.sheen * op))
                sheen.addColorStop(1, Qt.rgba(1, 1, 1, 0))
                ctx.beginPath()
                ctx.arc(cx, cy, outerR - 1, 0, 2 * Math.PI)
                ctx.arc(cx, cy, innerR + 1, 2 * Math.PI, 0, true)
                ctx.closePath()
                ctx.fillStyle = sheen
                ctx.fill()
            }

            // Outer rim — neon lights it in accent with a soft halo
            if (sty.idleGlow > 0) {
                var halo = [{ w: 6, a: 0.12 }, { w: 3, a: 0.25 }]
                for (var h = 0; h < halo.length; h++) {
                    ctx.beginPath()
                    ctx.arc(cx, cy, outerR, 0, 2 * Math.PI)
                    ctx.strokeStyle = root.withAlpha(accentColor, halo[h].a * op)
                    ctx.lineWidth = halo[h].w
                    ctx.stroke()
                }
            }
            ctx.beginPath()
            ctx.arc(cx, cy, outerR, 0, 2 * Math.PI)
            ctx.strokeStyle = sty.idleGlow > 0
                ? root.withAlpha(accentColor, 0.6 * op)
                : root.withAlpha(Kirigami.Theme.textColor, sty.edge * op)
            ctx.lineWidth = 1.5
            ctx.stroke()

            // Inner rim
            ctx.beginPath()
            ctx.arc(cx, cy, innerR, 0, 2 * Math.PI)
            ctx.stroke()
        }
    }

    // Selected-sector highlight: painted once as the top (index 0) sector,
    // then rotated to the hovered sector so it glides between items.
    Canvas {
        id: wheelHighlight
        visible: isWheel && itemCount > 0
        anchors.centerIn: parent
        width: wheelCanvas.width; height: width

        rotation: root.lastSelected * 360 / Math.max(1, itemCount)
        // Only glide once already shown — appearing from nothing jumps
        // straight to the hovered sector instead of sweeping in from the last one
        Behavior on rotation {
            enabled: wheelHighlight.opacity > 0.5
            RotationAnimation { duration: 160 * animScale; direction: RotationAnimation.Shortest; easing.type: Easing.OutCubic }
        }
        opacity: root.selectedIndex >= 0 ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 140 * animScale; easing.type: Easing.OutCubic } }

        property int n: itemCount
        property real op: root.bgOpacity
        property real outerR: root.wheelOuterR
        property real innerR: root.wheelSectorInnerR
        property color accent: accentColor
        property var sty: root.st
        onStyChanged: requestPaint()
        onNChanged: requestPaint()
        onOpChanged: requestPaint()
        onOuterRChanged: requestPaint()
        onInnerRChanged: requestPaint()
        onAccentChanged: requestPaint()
        Component.onCompleted: requestPaint()

        onPaint: {
            var ctx = getContext("2d")
            ctx.reset()
            if (n <= 0) return
            var cx = width/2, cy = height/2
            var slice = 2 * Math.PI / n
            var startA = -Math.PI / 2 - slice / 2
            var endA = startA + slice

            // Neon-tinted fill (same inset gap as the base sectors)
            ctx.beginPath()
            ctx.arc(cx, cy, outerR, startA + 0.02, endA - 0.02)
            ctx.arc(cx, cy, innerR, endA - 0.02, startA + 0.02, true)
            ctx.closePath()
            ctx.fillStyle = Qt.rgba(
                Kirigami.Theme.backgroundColor.r * 1.3 + accent.r * 0.22,
                Kirigami.Theme.backgroundColor.g * 1.3 + accent.g * 0.22,
                Kirigami.Theme.backgroundColor.b * 1.3 + accent.b * 0.22,
                op)
            ctx.fill()

            // Neon edge glow — layered strokes fake a soft blur
            var glowPass = [
                { w: 10, a: 0.12 },
                { w: 6,  a: 0.22 },
                { w: 3,  a: 0.5  },
                { w: 1.5, a: 0.95 }
            ]
            for (var g = 0; g < glowPass.length; g++) {
                ctx.beginPath()
                ctx.arc(cx, cy, outerR, startA, endA)
                ctx.arc(cx, cy, innerR, endA, startA, true)
                ctx.closePath()
                ctx.strokeStyle = Qt.rgba(accent.r, accent.g, accent.b, Math.min(1, glowPass[g].a * sty.rim))
                ctx.lineWidth = glowPass[g].w
                ctx.stroke()
            }
        }
    }

    // Wheel center dark circle
    Rectangle {
        id: wheelHub
        visible: isWheel
        anchors.centerIn: parent
        width: root.hubSize; height: root.hubSize; radius: width / 2
        transform: Scale { origin.x: wheelHub.width / 2; origin.y: wheelHub.height / 2; xScale: root.centerFxScale; yScale: xScale }
        // Gradient flattens to a solid disc when depth is 0
        gradient: Gradient {
            GradientStop { position: 0.0; color: root.shade(Kirigami.Theme.backgroundColor, 0.3 * (1 + 1.2 * root.st.depth), 0.95 * root.bgOpacity) }
            GradientStop { position: 1.0; color: root.shade(Kirigami.Theme.backgroundColor, 0.3, 0.95 * root.bgOpacity) }
        }
        border.width: root.st.idleGlow > 0 ? 1.5 : 1
        border.color: root.st.idleGlow > 0
            ? root.withAlpha(accentColor, 0.7 * root.bgOpacity)
            : root.withAlpha(Kirigami.Theme.textColor, (0.1 + 0.08 * root.st.depth) * root.bgOpacity)

        Kirigami.Icon {
            anchors.centerIn: parent
            source: root.centerIcon
            width: Math.round(root.hubIconSize * 1.1); height: width
            color: root.centerHovered ? accentColor : Kirigami.Theme.textColor
            Behavior on color { ColorAnimation { duration: 120 * animScale } }
        }
    }

    // Wheel item icons (no containers, float over sectors)
    Repeater {
        model: isWheel ? itemCount : 0
        Item {
            id: wheelItem
            width: root.itemSize; height: root.itemSize
            readonly property var pos: index < itemPositions.length ? itemPositions[index] : null
            x: pos ? pos.x - width / 2 : 0
            y: pos ? pos.y - height / 2 : 0
            transform: Scale { origin.x: wheelItem.width / 2; origin.y: wheelItem.height / 2; xScale: root.fxScale(index); yScale: xScale }

            opacity: 0; scale: 0.3
            Component.onCompleted: wheelEnterAnim.start()
            SequentialAnimation {
                id: wheelEnterAnim
                PauseAnimation { duration: 40 * index * animScale }
                ParallelAnimation {
                    NumberAnimation { target: wheelItem; property: "opacity"; to: 1; duration: 200 * animScale; easing.type: Easing.OutCubic }
                    NumberAnimation { target: wheelItem; property: "scale"; to: 1.0; duration: 280 * animScale; easing.type: Easing.OutBack }
                }
            }

            // Neon glow halo behind icon — brighter on hovered item, faint on ring-neighbors
            Canvas {
                id: wheelGlow
                anchors.centerIn: parent
                width: parent.width * 2.4; height: width
                opacity: root.haloOpacity(index)
                visible: opacity > 0
                onVisibleChanged: if (visible) requestPaint()
                Behavior on opacity { NumberAnimation { duration: 160 * animScale; easing.type: Easing.OutCubic } }
                Component.onCompleted: requestPaint()
                onPaint: {
                    var ctx = getContext("2d")
                    ctx.reset()
                    var cx = width / 2, cy = height / 2, r = width / 2
                    var grad = ctx.createRadialGradient(cx, cy, 0, cx, cy, r)
                    grad.addColorStop(0, Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.55))
                    grad.addColorStop(0.45, Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.2))
                    grad.addColorStop(1, Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0))
                    ctx.fillStyle = grad
                    ctx.beginPath()
                    ctx.arc(cx, cy, r, 0, 2 * Math.PI)
                    ctx.fill()
                }
            }

            Item {
                id: wheelHoverScale
                anchors.fill: parent
                scale: root.magnifyScale(index)
                opacity: root.fxOpacity(index)
                Behavior on scale { NumberAnimation { duration: 200 * animScale; easing.type: Easing.OutBack; easing.overshoot: 2.4 } }

                Kirigami.Icon {
                    anchors.centerIn: parent
                    source: menuItems[index] ? menuItems[index].icon : ""
                    width: root.iconSize + 2; height: width
                    color: root.selectedIndex === index ? accentColor : Kirigami.Theme.textColor
                    Behavior on color { ColorAnimation { duration: 120 * animScale } }
                }
            }
        }
    }

    // =====================================================================
    //  SEMICIRCLE LAYOUT — Glass half-disk + circle containers
    // =====================================================================

    // Glass background — real half-disk (semicircle layout only), same arc the
    // items are placed on so it never looks like an off-center full circle
    Canvas {
        id: semicircleBg
        visible: isSemicircle
        anchors.centerIn: parent
        width: effectiveRadius * 2 + itemSize + 30; height: width
        property real rot: root.semicircleRotation
        property real op: root.bgOpacity
        // Spotlight slides between items (spotA) and fades in/out (spotT);
        // the slide is skipped while faded out so it appears in place
        property real spotA: root.lastSelected < itemPositions.length ? itemPositions[root.lastSelected].angle : 0
        Behavior on spotA { enabled: semicircleBg.spotT > 0.5; NumberAnimation { duration: 160 * animScale; easing.type: Easing.OutCubic } }
        property real spotT: root.selectedIndex >= 0 ? 1 : 0
        Behavior on spotT { NumberAnimation { duration: 140 * animScale; easing.type: Easing.OutCubic } }
        property var sty: root.st
        property var pos: root.itemPositions
        property bool divLines: root.showSectorLines
        onStyChanged: requestPaint()
        onPosChanged: requestPaint()
        onDivLinesChanged: requestPaint()
        onRotChanged: requestPaint()
        onOpChanged: requestPaint()
        onSpotAChanged: requestPaint()
        onSpotTChanged: requestPaint()
        Component.onCompleted: requestPaint()
        onPaint: {
            var ctx = getContext("2d")
            ctx.reset()
            // 8px inset leaves room for the glass drop shadow
            var cx = width / 2, cy = height / 2, r = width / 2 - 8
            var arc = Layouts.semicircleArc(rot)
            var bg = Kirigami.Theme.backgroundColor
            ctx.beginPath()
            ctx.moveTo(cx, cy)
            ctx.arc(cx, cy, r, arc.start, arc.end)
            ctx.closePath()

            // Base: side-to-side sweep plus a radial falloff (hub darker,
            // rim lighter) whose strength follows depth
            var grad = ctx.createLinearGradient(
                cx + Math.cos(arc.start) * r, cy + Math.sin(arc.start) * r,
                cx + Math.cos(arc.end) * r, cy + Math.sin(arc.end) * r)
            grad.addColorStop(0.0, root.shade(bg, sty.body, op))
            grad.addColorStop(1.0, root.shade(bg, sty.body * (1 - 0.08 * Math.max(sty.depth, 0.5)), op * 0.95))
            ctx.save()
            if (sty.shadow) {
                ctx.shadowColor = Qt.rgba(0, 0, 0, 0.35 * op)
                ctx.shadowBlur = 10
                ctx.shadowOffsetY = 2
            }
            ctx.fillStyle = grad
            ctx.fill()
            ctx.restore()

            if (sty.depth > 0) {
                var radial = ctx.createRadialGradient(cx, cy, 0, cx, cy, r)
                radial.addColorStop(0, Qt.rgba(0, 0, 0, 0.18 * sty.depth * op))
                radial.addColorStop(0.6, Qt.rgba(0, 0, 0, 0))
                radial.addColorStop(1, Qt.rgba(1, 1, 1, 0.06 * sty.depth * op))
                ctx.fillStyle = radial
                ctx.fill()
            }

            // Track band behind the item ring — a darker channel the items sit in
            var neon = sty.idleGlow > 0
            var trackIn = Math.max(root.hubSize / 2 + 6, root.effectiveRadius - root.itemSize / 2 - 6 * root.sizeScale)
            var trackOut = r - 3
            ctx.beginPath()
            ctx.arc(cx, cy, trackOut, arc.start, arc.end)
            ctx.arc(cx, cy, trackIn, arc.end, arc.start, true)
            ctx.closePath()
            ctx.fillStyle = Qt.rgba(0, 0, 0, (neon ? 0.28 : sty.depth > 0 ? 0.16 : 0.1) * op)
            ctx.fill()
            // Inner edge of the track
            ctx.beginPath()
            ctx.arc(cx, cy, trackIn, arc.start, arc.end)
            ctx.strokeStyle = neon ? root.withAlpha(accentColor, 0.45 * op)
                                   : Qt.rgba(1, 1, 1, Math.max(0.05, sty.sheen * 0.4) * op)
            ctx.lineWidth = 1
            ctx.stroke()

            // Dividers between neighbouring items, like the wheel's sectors
            if (divLines && pos.length > 1) {
                for (var d = 0; d < pos.length - 1; d++) {
                    var a = (pos[d].angle + pos[d + 1].angle) / 2
                    var x1 = cx + Math.cos(a) * trackIn, y1 = cy + Math.sin(a) * trackIn
                    var x2 = cx + Math.cos(a) * trackOut, y2 = cy + Math.sin(a) * trackOut
                    ctx.beginPath()
                    ctx.moveTo(x1, y1)
                    ctx.lineTo(x2, y2)
                    ctx.strokeStyle = neon ? root.withAlpha(accentColor, Math.min(1, 0.45 * sty.rim) * op)
                                           : Qt.rgba(0, 0, 0, (sty.depth > 0 ? 0.4 : 0.25) * op)
                    ctx.lineWidth = 2
                    ctx.stroke()
                    // Light hairline beside the dark one gives an etched look
                    if (!neon) {
                        var nx = -Math.sin(a), ny = Math.cos(a)
                        ctx.beginPath()
                        ctx.moveTo(x1 + nx, y1 + ny)
                        ctx.lineTo(x2 + nx, y2 + ny)
                        ctx.strokeStyle = Qt.rgba(1, 1, 1, (sty.sheen > 0 ? 0.12 : 0.05) * op)
                        ctx.lineWidth = 1
                        ctx.stroke()
                    }
                }
            }

            // Soft accent spotlight behind the hovered/selected item, clipped
            // to the half-disk so it never bleeds past the arc edge
            if (spotT > 0) {
                var spotX = cx + Math.cos(spotA) * r * 0.55
                var spotY = cy + Math.sin(spotA) * r * 0.55
                var spot = ctx.createRadialGradient(spotX, spotY, 0, spotX, spotY, r * 0.6)
                spot.addColorStop(0, Qt.rgba(accentColor.r, accentColor.g, accentColor.b, Math.min(0.5, 0.3 * sty.glow) * op * spotT))
                spot.addColorStop(1, Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0))
                ctx.save()
                ctx.beginPath()
                ctx.moveTo(cx, cy)
                ctx.arc(cx, cy, r, arc.start, arc.end)
                ctx.closePath()
                ctx.clip()
                ctx.fillStyle = spot
                ctx.fillRect(0, 0, width, height)
                ctx.restore()
            }

            // Neon rim along the curved edge — layered strokes fake a soft
            // glow, echoing the wheel layout's selected-sector edge glow
            var rimPass = [
                { w: 7, a: 0.08 },
                { w: 3.5, a: 0.16 },
                { w: 1.25, a: 0.4 }
            ]
            for (var g = 0; g < rimPass.length; g++) {
                ctx.beginPath()
                ctx.arc(cx, cy, r - 1, arc.start, arc.end)
                ctx.strokeStyle = Qt.rgba(accentColor.r, accentColor.g, accentColor.b, Math.min(1, rimPass[g].a * sty.rim * 1.6) * op)
                ctx.lineWidth = rimPass[g].w
                ctx.stroke()
            }

            // Thin inner edge — brighter glossy line in glass
            ctx.strokeStyle = Qt.rgba(1, 1, 1, Math.max(0.06, sty.sheen * 0.8) * op)
            ctx.lineWidth = 1
            ctx.stroke()
        }
    }

    // Circle icon containers (semicircle layout only)
    Repeater {
        model: isSemicircle ? itemCount : 0
        Item {
            id: circItem
            width: root.itemSize; height: root.itemSize
            readonly property bool isSel: root.selectedIndex === index
            readonly property var pos: index < itemPositions.length ? itemPositions[index] : null
            x: pos ? pos.x - width / 2 : 0
            y: pos ? pos.y - height / 2 : 0
            transform: Scale { origin.x: circItem.width / 2; origin.y: circItem.height / 2; xScale: root.fxScale(index); yScale: xScale }

            opacity: 0; scale: 0.4
            Component.onCompleted: circEnter.start()
            SequentialAnimation {
                id: circEnter
                PauseAnimation { duration: 50 * index * animScale }
                ParallelAnimation {
                    NumberAnimation { target: circItem; property: "opacity"; to: 1; duration: 200 * animScale; easing.type: Easing.OutCubic }
                    NumberAnimation { target: circItem; property: "scale"; to: 1.0; duration: 300 * animScale; easing.type: Easing.OutBack }
                }
            }

            Item {
                anchors.fill: parent
                scale: root.magnifyScale(index)
                opacity: root.fxOpacity(index)
                Behavior on scale { NumberAnimation { duration: 200 * animScale; easing.type: Easing.OutBack; easing.overshoot: 2.4 } }

                // Hover glow halo (matches hexGlow/wheelGlow — was missing
                // here, so semicircle had pop-scale but no glow)
                Canvas {
                    id: circGlow
                    anchors.centerIn: parent
                    width: parent.width * 1.8; height: width
                    opacity: root.haloOpacity(index)
                    visible: opacity > 0
                    onVisibleChanged: if (visible) requestPaint()
                    Behavior on opacity { NumberAnimation { duration: 150 * animScale } }
                    onPaint: {
                        var ctx = getContext("2d")
                        ctx.reset()
                        var cx = width / 2, cy = height / 2, r = width / 2
                        var grad = ctx.createRadialGradient(cx, cy, 0, cx, cy, r)
                        grad.addColorStop(0, Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.5))
                        grad.addColorStop(0.5, Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.18))
                        grad.addColorStop(1, Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0))
                        ctx.fillStyle = grad
                        ctx.beginPath()
                        ctx.arc(cx, cy, r, 0, 2 * Math.PI)
                        ctx.fill()
                    }
                    Component.onCompleted: requestPaint()
                }

                Rectangle {
                    anchors.fill: parent; radius: width / 2
                    gradient: Gradient {
                        GradientStop {
                            position: 0.0
                            color: circItem.isSel
                                ? Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.32 * root.bgOpacity)
                                : root.shade(Kirigami.Theme.backgroundColor, root.st.body * (1 + 0.2 * root.st.depth), 0.45 * root.bgOpacity)
                        }
                        GradientStop {
                            position: 1.0
                            color: circItem.isSel
                                ? Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.16 * root.bgOpacity)
                                : root.shade(Kirigami.Theme.backgroundColor, root.st.body * (1 - 0.2 * root.st.depth), 0.4 * root.bgOpacity)
                        }
                    }
                    border.width: circItem.isSel ? 2 : 1
                    border.color: circItem.isSel ? accentColor
                        : root.st.idleGlow > 0 ? root.withAlpha(accentColor, 0.85 * root.bgOpacity)
                        : root.withAlpha(Kirigami.Theme.textColor, root.st.edge * root.bgOpacity)

                    // Glossy sheen over the top half
                    Rectangle {
                        visible: root.st.sheen > 0
                        anchors.fill: parent; anchors.margins: 2
                        radius: width / 2
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, root.st.sheen * root.bgOpacity) }
                            GradientStop { position: 0.5; color: Qt.rgba(1, 1, 1, 0) }
                        }
                    }
                    Kirigami.Icon {
                        anchors.centerIn: parent
                        source: menuItems[index] ? menuItems[index].icon : ""
                        width: root.iconSize; height: width
                        color: circItem.isSel ? accentColor : Kirigami.Theme.textColor
                        Behavior on color { ColorAnimation { duration: 120 * animScale } }
                    }
                }
            }
        }
    }

    // Soft ambient glow behind the semicircle center button — brightens on
    // hover, but no scale (the hover-magnify effect was intentionally
    // removed from every layout's settings/center button)
    Canvas {
        id: centerGlow
        visible: isSemicircle
        anchors.centerIn: parent
        width: centerSize * 2; height: width
        property bool hov: root.centerHovered
        property real op: root.bgOpacity
        onHovChanged: requestPaint()
        onOpChanged: requestPaint()
        opacity: Math.min(1, (hov ? 1.0 : 0.55) * (0.3 + 0.5 * root.st.glow))
        Behavior on opacity { NumberAnimation { duration: 150 * animScale } }
        Component.onCompleted: requestPaint()
        onPaint: {
            var ctx = getContext("2d")
            ctx.reset()
            var cx = width / 2, cy = height / 2, r = width / 2
            var grad = ctx.createRadialGradient(cx, cy, 0, cx, cy, r)
            grad.addColorStop(0, Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.35 * op))
            grad.addColorStop(0.55, Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.12 * op))
            grad.addColorStop(1, Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0))
            ctx.fillStyle = grad
            ctx.beginPath()
            ctx.arc(cx, cy, r, 0, 2 * Math.PI)
            ctx.fill()
        }
    }

    // Center button (semicircle only — hexagonal uses the glowing ring
    // center above; wheel has its own dark hub)
    Rectangle {
        id: semiHub
        visible: isSemicircle
        anchors.centerIn: parent
        width: root.hubSize; height: root.hubSize; radius: width / 2
        transform: Scale { origin.x: semiHub.width / 2; origin.y: semiHub.height / 2; xScale: root.centerFxScale; yScale: xScale }
        color: centerHovered ? Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.18 * bgOpacity) : Qt.rgba(Kirigami.Theme.backgroundColor.r, Kirigami.Theme.backgroundColor.g, Kirigami.Theme.backgroundColor.b, 0.95 * bgOpacity)
        border.width: 2
        border.color: centerHovered ? accentColor : root.withAlpha(accentColor, Math.min(1, 0.5 * (0.5 + 0.5 * root.st.rim) + root.st.idleGlow) * bgOpacity)
        Behavior on color { ColorAnimation { duration: 150 * animScale } }
        Kirigami.Icon {
            anchors.centerIn: parent; source: root.centerIcon
            width: Math.round(root.hubIconSize * 0.9); height: width
            color: centerHovered ? accentColor : Kirigami.Theme.textColor
            Behavior on color { ColorAnimation { duration: 120 * animScale } }
        }
    }

    // =====================================================================
    //  LABEL
    // =====================================================================
    PlasmaComponents.Label {
        visible: showLabels
        anchors.horizontalCenter: parent.horizontalCenter
        y: centerY + centerSize / 2 + 12 * sizeScale
        text: activeLabel
        font.weight: Font.Bold; font.pointSize: 11; font.letterSpacing: 0.5
        color: Kirigami.Theme.textColor
        opacity: activeLabel !== "" ? 1.0 : 0.0
        scale: activeLabel !== "" ? 1.0 : 0.85
        Behavior on opacity { NumberAnimation { duration: 100 * animScale } }
        Behavior on scale { NumberAnimation { duration: 140 * animScale; easing.type: Easing.OutCubic } }
        PlasmaComponents.Label {
            anchors.centerIn: parent; anchors.verticalCenterOffset: 1; anchors.horizontalCenterOffset: 1
            text: parent.text; font: parent.font; color: Qt.rgba(0, 0, 0, 0.25); z: -1
        }
    }

    // =====================================================================
    //  MOUSE INTERACTION
    // =====================================================================
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true

        function findNearest(mx, my) {
            var bestIdx = -1, bestDist = Infinity
            for (var i = 0; i < itemPositions.length; i++) {
                var dx = mx - itemPositions[i].x, dy = my - itemPositions[i].y
                var d = Math.sqrt(dx * dx + dy * dy)
                if (d < itemSize * 1.2 && d < bestDist) { bestDist = d; bestIdx = i }
            }
            return bestIdx
        }

        function findSector(mx, my) {
            var dx = mx - centerX, dy = my - centerY
            var angle = Math.atan2(dy, dx)
            var norm = angle + Math.PI / 2
            if (norm < 0) norm += 2 * Math.PI
            var slice = 2 * Math.PI / itemCount
            return Math.floor((norm + slice / 2) / slice) % itemCount
        }

        onPositionChanged: (mouse) => { if (!launching) updateHover(mouse) }

        function updateHover(mouse) {
            var dx = mouse.x - centerX, dy = mouse.y - centerY
            var dist = Math.sqrt(dx * dx + dy * dy)

            var centerR = isWheel ? wheelInnerR - 4 : centerSize / 2
            if (dist < centerR) {
                centerHovered = true; selectedIndex = -1; activeLabel = "Settings"
            } else if (isWheel && dist < wheelSectorInnerR) {
                // Empty gap between hub and ring (centerGap) — nothing to select here
                centerHovered = false; selectedIndex = -1; activeLabel = ""
            } else if (dist < effectiveRadius + itemSize + 20 && itemCount > 0) {
                centerHovered = false
                // Wheel's visual wedges are angle-defined, so angle-based hit
                // testing must match them exactly. Hexagonal (and semicircle)
                // place icons at fixed points — including hexagonal's second
                // overflow ring past 6 items, where positions aren't evenly
                // spaced around one circle — so nearest-position is correct
                // there instead.
                var idx
                if (isWheel) { idx = findSector(mouse.x, mouse.y) }
                else { idx = findNearest(mouse.x, mouse.y) }

                if (idx >= 0) { selectedIndex = idx; activeLabel = menuItems[idx] ? menuItems[idx].label : "" }
                else { selectedIndex = -1; activeLabel = "" }
            } else {
                centerHovered = false; selectedIndex = -1; activeLabel = ""
            }
        }

        onPressed: (mouse) => {
            if (launching) return
            updateHover(mouse)  // covers a click/tap with no prior hover move
            pressedCenter = centerHovered
            pressedIndex = selectedIndex
            pressing = true
        }
        onReleased: pressing = false
        onCanceled: { pressing = false; pressedIndex = -1; pressedCenter = false }

        // Only act when released over what was pressed — dragging off the
        // pressed item/hub cancels instead of launching something else
        onClicked: {
            if (launching) return
            if (pressedCenter) {
                if (centerHovered) root.openSettings()
            } else if (pressedIndex >= 0) {
                if (selectedIndex === pressedIndex && menuItems[pressedIndex]) root.startLaunch(pressedIndex)
            } else if (!centerHovered && selectedIndex < 0) {
                root.hide()
            }
        }

        onExited: { if (!launching) { centerHovered = false; selectedIndex = -1; activeLabel = "" } }
    }
}
