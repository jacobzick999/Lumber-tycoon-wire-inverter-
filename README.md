# Lumber Tycoon Wire Art Lasso

A local-only visual blueprint helper.

## How to use
1. Run `WireArtCopier.lua` in your local client script environment.
2. Look at the wire-art design and tap **START LASSO**.
3. Drag your finger around the visible artwork, then release.
4. The script records matching visible wire-named parts enclosed by the lasso.
5. Tap **COPY BLUEPRINT JSON** to save the captured layout data.

The blueprint records positions relative to your character at capture time, rotations, sizes, colors, materials, and transparency.

## Limits and permissions
- This is a visual selection and blueprint exporter, not an automatic copier or placer.
- It does not call game remotes, modify server state, or duplicate another player's placed objects.
- It can only capture locally replicated parts whose names include `wire`, `cable`, `connector`, or `wiring`.
- Only parts whose projected center is inside the lasso and currently on screen are captured.
- Use the blueprint as a reference to rebuild where you have permission.
