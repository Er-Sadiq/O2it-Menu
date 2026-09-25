.pragma library

function getPositions(layout, n, radius, cx, cy, rotationDeg, innerRadius, itemSize) {
    if (n <= 0) return []
    switch (layout) {
        case "semicircle": return semicircle(n, radius, cx, cy, rotationDeg || 0, itemSize || 0)
        case "wheel":      return wheel(n, radius, innerRadius, cx, cy)
        case "hud":        return hud(n, radius, cx, cy)
        // "radial" was this layout's old id before it was renamed to
        // "hexagonal" — old saved configs with that value fall through here.
        default:           return hexagonal(n, radius, cx, cy)
    }
}

// Semicircle spans exactly Math.PI radians; rotationDeg rotates the whole arc
// around the center (0 = open end pointing down / arc bulges up, matching
// the original default). Shared with the half-disk background drawing so the
// icons always sit inside the arc that's actually drawn.
function semicircleArc(rotationDeg) {
    var rot = (rotationDeg || 0) * Math.PI / 180
    return { start: -Math.PI + rot, end: rot }
}

// n <= 6: evenly spaced on one ring. n > 6: first 6 on the ring at radius r
// (fixed 60° hex slots), the rest fan out onto a second ring at r*1.65
// (honeycomb overflow).
function hexagonal(n, r, cx, cy) {
    var pos = []
    if (n <= 6) {
        for (var i = 0; i < n; i++) {
            var a = (2 * Math.PI / n) * i - Math.PI / 2
            pos.push({ x: cx + Math.cos(a) * r, y: cy + Math.sin(a) * r, angle: a })
        }
        return pos
    }
    for (var i = 0; i < 6; i++) {
        var a = (2 * Math.PI / 6) * i - Math.PI / 2
        pos.push({ x: cx + Math.cos(a) * r, y: cy + Math.sin(a) * r, angle: a })
    }
    var ring2 = Math.min(n - 6, 12)
    var r2 = r * 1.65
    for (var j = 0; j < ring2; j++) {
        var a2 = (2 * Math.PI / ring2) * j - Math.PI / 2 + Math.PI / ring2
        pos.push({ x: cx + Math.cos(a2) * r2, y: cy + Math.sin(a2) * r2, angle: a2 })
    }
    return pos
}

// End items are pulled in from the flat edge by just enough angle that the
// whole item (plus a small margin) sits inside the half-disk.
function semicircle(n, r, cx, cy, rotationDeg, itemSize) {
    var arc = semicircleArc(rotationDeg)
    var inset = r > 0 ? Math.asin(Math.min(1, (itemSize / 2 + 4) / r)) : 0
    inset = Math.min(inset, Math.PI / 4)
    var start = arc.start + inset, end = arc.end - inset
    var pos = []
    for (var i = 0; i < n; i++) {
        var a = (n === 1) ? (start + end) / 2 : start + (end - start) / (n - 1) * i
        pos.push({ x: cx + Math.cos(a) * r, y: cy + Math.sin(a) * r, angle: a })
    }
    return pos
}

// HUD: up to 8 buttons evenly on one orbit starting at the top; extras
// fan onto an outer orbit at r*1.5, offset by half an inner slot so they
// sit between (not behind) the inner buttons.
function hud(n, r, cx, cy) {
    var pos = []
    var first = Math.min(n, 8)
    for (var i = 0; i < first; i++) {
        var a = (2 * Math.PI / first) * i - Math.PI / 2
        pos.push({ x: cx + Math.cos(a) * r, y: cy + Math.sin(a) * r, angle: a })
    }
    var rest = Math.min(n - first, 16)
    for (var j = 0; j < rest; j++) {
        var a2 = (2 * Math.PI / rest) * j - Math.PI / 2 + Math.PI / first
        pos.push({ x: cx + Math.cos(a2) * r * 1.5, y: cy + Math.sin(a2) * r * 1.5, angle: a2 })
    }
    return pos
}

// Wheel/pie layout: icons sit at the midpoint of the donut ring.
// outerR/innerR are passed in directly so the caller's centerGap logic
// (which shifts outerR but keeps the hub/innerR fixed) is the only source
// of truth — no radius math duplicated here.
function wheel(n, outerR, innerR, cx, cy) {
    var midR = (outerR + innerR) / 2
    var pos = []
    for (var i = 0; i < n; i++) {
        var a = (2 * Math.PI / n) * i - Math.PI / 2
        pos.push({ x: cx + Math.cos(a) * midR, y: cy + Math.sin(a) * midR, angle: a })
    }
    return pos
}

function hasSectors(layout) {
    return false  // sectors now drawn differently per layout
}

function hasDividers(layout) {
    return false  // dividers drawn via Canvas per layout
}

// Draw a pointy-top hexagon path on a Canvas context
function hexPath(ctx, cx, cy, r) {
    ctx.beginPath()
    for (var i = 0; i < 6; i++) {
        var a = Math.PI / 3 * i - Math.PI / 2
        var px = cx + r * Math.cos(a)
        var py = cy + r * Math.sin(a)
        if (i === 0) ctx.moveTo(px, py)
        else ctx.lineTo(px, py)
    }
    ctx.closePath()
}
