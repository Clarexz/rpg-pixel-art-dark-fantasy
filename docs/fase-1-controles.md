# Fase 1: controles FPS en vertical

## Esquemas considerados

| # | Esquema | A favor | En contra |
|---|---|---|---|
| **A (elegido)** | Joystick flotante abajo-izquierda + arrastrar para mirar en el resto de la pantalla + botones abajo-derecha. El botón ATACAR también deja mirar si arrastras sobre él. | Es lo que ya conoce cualquiera que haya jugado un shooter móvil. Atacar sin soltar la mira. Funciona con dos pulgares. | En vertical los pulgares quedan muy juntos y la mitad de abajo de la pantalla se tapa con las manos. |
| B | A + auto-aim suave (la mira se "pega" un poco al enemigo más cercano). | Compensa el campo de visión horizontal tan angosto del vertical; casi obligatorio para combate cuerpo a cuerpo. | Necesita enemigos reales para afinarse. Se agrega encima de A en la fase 3, no lo reemplaza. |
| C | Gestos: tocar para caminar a un punto, deslizar para atacar (estilo duelos de Infinity Blade). | Se juega con una mano. | No sirve para explorar un mundo abierto en tiempo real; encaja mejor como modo "duelo" contra rivales. |

**Recomendación:** A ahora, B en la fase 3 (combate), y C solo si decidimos que los rivales se pelean en duelos.

## Qué hay en el build

- **Nivel gris** (`world/greybox/`): piso con cuadrícula, pilares, coberturas bajas, escaleras, una rampa, un pasillo angosto y 5 muñecos de práctica.
- **Jugador** (`player/`): `CharacterBody3D` con cámara en primera persona, caminar, correr (empuja el joystick hasta el borde hacia adelante: el aro se pone amarillo), saltar y un arma placeholder.
- **Controles táctiles** (`ui/touch_controls/`):
  - Mitad izquierda, parte baja: el joystick aparece donde pones el pulgar.
  - Cualquier otro lado: arrastrar para mirar. Funciona con varios dedos a la vez.
  - **ATACAR**: toca para golpear, mantén para seguir golpeando, arrastra encima para apuntar mientras atacas.
  - **SALTO** y **PIEDRA** (lectura placeholder del poder del muñeco que tienes en la mira).
- **Vibración**: corta al tocar botones, más fuerte cuando el golpe conecta, suave al empezar a correr.
- **Ajustes** (botón arriba a la derecha): sensibilidad, eje vertical, campo de visión, tamaño y zona muerta del joystick, joystick fijo o flotante, vibración. Pausan el juego y se guardan en el celular. Los valores por defecto están en `player/controls/default_control_settings.tres`.
- **Pérdida de foco**: si sales de la app o llega una notificación, se sueltan todos los dedos y se abre el panel (pausa).
- **Prueba automática** (`tools/tests/controls_test.gd`): simula dedos y verifica que caminar, mirar, atacar y la pausa funcionen. Corre en CI en cada PR.

## Qué probar en el celular

1. Camina y mira al mismo tiempo. ¿El joystick se "pierde" o el pulgar se sale de la zona?
2. Gira 180° de un solo arrastre. ¿La sensibilidad se siente bien o hay que subirla/bajarla?
3. Golpea un muñeco mientras lo rodeas (arrastrando sobre ATACAR). ¿Es cómodo?
4. Sube la rampa y las escaleras, salta a la plataforma.
5. ¿Los botones están donde cae tu pulgar? ¿Tocas SALTO sin querer?
6. Prueba con una mano: ¿se puede algo, o es solo a dos manos?

## Notas de qué se sintió mal

Llenar después de probar (sirven de entrada para la fase 3).

- Probado en la nube: el campo de visión horizontal en vertical es muy angosto (~45° con FOV vertical de 80°). Por eso el FOV es ajustable; probar entre 80 y 95.
- Probado en la nube: el arma placeholder queda detrás del botón ATACAR. En la fase 2 (pixel art) se rediseña como sprite.
- _(pendiente: notas de Caleb en su celular)_
