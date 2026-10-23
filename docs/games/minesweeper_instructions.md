# Especificación e Instrucciones: Minijuego Buscaminas (Minesweeper)

**Versión:** 1.1  
**Objetivo:** Guía técnica para implementar el segundo minijuego de la colección ("Buscaminas") con selector de 3 niveles de dificultad/tamaño de mapa, respetando estrictamente las directrices de arquitectura, diseño táctil y desacoplamiento de `AGENTS.MD`.

---

## 1. Resumen y Propósito del Juego

Crear un clásico **Buscaminas** optimizado para pantalla vertical (*Portrait*, resolución 720x1280) y control táctil móvil/ratón. El objetivo del jugador es descubrir todas las casillas del tablero que no contengan minas sin detonar ninguna, pudiendo marcar con banderas las casillas sospechosas.

### Requisitos Esenciales
- **Offline y autónomo:** Sin dependencias externas ni plugins de terceros.
- **Selector de nivel previo:** Antes de iniciar la partida, el jugador puede elegir entre 3 tamaños de mapa: **Pequeño**, **Mediano** y **Grande**.
- **Primer toque seguro:** El primer clic o toque del jugador nunca debe ser una mina (la distribución de minas se genera tras el primer toque).
- **Control móvil sin fricción:** Modo toggle (Pala ⛏️ / Bandera 🚩) en el HUD y soporte de pulsación prolongada (*long press*) para colocar banderas con facilidad.
- **Apertura en cascada (*Flood Fill*):** Al descubrir una casilla con 0 minas adyacentes, se revelan automáticamente todas las casillas vecinas seguras.
- **Récords independientes:** El mejor tiempo/puntuación se guarda y muestra por separado para cada uno de los 3 niveles de dificultad en `SaveManager`.
- **Integración con la arquitectura existente:** Conectado con `GameManager`, `GameHost`, `SaveManager` y `AudioManager`.

---

## 2. Niveles de Dificultad y Dimensiones de Tablero

Para aprovechar al máximo el formato vertical de 720 × 1280 px y garantizar objetivos táctiles cómodos en cualquier tamaño de mano:

| Nivel | Cuadrícula | Total Casillas | Minas | Densidad | Tamaño Celda | Descripción |
| :--- | :---: | :---: | :---: | :---: | :---: | :--- |
| **Pequeño (Fácil)** | 7 columnas × 9 filas | 63 | 8 | ~12.7% | ~84 × 84 px | Celdas muy amplias, ideal para partidas rápidas y principiantes. |
| **Mediano (Normal)** | 9 columnas × 12 filas | 108 | 16 | ~14.8% | ~66 × 66 px | Tamaño equilibrado y desafío clásico de Buscaminas. |
| **Grande (Difícil)** | 11 columnas × 15 filas | 165 | 30 | ~18.2% | ~54 × 54 px | Mayor densidad y concentración táctica para expertos. |

### Configuración en Código (`minesweeper.gd`):
```gdscript
const DIFFICULTY_CONFIG: Dictionary = {
    "easy": {
        "id": "easy",
        "name": "Pequeño",
        "cols": 7,
        "rows": 9,
        "mines": 8,
        "cell_size": Vector2(84, 84),
        "save_key": "minesweeper_easy"
    },
    "medium": {
        "id": "medium",
        "name": "Mediano",
        "cols": 9,
        "rows": 12,
        "mines": 16,
        "cell_size": Vector2(66, 66),
        "save_key": "minesweeper_medium"
    },
    "hard": {
        "id": "hard",
        "name": "Grande",
        "cols": 11,
        "rows": 15,
        "mines": 30,
        "cell_size": Vector2(54, 54),
        "save_key": "minesweeper_hard"
    }
}
```

---

## 3. Estructura de Archivos a Crear

```text
res://
├── scenes/
│   └── games/
│       └── minesweeper/
│           ├── minesweeper.tscn       # Escena principal (Selector de nivel, HUD, Tablero y Modal de fin)
│           └── mine_cell.tscn         # Escena reutilizable de cada casilla individual (Control)
└── scripts/
    └── games/
        └── minesweeper/
            ├── minesweeper.gd         # Orquestador del juego, cuadrícula, dificultad y reglas
            └── mine_cell.gd           # Comportamiento visual, táctil y estados de celda
```

---

## 4. Contrato con la Arquitectura

### 4.1 Registro en `GameManager` (`res://scripts/services/game_manager.gd`)
Añadir la entrada `"minesweeper"` al catálogo general:

```gdscript
"minesweeper": {
    "id": "minesweeper",
    "title": "Buscaminas",
    "description": "¡Despeja el campo sin detonar ninguna mina oculta!",
    "scene_path": "res://scenes/games/minesweeper/minesweeper.tscn"
}
```

### 4.2 Señales del Minijuego (`minesweeper.gd`)
- `signal request_exit()`: Emitida al presionar el botón `◀ MENÚ` o al salir desde los modales.
- `signal game_over(score: int)`: Emitida al finalizar una partida (victoria o derrota). En victoria, el puntaje premia la velocidad:
  ```gdscript
  var time_bonus = max(100, 10000 - elapsed_seconds * 20)
  var difficulty_mult = 1.0 if current_diff == "easy" else (1.5 if current_diff == "medium" else 2.0)
  var final_score = int(time_bonus * difficulty_mult)
  ```

### 4.3 Persistencia con `SaveManager`
Guardar y consultar el mejor tiempo o récord por cada nivel:
- `SaveManager.get_high_score("minesweeper_easy")`
- `SaveManager.get_high_score("minesweeper_medium")`
- `SaveManager.get_high_score("minesweeper_hard")`

### 4.4 Limpieza Autónoma (`clean_up()`)
- Cancelar el temporizador de partida (`game_timer.stop()`).
- Liberar las celdas del tablero y desconectar señales.
- Ejecutar `clean_up()` al salir o en `_exit_tree()`.

---

## 5. Flujo de Navegación y Pantallas del Juego

### 5.1 Pantalla de Selección de Dificultad (`LevelSelectView`)
Al abrir el juego desde el menú principal (o al presionar "Cambiar Nivel"):
- **Encabezado:** Título "BUSCAMINAS" y botón `◀ MENÚ`.
- **Subtítulo:** "Selecciona el tamaño del mapa:".
- **3 Tarjetas / Botones de Nivel:**
  - **Pequeño:** `7 × 9` | `8 minas` | `Récord: XX pts`
  - **Mediano:** `9 × 12` | `16 minas` | `Récord: XX pts`
  - **Grande:** `11 × 15` | `30 minas` | `Récord: XX pts`
- Al pulsar cualquiera de los tres, se oculta el selector, se construye el tablero con las dimensiones seleccionadas y comienza la partida.

### 5.2 HUD Superior Durante la Partida
- Botón `◀ MENÚ` (esquina superior izquierda).
- Contador de minas restantes: `🚩 16`.
- Cronómetro en tiempo real: `⏱️ 00:00`.
- Selector de modo: Botón toggle `⛏️ EXCAVAR` / `🚩 BANDERA`.
- Botón rápido `🔄 REINICIAR`.

### 5.3 Pantalla de Fin de Partida (`GameOverModal`)
Al ganar o perder:
- Título con resultado: **"¡VICTORIA!"** (verde/dorado) o **"¡BOOM! FIN DE PARTIDA"** (rojo).
- Tiempo transcurrido y puntuación obtenida.
- Indicador si se logró un **¡Nuevo Récord!** para ese nivel específico.
- **Acciones:**
  1. `Reintentar`: Reinicia el mismo nivel inmediatamente con un nuevo tablero aleatorio.
  2. `Cambiar Nivel`: Vuelve a la pantalla de selección de dificultad.
  3. `Salir al Menú`: Vuelve al menú principal de la colección.

---

## 6. Lógica del Tablero y Mecánicas de Juego

### 6.1 Primer Toque Seguro
1. El tablero se inicializa con todas las celdas en estado oculto sin minas asignadas.
2. Al registrarse el primer toque en `(c, r)`:
   - Se colocan las `N` minas aleatoriamente en cualquier casilla que **no** sea `(c, r)` ni sus casillas inmediatamente vecinas.
   - Se calculan los números de minas adyacentes para cada celda del tablero.
   - Se revela inmediatamente la casilla tocada (la cual tendrá garantizado un valor de `0` o número bajo).

### 6.2 Apertura en Cascada (*Flood Fill*)
Cuando se descubre una casilla con valor `0`:
- Usar una cola BFS (`Array[Vector2i]`):
  - Sacar la coordenada actual.
  - Para cada vecino en las 8 direcciones:
    - Si no está revelado y no tiene bandera:
      - Revelar la celda.
      - Si su valor es `0`, añadir a la cola para seguir expandiendo.

### 6.3 Interacción Táctil y Banderas
- Si el modo es **⛏️ Excavar**: Un toque en una casilla oculta sin bandera la descubre. Si es una mina, detona y termina la partida.
- Si el modo es **🚩 Bandera**: Un toque en una casilla oculta alterna la bandera. Las casillas con bandera quedan bloqueadas para no ser descubiertas por error.
- **Soporte de Pulsación Prolongada (*Long Press*):** Si el jugador mantiene presionado el dedo sobre una casilla durante 0.35s en cualquier modo, se alterna la bandera automáticamente con feedback táctil.

---

## 7. Recursos Audiovisuales (Originales y Procedurales)

No se requiere ningún asset externo:
- **Celdas:** Nodos `Control` con dibujo vectorial `_draw()` o `StyleBoxFlat`:
  - Oculta: Botón con bisel 3D suave.
  - Revelada: Fondo plano limpio con contraste.
  - Mina detonada: Fondo rojo intenso con icono `💣`.
  - Bandera: Icono `🚩` rojo vibrante con base.
- **Sonidos Procedurales (AudioManager):**
  - `click`: Al alternar herramientas o presionar botones de nivel.
  - `pop`: Al revelar celdas seguras o colocar banderas.
  - `game_over`: Al detonar una mina.
  - `new_record`: Fanfarria al completar el tablero.

---

## 8. Plan de Implementación Paso a Paso con TDD

### Paso 1: Pruebas Unitarias de Lógica de Tablero
En `tests/test_runner.gd`, añadir `test_minesweeper_logic()`:
1. Comprobar que los 3 niveles configuran correctamente columnas, filas y cantidad de minas.
2. Verificar que tras el primer toque, la casilla inicial y sus vecinas no contienen minas.
3. Verificar el conteo correcto de adyacencias en matrices predefinidas.
4. Verificar que *Flood Fill* revela todas las celdas conectadas con 0 minas y no cruza casillas con banderas.
5. Verificar condiciones de victoria (`casillas_ocultas == minas`) y derrota (`mina_detonada`).

### Paso 2: Creación de la Celda (`mine_cell`)
1. Implementar `scripts/games/minesweeper/mine_cell.gd` y `scenes/games/minesweeper/mine_cell.tscn`.
2. Soporte para estados visuales y eventos de entrada táctil (`_gui_input` con detección de tap y long-press).

### Paso 3: Escena Principal (`minesweeper`)
1. Implementar la interfaz completa en `minesweeper.tscn` (pantalla de selección de nivel, HUD de juego, contenedor de tablero y modal de fin).
2. Conectar la lógica en `minesweeper.gd`.

### Paso 4: Registro y Verificación
1. Registrar `"minesweeper"` en `GameManager.gd`.
2. Ejecutar la suite de pruebas automatizadas:
   ```powershell
   & "C:\Users\candi\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe" --headless -s res://tests/test_runner.gd
   ```
3. Recompilar el APK:
   ```powershell
   & "C:\Users\candi\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe" --headless --export-debug "Android" "builds/Minijuegos.apk"
   ```
