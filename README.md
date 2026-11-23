# Lumber Tycoon Wire Art Lasso PRO

A local-only screen-space lasso that turns a visible selection into a JSON blueprint.

## Use
1. Run `WireArtCopier.lua` in your local client script environment.
2. Choose **FILTER: ALL PARTS** or **FILTER: WIRE-NAMED ONLY**.
3. Tap **START LASSO**, trace around the visible artwork, and release.
4. Blue outlines show the parts included in the capture.
5. Tap **COPY BLUEPRINT JSON** to export the design data.

## Improvements
- Touch and mouse lasso input.
- Screen-space polygon selection.
- Selects parts whose projected screen-space bounds overlap the lasso, not only parts whose centers are inside.
- Optional wire-name filter for games that use descriptive part names.
- Local selection highlights, cancel, clear, draggable panel, and JSON export.
- Stores position relative to the center of the captured part bounds, rotation, size, color, material, and transparency.

## Limitations and permissions
- Captures only locally replicated BaseParts that are visible in the current client view.
- The all-parts filter may include scenery or nearby objects if they overlap the lasso; use wire-named filter to narrow the result.
- It is a blueprint exporter, not an automatic copier/placer. It does not call game remotes, change server state, or duplicate another player's placed objects.
- Rebuild only where you have permission.
