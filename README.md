# Lumber Tycoon Wire Art Lasso PRO

A local-only screen-space lasso and 3D blueprint preview tool.

## Use
1. Run `WireArtCopier.lua` in your local client script environment.
2. Choose **FILTER: ALL PARTS** or **FILTER: WIRE-NAMED ONLY**.
3. Tap **START LASSO**, trace around visible artwork, and release.
4. Blue outlines show the selected parts.
5. Tap **PREVIEW 3D BLUEPRINT** to create a temporary local preview in front of your camera. Tap it again to hide it.
6. Tap **COPY BLUEPRINT JSON** to export the design data.

## Features
- Touch and mouse freehand lasso.
- Screen-space selection checks projected part bounds against the lasso.
- Optional wire-name filter.
- Local selection highlights.
- Temporary 3D preview using captured position, rotation, size, color, material, and transparency.
- Preview toggle, cancel, clear, draggable/minimizable panel, and JSON export.

## Limitations and permissions
- Captures locally replicated BaseParts that are visible in the current client view.
- The all-parts filter may include scenery or nearby objects overlapping the lasso.
- The 3D preview is a temporary client-side visualization in front of the camera; it is not placed on a base or saved to the game.
- It does not call game remotes, modify server state, or duplicate another player's placed objects.
- Rebuild only where you have permission.
