# Pipeline pixel art y rendimiento (fase 2)

Esta fase decide **cómo se ve** el juego (pixel art en 3D) y **cuánto aguanta** un celular de gama media. Todo es arte de relleno: un espantapájaros y un necrófago dibujados en 20x36 y 24x32 píxeles.

## Cómo se dibuja el mundo

```
Mundo 3D ──► cámara espejo ──► SubViewport chiquito (p. ej. 216x480)
                                      │  se estira x5 con filtro "nearest"
                                      ▼
                    pantalla completa (1080x2400)  ◄── HUD y botones nítidos encima
```

- **Autoload `Graphics`** (`core/graphics/graphics.gd`) hace todo, en cualquier escena, sin tocar las escenas del juego:
  1. Apaga el 3D de la ventana principal (`root.disable_3d`).
  2. Un `SubViewport` que comparte el **mismo mundo** dibuja con una cámara que copia a la del jugador cada frame (posición, FOV, sacudida).
  3. Un `TextureRect` estira esa imagen a toda la pantalla con filtro **nearest** (cada píxel se vuelve un cuadrito, sin difuminar).
  4. El HUD, los botones y el duelo se dibujan encima a resolución completa: el texto se sigue leyendo bien.
- **Analogía web:** dibujar en un `<canvas width="216" height="480">` y mostrarlo con CSS `width: 100%; image-rendering: pixelated`, mientras los botones del DOM siguen nítidos.
- **Factor entero:** cada píxel del mundo mide exactamente N×N píxeles reales (x5 en una pantalla de 2400 de alto). Con factores con decimales unas columnas saldrían más anchas que otras.
- **Resoluciones** (Ajustes > Gráficos y rendimiento), contadas en píxeles de alto: Nativa, 640, **480 (default)**, 360, 270. El ancho sale de la forma de tu pantalla (en 20:9, 480 de alto son 216 de ancho).

## NPCs como billboards

- Los enemigos son `Sprite3D` con `billboard = Y` (giran para mirarte, pero solo de lado, como en Doom), textura con filtro nearest y `alpha_cut = discard` (los bordes transparentes se recortan: es más barato que mezclar transparencias y no hay que ordenarlos).
- No proyectan sombra: una sombra de un dibujo plano que gira se ve rara. Si hace falta, después se pone una "mancha" de sombra debajo.
- Los muñecos de práctica del nivel ahora son un espantapájaros billboard (`world/greybox/training_dummy.tscn`). Al golpearlos se ponen rojos y se aplastan.

## Monitor de rendimiento

Arriba a la izquierda (se activa en Ajustes > "Monitor de rendimiento completo"):

| Línea | Qué significa |
|---|---|
| `FPS 60 · 16.7 ms (peor 18)` | frames por segundo, ms promedio por frame y el frame más lento del último medio segundo |
| `GPU 3.1 ms · draw calls 52` | cuánto tardó la GPU en dibujar el mundo y cuántas veces le pedimos "dibuja esto" |
| `3D 216x480 (x5) · mobile` | resolución interna del mundo, el factor y el renderer |

Aunque los FPS digan 60 (el tope de la pantalla), los **ms de GPU** dicen cuánto margen queda: a 60 FPS hay 16.7 ms por frame en total.

## Prueba de rendimiento (benchmark)

Ajustes > **Prueba de rendimiento (≈1 min)**. Para cada resolución sube los enemigos (0, 50, 100, 200, 400) y mide 2.5 s cada paso con la cámara balanceándose. Apaga el vsync si el celular lo permite, para ver si pasa de 60.

- **"Estable"** = FPS promedio ≥ 95 % de la meta **y** el "1 % más bajo" ≥ 80 % de la meta (que no se trabe aunque el promedio se vea bien).
- Al final muestra una tabla y un resumen: "480 px: 60 FPS → 200 · 30 FPS → 400 o más".
- **Copiar resultados** lo pone en el portapapeles para pegarlo en el chat.
- **Probar con el otro renderer** cambia el renderer, cierra la app y, al volver a abrirla, la prueba corre sola con el otro y muestra las dos corridas juntas.
- Se corre en frío: después de un rato los celulares se calientan y bajan la velocidad. Si quieres ver eso, corre la prueba 2 veces seguidas.

## Mobile vs Compatibility

Godot elige el renderer **al arrancar**, no se puede cambiar con el juego abierto. Por eso el cambio se guarda en `user://renderer_override.cfg` (project.godot lo manda leer con `application/config/project_settings_override`) y hay que reabrir la app. Analogía web: cambiar una variable de entorno y reiniciar el servidor.

| | Mobile (Vulkan) | Compatibility (OpenGL ES 3) |
|---|---|---|
| Celulares | Android con Vulkan decente (si no hay, cae solo a OpenGL) | Prácticamente todos |
| Funciones | más luces por objeto, partículas en GPU, efectos | lo básico: sombras, niebla, glow sencillo |
| Costo fijo por frame | más alto (pensado para escenas pesadas) | más bajo |
| Arranque | compila shaders (puede tardar más la 1ª vez) | más rápido |

Para un mundo de baja resolución, con texturas chiquitas y billboards, casi nunca necesitamos lo extra de Mobile. **Mi apuesta: Compatibility gana o empata en gama media**, y si es así lo cambiamos a default por compatibilidad con más celulares. Lo decidimos con los números de tu celular, no a ojo.

> Probado en la nube solo con Compatibility (no hay GPU con Vulkan ahí), y en la nube la GPU es emulada por CPU: esos números no sirven para decidir, solo para ver que la prueba funciona.

## Qué reportar

1. Ajustes > Prueba de rendimiento. Al terminar, **Copiar resultados**.
2. **Probar con el otro renderer**, reabre la app, espera a que termine y **Copiar resultados** otra vez (trae las dos corridas).
3. Pega el texto en el chat y di cuál resolución te gustó más a la vista (Ajustes > Resolución del mundo 3D cambia al momento).

Con eso fijamos: resolución default, renderer y "presupuesto" de enemigos en pantalla para las fases 3 y 5.

## Archivos

| Archivo | Qué hace |
|---|---|
| `core/graphics/graphics.gd` | autoload: SubViewport, cámara espejo, renderer, ms de GPU |
| `core/graphics/graphics_settings.gd` | resolución elegida y monitor, guardados en `user://` |
| `ui/hud/debug_overlay.gd` | monitor de rendimiento |
| `world/benchmark/` | escena de estrés y necrófago billboard |
| `assets/placeholder/sprites/` | sprites de relleno |
| `tools/tests/pixel_test.tscn` | prueba de CI: resolución, cámara espejo, override de renderer, benchmark rápido |
