# Biome Mason Brick

[![Powered by Mason](https://img.shields.io/endpoint?url=https%3A%2F%2Ftinyurl.com%2Fmason-badge)](https://github.com/felangel/mason)

A [Mason](https://github.com/felangel/mason) brick to seamlessly add [Biome](https://biomejs.dev/) dependencies, scripts, and configuration rules (`biome.json`) to any JavaScript, TypeScript, or Bun project.

---

## Features

- 🔍 **Recursive `package.json` Discovery**: Scans the project root and all subdirectories for `package.json` files (excluding `node_modules`, `.git`, `dist`, `.turbo`, etc.).
- ⚡ **Bun.js Detection**: Automatically detects Bun projects by checking for `bun.lock`, `bun.lockb`, `bunfig.toml`, or `packageManager` configurations.
- 💡 **Smart Package Manager Inference**: Inspects lockfiles (`bun.lock`, `pnpm-lock.yaml`, `yarn.lock`, `package-lock.json`) and package configurations to infer the default package manager.
- 🎯 **Interactive Selection**:
  - Prompts you to pick which `package.json` file should receive the Biome dependency (ideal for monorepos with sub-packages!).
  - Prompts you to confirm or choose the package manager (`bun`, `pnpm`, `npm`, `yarn`).
  - Prompts to optionally add Biome scripts (`check`, `lint`, `format`) to `package.json`.
  - Prompts where to place `biome.json` (project root or package subfolder).
  - Prompts whether to run the package manager install command immediately.
- 🚀 **`biome.json` Template Generation**:
  - Automatically generated from Mason's `__brick__/biome.json` template with recommended defaults:
    - 2-space indentation (`indentStyle: "space"`, `indentWidth: 2`)
    - Single quotes for JavaScript/TypeScript (`quoteStyle: "single"`)
    - Standard ignore list (`node_modules`, `dist`, `build`, `.next`, `.turbo`, `coverage`)
    - VCS Git integration (automatically enabled when `.git` is detected)
  - Automatically placed at the project root or moved to the chosen package directory based on your selection.

---

## Installation

### From Git

```bash
mason add biome --git-url https://github.com/sanathkumarbs/biome.git
```

### Locally (for development)

In your `mason.yaml`:

```yaml
bricks:
  biome:
    path: .
```

Then install the brick:

```bash
mason get
```

---

## Usage

Navigate to your project directory and run:

```bash
mason make biome
```

### Example Walkthrough

```text
🔍 Analyzing project at /workspace/my-app...
⚡ Detected Bun.js project.
? Select the package.json where the Biome dependency should be added: › ./apps/web/package.json
💡 Inferred package manager: bun
? Select the package manager to be used: › bun
? Add Biome scripts ("lint", "format", "check") to package.json? › Yes
? Where would you like to place biome.json? › Project root (./biome.json)
? Run "bun" to install @biomejs/biome now? › Yes
✔ Added @biomejs/biome to ./apps/web/package.json devDependencies
✔ Generated biome.json
✔ Installed @biomejs/biome successfully!

✨ Biome setup completed successfully!

Next steps:
  • Check code:    bun run check
  • Format code:   bun run format
  • Lint code:     bun run lint
```

---

## Generated & Modified Files

- **`biome.json`**: Generated from `__brick__/biome.json` template and configured with formatting, linter, VCS, and ignore rules.
- **`package.json`**: Updated with:
  - `"@biomejs/biome": "^1.9.4"` in `devDependencies`.
  - `"check": "biome check ."`, `"lint": "biome lint ."`, and `"format": "biome format --write ."` in `scripts`.

---

## License

MIT
