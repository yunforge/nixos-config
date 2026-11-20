/*
 * Keep KWin quick tiles away from the work area and each other.
 *
 * KWin 6.8 creates every quick tile with padding 0 (src/quicktile.cpp), so
 * Meta+Left/Right and drag-to-edge tiling touch the panel/Dock and the
 * neighbouring tiled window. KWin does not expose quickTileMode to scripts,
 * but Window.tile points at the active tile for both quick and custom layouts.
 */
(function () {
    var GAP = 8;

    function applyGap(window) {
        var tile = window.tile;
        if (tile && tile.padding !== GAP) {
            tile.padding = GAP;
        }
    }

    function watch(window) {
        window.tileChanged.connect(function () {
            applyGap(window);
        });
        applyGap(window);
    }

    var windows = workspace.windowList();
    for (var i = 0; i < windows.length; ++i) {
        watch(windows[i]);
    }
    workspace.windowAdded.connect(watch);
})();
