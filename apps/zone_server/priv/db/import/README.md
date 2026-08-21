# Import overlay

Place local YAML customizations here. Files load after shipped data in lexicographic order, so the last matching entry wins.

Keyed databases replace an entire entry by key. List databases (`spawns`, `warps`, and `shops`) are append-only. Map-shaped databases merge by top-level key.

The tree mirrors shipped data: `import/items/*.yml`, `import/refine/refine.yml`, `import/arrows.yml`, and so on. Restart the server after changes, or use the relevant reload operation where available.
