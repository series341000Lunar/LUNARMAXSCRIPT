# LUNARMAXSCRIPT

Personal production-assistance tools for Autodesk 3ds Max.

This repository collects multiple MAXScript tools. Each tool lives in its own top-level directory with its source, launcher, and tool-specific documentation.

## Tools

### Lunar Transform Assistant

Transform, controller, base-object, visibility, and transform-lock utility for Autodesk 3ds Max.

- [Documentation](LunarTransformAssistant/README.md)
- [MAXScript Source](LunarTransformAssistant/src/LunarTransformAssistant.ms)
- [MacroScript Launcher](LunarTransformAssistant/macros/LunarTransformAssistant.mcr)

### Lunar Material ID Normalizer

Normalizes Editable Poly face Material IDs and Multi/Sub-Object material assignments to a selected Master object.

- Documentation: [한국어](LunarMaterialIDNormalizer/README.md) · [Català](LunarMaterialIDNormalizer/README.ca.md)
- [MAXScript Source](LunarMaterialIDNormalizer/src/LunarMaterialIDNormalizer.ms)

## Repository Structure

Shared repository files remain at the root. Each tool has a dedicated top-level directory containing its documentation and implementation files.

```text
LUNARMAXSCRIPT/
├── README.md
├── LICENSE
├── .gitignore
├── AGENTS.md
└── LunarTransformAssistant/
    ├── README.md
    ├── src/
    │   └── LunarTransformAssistant.ms
    └── macros/
        └── LunarTransformAssistant.mcr
```

## License

This repository is licensed under the GNU General Public License v3.0.

See [LICENSE](LICENSE) for details.
