# Especificación de Diseño: Inicialización de la Aplicación de Minijuegos en Godot

**Fecha:** 2026-10-17  
**Estado:** Aprobado  
**Objetivo:** Establecer la arquitectura base modular, los servicios comunes y el primer minijuego funcional ("Explota Globos") de acuerdo con las especificaciones de `AGENTS.MD`.

---

## 1. Contexto y Objetivos

El propósito del proyecto es crear una plataforma offline para minijuegos en Godot 4.x. La arquitectura debe permitir que la colección crezca de forma modular, manteniendo un desacoplamiento estricto entre la aplicación contenedora y cada uno de los minijuegos. Todo el arte, diseño y audio se generará procedimentalmente mediante herramientas nativas de Godot para garantizar 100% originalidad y ausencia de dependencias externas.

---

## 2. Configuración del Proyecto (`project.godot`)

- **Motor:** Godot 4.x (compatible con 4.7.2).
- **Nombre de la Aplicación:** Minijuegos
- **Orientación:** Vertical (*Portrait*).
- **Resolución base:** 720 x 1280 píxeles.
- **Configuración de Escalado:**
  - `window/size/viewport_width = 720`
  - `window/size/viewport_height = 1280`
  - `window/stretch/mode = "canvas_items"`
  - `window/stretch/aspect = "expand"`
  - `window/handheld/orientation = "portrait"`
- **Entrada:**
  - `input_devices/pointing/emulate_touch_from_mouse = true`
  - `input_devices/pointing/emulate_mouse_from_touch = true`
- **Escena Principal:** `res://scenes/app/main.tscn`

---

## 3. Estructura de Carpetas

```text
res://
├── project.godot
├── AGENTS.md
├── scenes/
│   ├── app/
│   │   ├── main.tscn
│   │   └── game_host.tscn
│   ├── menu/
│   │   └── main_menu.tscn
│   └── games/
│       └── balloon_pop/
│           ├── balloon_pop.tscn
│           └── balloon.tscn
├── scripts/
│   ├── app/
│   │   ├── main.gd
│   │   └── game_host.gd
│   ├── menu/
│   │   └── main_menu.gd
│   ├── games/
│   │   └── balloon_pop/
│   │       ├── balloon_pop.gd
│   │       └── balloon.gd
│   └── services/
│       ├── game_manager.gd
│       ├── save_manager.gd
│       └── audio_manager.gd
├── assets/
│   ├── images/
│   ├── audio/
│   └── fonts/
└── tests/
    └── test_runner.gd
```

---

## 4. Arquitectura de Servicios y Navegación

### 4.1 Autoloads

1. **`SaveManager` (`res://scripts/services/save_manager.gd`)**
   - **Archivo:** `user://save_data.json`
   - **Estructura JSON:**
     ```json
     {
       "preferences": {
         "music_volume": 1.0,
         "sfx_volume": 1.0,
         "muted": false
       },
       "records": {
         "balloon_pop": {
           "high_score": 0,
           "games_played": 0
         }
       }
     }
     ```
   - **Contrato:**
     - `get_high_score(game_id: String) -> int`
     - `save_score(game_id: String, score: int) -> bool` (retorna `true` si es un nuevo récord)
     - `get_preference(key: String, default_value: Variant) -> Variant`
     - `set_preference(key: String, value: Variant) -> void`

2. **`AudioManager` (`res://scripts/services/audio_manager.gd`)**
   - Generación sintética procedural de ondas de audio PCM mediante `AudioStreamWav`:
     - `pop`: Tono rápido descendente senoidal (800 Hz a 200 Hz).
     - `click`: Pulso corto amortiguado (1000 Hz).
     - `game_over`: Tono descendente melancólico.
     - `new_record`: Fanfarria arpegiada de 3 notas ascendentes.
   - **Contrato:**
     - `play_sfx(sound_name: String) -> void`
     - `set_sfx_volume(linear_vol: float) -> void`
     - `set_muted(muted: bool) -> void`

3. **`GameManager` (`res://scripts/services/game_manager.gd`)**
   - **Estados:** `enum State { MENU, IN_GAME, PAUSED }`
   - **Catálogo de Juegos:** Diccionario con metadatos:
     - `id`: `"balloon_pop"`
     - `title`: `"Explota Globos"`
     - `description`: `"¡Toca los globos antes de que escapen!"`
     - `scene_path`: `"res://scenes/games/balloon_pop/balloon_pop.tscn"`
   - **Señales:**
     - `game_start_requested(game_id: String)`
     - `game_exit_requested()`
     - `state_changed(new_state: int)`

### 4.2 Escenas del Contenedor (`App`)

- **`Main` (`main.tscn` / `main.gd`):** Raíz que contiene `MenuContainer`, `GameHost` y `OverlayContainer`. Gestiona la visibilidad entre el menú y el contenedor de juegos según las señales de `GameManager`.
- **`GameHost` (`game_host.tscn` / `game_host.gd`):** Instancia dinámicamente la escena del minijuego correspondiente cuando se emite `game_start_requested`. Conecta las señales de terminación y salida. Al salir, limpia la instancia con `queue_free()` garantizando que no queden referencias vivas ni procesos activos.

---

## 5. Diseño del Minijuego: "Explota Globos" (`balloon_pop`)

### 5.1 Mecánicas y Reglas
- **Aparición:** Los globos se generan en la base inferior con posiciones `x` aleatorias y ascienden verticalmente a velocidades variables.
- **Interacción:** Detección de toque táctil o clic de ratón sobre el globo.
- **Puntuación:**
  - Globo estándar (radio medio, velocidad normal): 10 puntos.
  - Globo veloz (radio pequeño, velocidad rápida): 25 puntos.
  - Globo dorado (raro, muy rápido): 50 puntos.
- **Condición de fallo:** Si un globo sobrepasa el límite superior de la pantalla sin ser explotado, se pierde 1 vida (se inicia con 3 vidas).
- **Fin de partida:** Al llegar a 0 vidas, se detiene la aparición, se calcula si se batió el récord histórico mediante `SaveManager`, y se presenta la pantalla de resumen con opción de Reintentar o Salir al Menú.
- **Controles HUD:** Botón de retorno al menú disponible en la esquina superior izquierda en todo momento.

### 5.2 Componentes del Minijuego
- `balloon_pop.tscn`: Escena raíz del juego con HUD, área de spawn y lógica de temporizadores.
- `balloon.tscn`: Nodo representativo del globo con colisión 2D (`Area2D`) o detección `gui_input`, dibujado con primitivas vectoriales (`_draw` con gradiente/círculo y cuerda) o `CanvasItem`.

---

## 6. Estrategia de Pruebas Automatizadas

Se provee `res://tests/test_runner.gd` ejecutable en modo headless (`godot --headless -s res://tests/test_runner.gd`):
1. **Prueba de `SaveManager`:** Comprobación de persistencia y actualización de récords.
2. **Prueba de `AudioManager`:** Comprobación de inicialización de buffers de sonido sintéticos.
3. **Prueba de `GameManager`:** Verificación de catálogo y transición de estados.
4. **Prueba de Carga de Escenas:** Verificación de que `main.tscn`, `main_menu.tscn` y `balloon_pop.tscn` se instancian sin errores de sintaxis o dependencias faltantes.
