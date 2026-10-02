# cosas roblox

Scripts del juego `cosas roblox` versionados con Git y mapeados con Rojo 7.

## Flujo de trabajo

- `rojo sourcemap default.project.json` muestra el mapeo de scripts.
- `rojo serve default.project.json` inicia la sincronización en vivo con Roblox Studio; conecta el plugin Rojo de Studio al servidor local.
- Usa Git para guardar cambios (`git add`, `git commit`) y sincronizarlos con un remoto (`git push`).

El proyecto incluye los scripts que estaban en Studio al exportarlos. El árbol de Rojo ignora instancias desconocidas para conservar el resto del lugar y los objetos no exportados dentro de `Workspace.R6_Dummy`.