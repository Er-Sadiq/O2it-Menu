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

    // Targeting brackets shown on the hovered item (HUD look). sides: 0 =
    // four short arcs around a round item, 6 = corner brackets on a hex.
    component TargetBrackets: Canvas {
        id: tb
        property bool active: false
        property bool spin: false
        property color color: "white"
        property int sides: 0
        opacity: active ? 1 : 0
        visible: opacity > 0
        scale: active ? 1 : 1.3
        Behavior on opacity { NumberAnimation { duration: 140 } }
        Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
        onVisibleChanged: if (visible) requestPaint()
        onColorChanged: requestPaint()
        Component.onCompleted: requestPaint()
        RotationAnimation on rotation {
            running: tb.active && tb.spin; loops: Animation.Infinite
            from: 0; to: 360; duration: 4000
        }
        onPaint: {
            var ctx = getContext("2d")
            ctx.reset()
            var cx = width / 2, cy = height / 2, r = width / 2 - 2
            ctx.strokeStyle = Qt.rgba(color.r, color.g, color.b, 0.95)
            ctx.lineWidth = 2
            if (sides === 0) {
                for (var q = 0; q < 4; q++) {
                    var a0 = q * Math.PI / 2 - Math.PI / 4 - 0.3
                    ctx.beginPath()
                    ctx.arc(cx, cy, r, a0, a0 + 0.6)
                    ctx.stroke()
                }
                return
            }
            // Pointy-top polygon; each bracket runs 30% down both edges of a corner
            var pts = []
            for (var i = 0; i < sides; i++) {
                var a = 2 * Math.PI / sides * i - Math.PI / 2
                pts.push({ x: cx + Math.cos(a) * r, y: cy + Math.sin(a) * r })
            }
            for (var v = 0; v < sides; v++) {
                var p = pts[v], prev = pts[(v + sides - 1) % sides], next = pts[(v + 1) % sides]
                ctx.beginPath()
                ctx.moveTo(p.x + (prev.x - p.x) * 0.3, p.y + (prev.y - p.y) * 0.3)
                ctx.lineTo(p.x, p.y)
                ctx.lineTo(p.x + (next.x - p.x) * 0.3, p.y + (next.y - p.y) * 0.3)
                ctx.stroke()
            }
        }
    }

    // Hover glow behind an item: a soft radial blob, or a flat hex (hex: true).
    // Inline components can't see root, so the caller passes vivid.
    component Halo: Canvas {
        id: halo
        property color color: "white"
        property real vivid: 1
        property bool hex: false
        property real inner: 0.5      // alpha at the center
        property real mid: 0.18       // alpha at midStop
        property real midStop: 0.5
        anchors.centerIn: parent
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 150 } }
        onVisibleChanged: if (visible) requestPaint()
        onColorChanged: requestPaint()
        Component.onCompleted: requestPaint()
        function tint(a) { return Qt.rgba(color.r, color.g, color.b, Math.min(1, a * vivid)) }
        onPaint: {
            var ctx = getContext("2d")
            ctx.reset()
            var cx = width / 2, cy = height / 2, r = width / 2
            if (hex) {
                Layouts.hexPath(ctx, cx, cy, r - 1)
                ctx.fillStyle = tint(0.35)
            } else {
                var grad = ctx.createRadialGradient(cx, cy, 0, cx, cy, r)
                grad.addColorStop(0, tint(inner))
                grad.addColorStop(midStop, tint(mid))
                grad.addColorStop(1, tint(0))
                ctx.fillStyle = grad
                ctx.beginPath()
                ctx.arc(cx, cy, r, 0, 2 * Math.PI)
            }
            ctx.fill()
        }
    }

    // Staggered pop-in for one item; replays each time trigger changes
    // (root.openCount), since the dialog keeps items alive between opens.
    component Entrance: SequentialAnimation {
        id: ent
        property Item item
        property int trigger: 0
        property int delay: 0
        property real fromScale: 0.4
        property int fadeDuration: 200
        property int scaleDuration: 300
        property real overshoot: 1.70158
        onTriggerChanged: restart()
        Component.onCompleted: start()
        PropertyAction { target: ent.item; property: "opacity"; value: 0 }
        PropertyAction { target: ent.item; property: "scale"; value: ent.fromScale }
        PauseAnimation { duration: ent.delay }
        ParallelAnimation {
            NumberAnimation { target: ent.item; property: "opacity"; to: 1; duration: ent.fadeDuration; easing.type: Easing.OutCubic }
            NumberAnimation { target: ent.item; property: "scale"; to: 1.0; duration: ent.scaleDuration; easing.type: Easing.OutBack; easing.overshoot: ent.overshoot }
        }
    }

    // ── Config ──────────────────────────────────────────────
    property var menuItems: []
    property int menuSize: 400
    property int cfgIconSize: 26
    property real bgOpacity: 0.88
    property bool showLabels: true
    property bool showSectorLines: true
    property color accentColor: Kirigami.Theme.highlightColor
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
    //   spin      — decorative HUD rings rotate
    readonly property var styles: ({
        glass:   { glow: 0.9, idleGlow: 0, rim: 0.7, depth: 1.0, body: 1.7, edge: 0.4,  sheen: 0.28, shadow: true,  spin: true },
        neon:    { glow: 1.6, idleGlow: 1, rim: 1.4, depth: 0.3, body: 0.4, edge: 0,    sheen: 0,    shadow: false, spin: true },
        minimal: { glow: 0,   idleGlow: 0, rim: 0.3, depth: 0,   body: 1.0, edge: 0.18, sheen: 0,    shadow: false, spin: false }
    })
    readonly property var st: styles[menuStyle] || styles.glass

    // Halo opacity for an item: hover falloff scaled by style, floored by idle glow
    function haloOpacity(idx) {
        return Math.min(1, Math.max(st.idleGlow * 0.4, magnifyGlow(idx) * st.glow))
    }
    function shade(c, f, a) {
        return Qt.rgba(Math.min(1, c.r * f), Math.min(1, c.g * f), Math.min(1, c.b * f), a)
    }
    // Global brightness lift for accent lines/glows and outlines: every
    // alpha through here is scaled by `vivid` (capped at 1). Dark fills use
    // shade() and are left alone so contrast doesn't wash out.
    readonly property real vivid: 1.2
    function withAlpha(c, a) { return Qt.rgba(c.r, c.g, c.b, Math.min(1, a * vivid)) }

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
        if (isHud) {
            var h = half - itemSize / 2 - 6
            return itemCount > 8 ? h / 1.5 : h   // HUD overflow ring sits at r * 1.5
        }
        // Leave room for the rotating hex frame (ticks + bands, 27px at 400)
        // around the items; its corners may use the popup's 30px margin.
        var r = Math.min(half - itemSize / 2 - 6,
                         (half + 26) * 0.866 - 31 * sizeScale - itemSize / 2)
        return itemCount > 6 ? r / 1.65 : r   // hex overflow ring sits at r * 1.65
    }

    // Visible extent in local coords, including glows, brackets and the
    // label, so the host can size its window to the content instead of the
    // full square. Round layouts keep the square plus a 30px margin (their
    // rotating frames use it); the semicircle only fills half the square,
    // so it is cropped to the half-disk for its current rotation.
    readonly property rect contentRect: {
        if (!isSemicircle) return Qt.rect(-30, -30, menuSize + 60, menuSize + 60)
        var k = sizeScale
        var R = (effectiveRadius * 2 + itemSize + 30) / 2 - 8 + 20 * k
        var arc = Layouts.semicircleArc(semicircleRotation)
        var xs = [0], ys = [0]
        function add(a) { xs.push(Math.cos(a) * R); ys.push(Math.sin(a) * R) }
        add(arc.start); add(arc.end)
        // axis extremes that fall inside the arc
        for (var q = -4; q <= 4; q++) {
            var a = q * Math.PI / 2
            var d = ((a - arc.start) % (2 * Math.PI) + 2 * Math.PI) % (2 * Math.PI)
            if (d <= Math.PI + 1e-6) add(a)
        }
        var hub = hudCoreR + 12
        xs.push(-hub, hub); ys.push(-hub, hub)
        if (showLabels) { xs.push(-70 * k, 70 * k); ys.push(centerSize / 2 + 34 * k) }
        var x0 = Math.min.apply(null, xs), x1 = Math.max.apply(null, xs)
        var y0 = Math.min.apply(null, ys), y1 = Math.max.apply(null, ys)
        return Qt.rect(centerX + x0, centerY + y0, x1 - x0, y1 - y0)
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
    readonly property bool isHud: menuLayout === "hud"
    // Layouts sharing the HUD look: reactor core, compass, brackets, readout label
    readonly property bool hudLook: isHud || isHexagonal || isSemicircle

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
    Behavior on pressT { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }
    property int launchIndex: -1
    property real popT: 0
    readonly property bool launching: launchIndex >= 0
    property int openCount: 0

    function show() {
        launchAnim.stop()
        selectedIndex = -1; activeLabel = ""; centerHovered = false
        pressedIndex = -1; pressedCenter = false; pressing = false
        launchIndex = -1; popT = 0
        openAnim.restart()
        openCount++
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
        NumberAnimation { target: root; property: "opacity"; from: 0; to: 1; duration: 250; easing.type: Easing.OutCubic }
        NumberAnimation { target: root; property: "scale"; from: 0.6; to: 1.0; duration: 380; easing.type: Easing.OutBack; easing.overshoot: 1.2 }
    }
    SequentialAnimation {
        id: closeAnim
        ParallelAnimation {
            NumberAnimation { target: root; property: "opacity"; to: 0; duration: 150; easing.type: Easing.InCubic }
            NumberAnimation { target: root; property: "scale"; to: 0.7; duration: 150; easing.type: Easing.InCubic }
        }
        ScriptAction { script: root.closeRequested() }
    }
    SequentialAnimation {
        id: launchAnim
        NumberAnimation { target: root; property: "popT"; from: 0; to: 1; duration: 180; easing.type: Easing.OutCubic }
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
            Entrance {
                item: hexItem; trigger: root.openCount
                delay: 55 * index; fromScale: 0.3; fadeDuration: 220; scaleDuration: 320; overshoot: 1.4
            }

            // Inner wrap owns hover-scale (outer hexItem.scale is driven by entrance anim)
            Item {
                id: hexHoverScale
                anchors.fill: parent
                scale: root.magnifyScale(index)
                opacity: root.fxOpacity(index)
                Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack; easing.overshoot: 2.4 } }

                // Hex glow behind (on hover, falls off across neighbors)
                Halo {
                    hex: true
                    width: parent.width + 18; height: width
                    color: accentColor; vivid: root.vivid
                    opacity: root.haloOpacity(index)
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
                    Behavior on selT { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                    property real op: root.bgOpacity
                    property var sty: root.st
                    property color accent: accentColor
                    onAccentChanged: requestPaint()
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

                        // Inner outline — HUD double edge
                        Layouts.hexPath(ctx, cx, cy, r - 4 * root.sizeScale)
                        ctx.strokeStyle = root.withAlpha(accentColor, (0.2 + 0.2 * sty.idleGlow + 0.3 * selT) * op)
                        ctx.lineWidth = 1
                        ctx.stroke()
                    }
                }

                Kirigami.Icon {
                    anchors.centerIn: parent
                    source: menuItems[index] ? menuItems[index].icon : ""
                    width: root.iconSize; height: width
                    color: hexItem.isSel ? accentColor : Kirigami.Theme.textColor
                    Behavior on color { ColorAnimation { duration: 120 } }
                }

                TargetBrackets {
                    anchors.centerIn: parent
                    width: parent.width + 14 * root.sizeScale; height: width
                    sides: 6
                    active: hexItem.isSel
                    color: accentColor
                }
            }
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
        property int n: itemCount
        property color accent: accentColor
        onNChanged: requestPaint()
        onAccentChanged: requestPaint()
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
            RotationAnimation { duration: 160; direction: RotationAnimation.Shortest; easing.type: Easing.OutCubic }
        }
        opacity: root.selectedIndex >= 0 ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

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
                ctx.strokeStyle = root.withAlpha(accent, Math.min(1, glowPass[g].a * sty.rim))
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
            Behavior on color { ColorAnimation { duration: 120 } }
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
            Entrance {
                item: wheelItem; trigger: root.openCount
                delay: 40 * index; fromScale: 0.3; fadeDuration: 200; scaleDuration: 280
            }

            // Neon glow halo behind icon — brighter on hovered item, faint on ring-neighbors
            Halo {
                width: parent.width * 2.4; height: width
                inner: 0.55; mid: 0.2; midStop: 0.45
                color: accentColor; vivid: root.vivid
                opacity: root.haloOpacity(index)
            }

            Item {
                id: wheelHoverScale
                anchors.fill: parent
                scale: root.magnifyScale(index)
                opacity: root.fxOpacity(index)
                Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack; easing.overshoot: 2.4 } }

                Kirigami.Icon {
                    anchors.centerIn: parent
                    source: menuItems[index] ? menuItems[index].icon : ""
                    width: root.iconSize + 2; height: width
                    color: root.selectedIndex === index ? accentColor : Kirigami.Theme.textColor
                    Behavior on color { ColorAnimation { duration: 120 } }
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
        Behavior on spotA { enabled: semicircleBg.spotT > 0.5; NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
        property real spotT: root.selectedIndex >= 0 ? 1 : 0
        Behavior on spotT { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
        property var sty: root.st
        property var pos: root.itemPositions
        property bool divLines: root.showSectorLines
        property color accent: accentColor
        onAccentChanged: requestPaint()
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
                spot.addColorStop(0, root.withAlpha(accentColor, Math.min(0.5, 0.3 * sty.glow) * op * spotT))
                spot.addColorStop(1, root.withAlpha(accentColor, 0))
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
                ctx.strokeStyle = root.withAlpha(accentColor, Math.min(1, rimPass[g].a * sty.rim * 1.6) * op)
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
            Entrance {
                item: circItem; trigger: root.openCount
                delay: 50 * index; fromScale: 0.4; fadeDuration: 200; scaleDuration: 300
            }

            Item {
                anchors.fill: parent
                scale: root.magnifyScale(index)
                opacity: root.fxOpacity(index)
                Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack; easing.overshoot: 2.4 } }

                // Hover glow halo
                Halo {
                    width: parent.width * 1.8; height: width
                    color: accentColor; vivid: root.vivid
                    opacity: root.haloOpacity(index)
                }

                Rectangle {
                    anchors.fill: parent; radius: width / 2
                    gradient: Gradient {
                        GradientStop {
                            position: 0.0
                            color: circItem.isSel
                                ? root.withAlpha(accentColor, 0.32 * root.bgOpacity)
                                : root.shade(Kirigami.Theme.backgroundColor, root.st.body * (1 + 0.2 * root.st.depth), 0.45 * root.bgOpacity)
                        }
                        GradientStop {
                            position: 1.0
                            color: circItem.isSel
                                ? root.withAlpha(accentColor, 0.16 * root.bgOpacity)
                                : root.shade(Kirigami.Theme.backgroundColor, root.st.body * (1 - 0.2 * root.st.depth), 0.4 * root.bgOpacity)
                        }
                    }
                    border.width: circItem.isSel ? 2 : 1
                    border.color: circItem.isSel ? accentColor
                        : root.st.idleGlow > 0 ? root.withAlpha(accentColor, 0.85 * root.bgOpacity)
                        : root.withAlpha(Kirigami.Theme.textColor, root.st.edge * root.bgOpacity)

                    // Inner ring — HUD double edge
                    Rectangle {
                        anchors.fill: parent; anchors.margins: Math.round(4 * root.sizeScale)
                        radius: width / 2
                        color: "transparent"
                        border.width: 1
                        border.color: root.withAlpha(accentColor, (0.2 + 0.2 * root.st.idleGlow + (circItem.isSel ? 0.3 : 0)) * root.bgOpacity)
                    }

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
                        Behavior on color { ColorAnimation { duration: 120 } }
                    }

                    TargetBrackets {
                        anchors.centerIn: parent
                        width: parent.width + 16 * root.sizeScale; height: width
                        active: circItem.isSel
                        spin: root.hudSpin
                        color: accentColor
                    }
                }
            }
        }
    }

    // =====================================================================
    //  HUD LAYOUT — Iron Man / JARVIS style: arc-reactor core, rotating
    //  compass + segment rings, circular HUD buttons.
    //  Core, compass and brackets are shared with hexagonal + semicircle
    //  (hudLook); the backdrop bands with hexagonal.
    // =====================================================================

    // Semicircle keeps a small core on its flat edge; the round layouts fill
    // the space inside the item ring
    readonly property real hudCoreR: isSemicircle ? Math.round(46 * sizeScale)
        : Math.max(hubSize, effectiveRadius - itemSize / 2 - (isHud ? 8 : 16) * sizeScale)
    readonly property real hudOrbR: hudCoreR * (isSemicircle ? 0.55 : 0.42)
    // Ring spin is decorative — off in Minimal, and only while shown
    // (the panel dialog keeps the menu loaded while hidden)
    readonly property bool hudSpin: hudLook && st.spin && Window.visibility !== Window.Hidden
    // Hexagonal's rotating frame: inradius just outside the outermost items,
    // so the flat sides clear every item at any rotation
    readonly property real hexFrameIn: effectiveRadius * (itemCount > 6 ? 1.65 : 1) + itemSize / 2 + 4 * sizeScale

    // Backdrop: thick translucent arc bands + thin frame circle, slow spin.
    // Pure Item rotation, so spinning never repaints the canvas.
    Canvas {
        id: hudBackdrop
        visible: isHud || isHexagonal
        z: -1
        anchors.centerIn: parent
        width: root.menuSize + (isHexagonal ? 60 : 0); height: width
        property var sty: root.st
        property real op: root.bgOpacity
        property color accent: accentColor
        property real frame: root.hexFrameIn
        property bool hex: isHexagonal
        onFrameChanged: requestPaint()
        onHexChanged: requestPaint()
        onStyChanged: requestPaint()
        onOpChanged: requestPaint()
        onAccentChanged: requestPaint()
        Component.onCompleted: requestPaint()
        RotationAnimation on rotation {
            running: root.hudSpin; loops: Animation.Infinite
            from: 0; to: 360; duration: 90000
            onStopped: hudBackdrop.rotation = 0
        }
        onPaint: {
            var ctx = getContext("2d")
            ctx.reset()
            var cx = width / 2, cy = height / 2
            var fillA = (0.08 + 0.1 * sty.idleGlow + 0.04 * sty.depth) * op
            var edgeA = (0.18 + 0.2 * sty.idleGlow) * op

            // Hexagonal: same uneven bands, but on a hex ring outside the ticks
            if (hex) {
                var k = root.sizeScale, toC = 1 / 0.866
                var cIn = (frame + 13 * k) * toC, cOut = (frame + 27 * k) * toC
                // [t0, t1] in perimeter units (1 = one edge)
                var hb = [[0.2, 1.3], [1.8, 2.4], [2.9, 4.2], [4.7, 5.1], [5.4, 5.9]]
                for (var h = 0; h < hb.length; h++) {
                    Layouts.hexBandPath(ctx, cx, cy, cIn, cOut, hb[h][0], hb[h][1])
                    ctx.fillStyle = root.withAlpha(accent, fillA)
                    ctx.fill()
                    ctx.strokeStyle = root.withAlpha(accent, edgeA)
                    ctx.lineWidth = 1
                    ctx.stroke()
                }
                Layouts.hexPath(ctx, cx, cy, (frame + 10 * k) * toC)
                ctx.strokeStyle = root.withAlpha(accent, (0.2 + 0.2 * sty.idleGlow) * op)
                ctx.stroke()
                return
            }

            var R = width / 2 - 4
            var band = 14 * root.sizeScale
            var d2r = Math.PI / 180
            // [start°, length°] — deliberately uneven, like the reference
            var bands = [[-80, 70], [8, 42], [70, 95], [188, 28], [232, 62]]
            for (var i = 0; i < bands.length; i++) {
                var a0 = bands[i][0] * d2r, a1 = (bands[i][0] + bands[i][1]) * d2r
                ctx.beginPath()
                ctx.arc(cx, cy, R, a0, a1)
                ctx.arc(cx, cy, R - band, a1, a0, true)
                ctx.closePath()
                ctx.fillStyle = root.withAlpha(accent, (0.08 + 0.1 * sty.idleGlow + 0.04 * sty.depth) * op)
                ctx.fill()
                ctx.strokeStyle = root.withAlpha(accent, (0.18 + 0.2 * sty.idleGlow) * op)
                ctx.lineWidth = 1
                ctx.stroke()
            }
            ctx.beginPath()
            ctx.arc(cx, cy, R - band - 6 * root.sizeScale, 0, 2 * Math.PI)
            ctx.strokeStyle = root.withAlpha(accent, (0.2 + 0.2 * sty.idleGlow) * op)
            ctx.lineWidth = 1
            ctx.stroke()
        }
    }

    // Compass ring just outside the item orbit: ticks, N/E/S/W, markers.
    // Counter-rotates slower than the backdrop.
    Canvas {
        id: hudCompass
        visible: hudLook
        z: -1
        anchors.centerIn: parent
        width: root.menuSize + 60; height: width
        property var sty: root.st
        property real op: root.bgOpacity
        // Outermost button orbit, so the compass never runs under buttons
        property real orbit: root.effectiveRadius
            * (isHud && root.itemCount > 8 ? 1.5 : isHexagonal && root.itemCount > 6 ? 1.65 : 1)
        property string lay: root.menuLayout
        property real rot: root.semicircleRotation
        property real frame: root.hexFrameIn
        onFrameChanged: requestPaint()
        onLayChanged: requestPaint()
        onRotChanged: requestPaint()
        property color accent: accentColor
        onStyChanged: requestPaint()
        onOpChanged: requestPaint()
        onOrbitChanged: requestPaint()
        onAccentChanged: requestPaint()
        Component.onCompleted: requestPaint()
        // Semicircle's ticks must stay on its arc, so it never spins
        RotationAnimation on rotation {
            running: root.hudSpin && !isSemicircle; loops: Animation.Infinite
            from: 360; to: 0; duration: 140000
            onStopped: hudCompass.rotation = 0
        }
        onPaint: {
            var ctx = getContext("2d")
            ctx.reset()
            var cx = width / 2, cy = height / 2
            var k = root.sizeScale
            var r0 = orbit + root.itemSize / 2 + 4 * k
            var a = Math.min(1, 0.55 + 0.3 * sty.idleGlow) * op

            // Hexagonal: ticks perpendicular to each side of a hex frame,
            // markers pointing in from the six corners
            if (root.isHexagonal) {
                var toC = 1 / 0.866, C = frame * toC
                for (var ht = 0; ht < 72; ht++) {
                    var tt = ht / 12
                    var p0 = Layouts.hexPoint(cx, cy, C, tt)
                    var edge = Math.floor(tt) % 6
                    var na = Math.PI / 3 * edge - Math.PI / 3       // outward normal of this edge
                    var hmaj = ht % 6 === 0
                    var hl = (hmaj ? 9 : 4) * k
                    ctx.beginPath()
                    ctx.moveTo(p0.x, p0.y)
                    ctx.lineTo(p0.x + Math.cos(na) * hl, p0.y + Math.sin(na) * hl)
                    ctx.strokeStyle = root.withAlpha(accent, (hmaj ? 0.8 : 0.4) * a)
                    ctx.lineWidth = hmaj ? 1.5 : 1
                    ctx.stroke()
                }
                Layouts.hexPath(ctx, cx, cy, C)
                ctx.strokeStyle = root.withAlpha(accent, 0.3 * a)
                ctx.lineWidth = 1
                ctx.stroke()
                for (var hv = 0; hv < 6; hv++) {
                    var va = Math.PI / 3 * hv - Math.PI / 2
                    var vt = C - 1 * k, vb = C + 9 * k, vw = 0.035
                    ctx.beginPath()
                    ctx.moveTo(cx + Math.cos(va) * vt, cy + Math.sin(va) * vt)
                    ctx.lineTo(cx + Math.cos(va - vw) * vb, cy + Math.sin(va - vw) * vb)
                    ctx.lineTo(cx + Math.cos(va + vw) * vb, cy + Math.sin(va + vw) * vb)
                    ctx.closePath()
                    ctx.fillStyle = root.withAlpha(accent, 0.85 * a)
                    ctx.fill()
                }
                return
            }

            var arc = root.isSemicircle ? Layouts.semicircleArc(rot) : null
            function inArc(ang) {
                if (!arc) return true
                var d = ((ang - arc.start) % (2 * Math.PI) + 2 * Math.PI) % (2 * Math.PI)
                return d <= arc.end - arc.start + 1e-6
            }

            // Orbit line through the item centers + dashed inner guide
            // (semicircle already has its own track band)
            if (!arc) {
            ctx.beginPath()
            ctx.arc(cx, cy, orbit, 0, 2 * Math.PI)
            ctx.strokeStyle = root.withAlpha(accent, 0.45 * a)
            ctx.lineWidth = 1
            ctx.stroke()
            var inner = orbit - root.itemSize / 2 - 3 * k
            for (var s = 0; s < 72; s += 2) {
                ctx.beginPath()
                ctx.arc(cx, cy, inner, s * Math.PI / 36, (s + 1) * Math.PI / 36)
                ctx.strokeStyle = root.withAlpha(accent, 0.35 * a)
                ctx.stroke()
            }
            }

            // Ticks every 5°, long every 30°
            for (var t = 0; t < 72; t++) {
                var ang = t * Math.PI / 36
                if (!inArc(ang)) continue
                var major = t % 6 === 0
                var len = (major ? 9 : 4) * k
                ctx.beginPath()
                ctx.moveTo(cx + Math.cos(ang) * r0, cy + Math.sin(ang) * r0)
                ctx.lineTo(cx + Math.cos(ang) * (r0 + len), cy + Math.sin(ang) * (r0 + len))
                ctx.strokeStyle = root.withAlpha(accent, (major ? 0.8 : 0.4) * a)
                ctx.lineWidth = major ? 1.5 : 1
                ctx.stroke()
            }

            // Cardinal letters + inward-pointing markers (full circles only)
            if (arc) return
            var letters = ["N", "E", "S", "W"]
            ctx.font = "bold " + Math.round(10 * k) + "px sans-serif"
            ctx.textAlign = "center"
            ctx.textBaseline = "middle"
            for (var c = 0; c < 4; c++) {
                var ca = c * Math.PI / 2 - Math.PI / 2 + Math.PI / 12
                var lr = r0 + 17 * k
                ctx.fillStyle = root.withAlpha(accent, 0.75 * a)
                ctx.fillText(letters[c], cx + Math.cos(ca) * lr, cy + Math.sin(ca) * lr)

                var ma = c * Math.PI / 2 - Math.PI / 2
                var tip = r0 - 1 * k, base = r0 + 8 * k, w = 0.035
                ctx.beginPath()
                ctx.moveTo(cx + Math.cos(ma) * tip, cy + Math.sin(ma) * tip)
                ctx.lineTo(cx + Math.cos(ma - w) * base, cy + Math.sin(ma - w) * base)
                ctx.lineTo(cx + Math.cos(ma + w) * base, cy + Math.sin(ma + w) * base)
                ctx.closePath()
                ctx.fillStyle = root.withAlpha(accent, 0.85 * a)
                ctx.fill()
            }
        }
    }

    // Arc-reactor core: dark disc, segment-block ring, rim, hex-patterned orb
    Item {
        id: hudCore
        visible: hudLook
        anchors.centerIn: parent
        width: root.hudCoreR * 2 + 24; height: width

        Canvas {
            id: hudCoreCanvas
            anchors.fill: parent
            property var sty: root.st
            property real op: root.bgOpacity
            property real coreR: root.hudCoreR
            property bool hov: root.centerHovered
            property color accent: accentColor
            onStyChanged: requestPaint()
            onOpChanged: requestPaint()
            onCoreRChanged: requestPaint()
            onHovChanged: requestPaint()
            onAccentChanged: requestPaint()
            Component.onCompleted: requestPaint()
            onPaint: {
                var ctx = getContext("2d")
                ctx.reset()
                var cx = width / 2, cy = height / 2
                var R = coreR, orbR = root.hudOrbR
                var bg = Kirigami.Theme.backgroundColor

                // Dark disc with a faint accent edge tint
                var disc = ctx.createRadialGradient(cx, cy, 0, cx, cy, R)
                disc.addColorStop(0, root.shade(bg, 0.35 * sty.body, 0.85 * op))
                disc.addColorStop(0.8, root.shade(bg, 0.45 * sty.body, 0.8 * op))
                disc.addColorStop(1, root.withAlpha(accent, (0.15 + 0.15 * sty.idleGlow) * op))
                ctx.save()
                if (sty.shadow) {
                    ctx.shadowColor = Qt.rgba(0, 0, 0, 0.4 * op)
                    ctx.shadowBlur = 10
                }
                ctx.beginPath()
                ctx.arc(cx, cy, R, 0, 2 * Math.PI)
                ctx.fillStyle = disc
                ctx.fill()
                ctx.restore()

                // Segment blocks — ~2/3 lit, the rest dim, like a charge gauge
                var nb = 36, bIn = R * 0.68, bOut = R * 0.9
                var slot = 2 * Math.PI / nb
                for (var b = 0; b < nb; b++) {
                    var s0 = b * slot - Math.PI / 2 + slot * 0.15
                    var s1 = s0 + slot * 0.7
                    ctx.beginPath()
                    ctx.arc(cx, cy, bOut, s0, s1)
                    ctx.arc(cx, cy, bIn, s1, s0, true)
                    ctx.closePath()
                    var lit = b < nb * 0.66
                    ctx.fillStyle = root.withAlpha(accent, (lit ? 0.35 + 0.3 * sty.idleGlow : 0.1) * op)
                    ctx.fill()
                }

                // Rim — glow passes in neon
                var rim = sty.idleGlow > 0 ? [{ w: 8, a: 0.12 }, { w: 4, a: 0.25 }, { w: 1.5, a: 0.95 }]
                                           : [{ w: 1.5, a: Math.min(1, 0.7 * sty.rim + 0.2) }]
                for (var g = 0; g < rim.length; g++) {
                    ctx.beginPath()
                    ctx.arc(cx, cy, R, 0, 2 * Math.PI)
                    ctx.strokeStyle = root.withAlpha(accent, rim[g].a * op)
                    ctx.lineWidth = rim[g].w
                    ctx.stroke()
                }

                // Orb: lit from upper-left, accent-tinted, brighter on hover
                var hx = cx - orbR * 0.35, hy = cy - orbR * 0.35
                var orb = ctx.createRadialGradient(hx, hy, 0, cx, cy, orbR)
                var boost = hov ? 1.3 : 1.0
                orb.addColorStop(0, root.withAlpha(accent, Math.min(1, 0.55 * boost) * op))
                orb.addColorStop(0.55, root.shade(accent, 0.35, 0.85 * op))
                orb.addColorStop(1, root.shade(bg, 0.25, 0.95 * op))
                ctx.beginPath()
                ctx.arc(cx, cy, orbR, 0, 2 * Math.PI)
                ctx.fillStyle = orb
                ctx.fill()

                // Hex armor pattern clipped to the orb
                ctx.save()
                ctx.beginPath()
                ctx.arc(cx, cy, orbR - 1, 0, 2 * Math.PI)
                ctx.clip()
                var hr = Math.max(4, orbR * 0.22)
                var dx = hr * Math.sqrt(3), dy = hr * 1.5
                for (var row = -4; row <= 4; row++) {
                    for (var col = -4; col <= 4; col++) {
                        var px = cx + col * dx + (row % 2 ? dx / 2 : 0)
                        var py = cy + row * dy
                        var dist = Math.sqrt((px - cx) * (px - cx) + (py - cy) * (py - cy))
                        if (dist > orbR + hr) continue
                        Layouts.hexPath(ctx, px, py, hr * 0.86)
                        ctx.strokeStyle = root.withAlpha(accent, (0.25 + 0.35 * (1 - dist / orbR)) * boost * op)
                        ctx.lineWidth = 1
                        ctx.stroke()
                    }
                }
                ctx.restore()

                ctx.beginPath()
                ctx.arc(cx, cy, orbR, 0, 2 * Math.PI)
                ctx.strokeStyle = root.withAlpha(accent, (hov ? 0.95 : 0.6) * op)
                ctx.lineWidth = 1.5
                ctx.stroke()
            }
        }

        // Sweep: bright arc with a fading tail, orbiting the block ring
        Canvas {
            id: hudSweep
            anchors.fill: parent
            visible: root.st.glow > 0
            property real coreR: root.hudCoreR
            property color accent: accentColor
            onCoreRChanged: requestPaint()
            onAccentChanged: requestPaint()
            Component.onCompleted: requestPaint()
            RotationAnimation on rotation {
                running: root.hudSpin; loops: Animation.Infinite
                from: 0; to: 360; duration: 6000
            }
            onPaint: {
                var ctx = getContext("2d")
                ctx.reset()
                var cx = width / 2, cy = height / 2, r = coreR * 0.95
                var steps = 14, span = Math.PI * 0.45
                for (var i = 0; i < steps; i++) {
                    var t = i / steps
                    ctx.beginPath()
                    ctx.arc(cx, cy, r, -Math.PI / 2 + span * t, -Math.PI / 2 + span * (t + 1 / steps) + 0.01)
                    ctx.strokeStyle = root.withAlpha(accent, 0.9 * t * root.bgOpacity)
                    ctx.lineWidth = 3
                    ctx.stroke()
                }
            }
        }

        transform: Scale { origin.x: hudCore.width / 2; origin.y: hudCore.height / 2; xScale: root.centerFxScale; yScale: xScale }

        Kirigami.Icon {
            anchors.centerIn: parent
            source: root.centerIcon
            width: root.hubIconSize; height: width
            color: root.centerHovered ? accentColor : Kirigami.Theme.textColor
            Behavior on color { ColorAnimation { duration: 120 } }
        }
    }

    // HUD buttons: dark disc, double accent outline, targeting brackets on hover
    Repeater {
        model: isHud ? itemCount : 0
        Item {
            id: hudItem
            width: root.itemSize; height: root.itemSize
            readonly property bool isSel: root.selectedIndex === index
            readonly property var pos: index < itemPositions.length ? itemPositions[index] : null
            x: pos ? pos.x - width / 2 : 0
            y: pos ? pos.y - height / 2 : 0
            transform: Scale { origin.x: hudItem.width / 2; origin.y: hudItem.height / 2; xScale: root.fxScale(index); yScale: xScale }

            opacity: 0; scale: 0.4
            Entrance {
                item: hudItem; trigger: root.openCount
                delay: 45 * index; fromScale: 0.4; fadeDuration: 200; scaleDuration: 300
            }

            Item {
                anchors.fill: parent
                scale: root.magnifyScale(index)
                opacity: root.fxOpacity(index)
                Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack; easing.overshoot: 2.4 } }

                Halo {
                    width: parent.width * 1.8; height: width
                    color: accentColor; vivid: root.vivid
                    opacity: root.haloOpacity(index)
                }

                Rectangle {
                    anchors.fill: parent; radius: width / 2
                    color: hudItem.isSel
                        ? root.withAlpha(accentColor, 0.28 * root.bgOpacity)
                        : root.shade(Kirigami.Theme.backgroundColor, 0.4 * root.st.body, 0.75 * root.bgOpacity)
                    border.width: hudItem.isSel ? 2 : 1.5
                    border.color: root.withAlpha(accentColor,
                        (hudItem.isSel ? 1 : Math.min(1, 0.45 + 0.4 * root.st.idleGlow + 0.1 * root.st.rim)) * root.bgOpacity)
                    Behavior on color { ColorAnimation { duration: 120 } }

                    Rectangle {
                        anchors.fill: parent; anchors.margins: Math.round(4 * root.sizeScale)
                        radius: width / 2
                        color: "transparent"
                        border.width: 1
                        border.color: root.withAlpha(accentColor, (0.2 + 0.2 * root.st.idleGlow) * root.bgOpacity)
                    }
                    Rectangle {
                        visible: root.st.sheen > 0
                        anchors.fill: parent; anchors.margins: 2
                        radius: width / 2
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, root.st.sheen * 0.8 * root.bgOpacity) }
                            GradientStop { position: 0.5; color: Qt.rgba(1, 1, 1, 0) }
                        }
                    }
                    Kirigami.Icon {
                        anchors.centerIn: parent
                        source: menuItems[index] ? menuItems[index].icon : ""
                        width: root.iconSize; height: width
                        color: hudItem.isSel || root.st.idleGlow > 0 ? accentColor : Kirigami.Theme.textColor
                        Behavior on color { ColorAnimation { duration: 120 } }
                    }
                }

                TargetBrackets {
                    anchors.centerIn: parent
                    width: parent.width + 16 * root.sizeScale; height: width
                    active: hudItem.isSel
                    spin: root.hudSpin
                    color: accentColor
                }
            }
        }
    }

    // =====================================================================
    //  LABEL
    // =====================================================================
    PlasmaComponents.Label {
        visible: showLabels
        anchors.horizontalCenter: parent.horizontalCenter
        // HUD: uppercase accent readout tucked under the orb
        // HUD look: uppercase accent readout — under the orb inside the
        // core on round layouts, below the flat edge on semicircle
        y: (isHud || isHexagonal) ? centerY + hudOrbR + 4 * sizeScale : centerY + centerSize / 2 + 12 * sizeScale
        text: hudLook ? activeLabel.toUpperCase() : activeLabel
        font.weight: Font.Bold; font.pointSize: hudLook ? 9 : 11; font.letterSpacing: hudLook ? 2 : 0.5
        color: hudLook ? accentColor : Kirigami.Theme.textColor
        opacity: activeLabel !== "" ? 1.0 : 0.0
        scale: activeLabel !== "" ? 1.0 : 0.85
        Behavior on opacity { NumberAnimation { duration: 100 } }
        Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
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

            var centerR = isWheel ? wheelInnerR - 4 : hudLook ? Math.max(hudOrbR, centerSize / 2) : centerSize / 2
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
