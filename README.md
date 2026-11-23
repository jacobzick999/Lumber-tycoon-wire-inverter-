# Lumber Tycoon Wire Art Copier

A local-only visual blueprint helper for Roblox.

## What it does
- Scans nearby replicated BaseParts whose names contain `wire`, `cable`, `connector`, or `wiring`.
- Records each match's position and rotation relative to your character, size, color, material, and transparency.
- Exports the scan as JSON using the executor clipboard function when available.
- Includes a draggable, touch-friendly panel.

## What it does not do
- It does not fire RemoteEvents or RemoteFunctions.
- It does not change server-owned objects, duplicate another player's build, or automatically place parts.
- A blueprint is a visual reference for rebuilding on a base where you have permission.

## Use
1. Open `WireArtCopier.lua` in your local client script environment.
2. Stand near the design and press **SCAN NEARBY WIRE ART**.
3. Press **COPY BLUEPRINT TO CLIPBOARD** to copy the JSON.
4. Paste the JSON into a text file to keep the blueprint.

## Limitations
The scanner uses part names to identify wire pieces. If a game's wire parts have generic names, the scan may miss them. The scan radius is 250 studs from your character.
