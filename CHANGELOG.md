# 0.1.0+1

- Initial release of the `biome` Mason brick.
- Scan for all `package.json` files in target folder and subdirectories.
- Detect Bun.js projects (`bun.lock`, `bun.lockb`, `bunfig.toml`).
- Infer package manager (Bun, pnpm, yarn, npm).
- Interactive prompts for target `package.json` and package manager.
- Add `@biomejs/biome` to devDependencies.
- Generate standard `biome.json` with recommended lint and format rules.
- Optional automatic package install and script additions.
