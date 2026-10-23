# AGENTS.md

## Propósito del proyecto

Crear una aplicación de minijuegos para Godot. El proyecto comenzará con un minijuego básico y crecerá gradualmente hasta convertirse en una colección de juegos independientes, accesibles desde un menú común.

La aplicación debe funcionar sin conexión. La interfaz, los recursos y el código deben ser originales: se puede tomar como referencia la idea general de una colección de minijuegos, pero no copiar juegos, textos, imágenes, sonidos, código ni diseño distintivo de otras aplicaciones.

## Instrucciones generales para agentes

- Antes de modificar archivos, revisa la estructura existente y las convenciones que ya utiliza el proyecto.
- Haz cambios pequeños, coherentes y fáciles de revisar.
- No reemplaces archivos completos si basta con modificar una parte.
- No elimines escenas, recursos o funcionalidades existentes sin una razón explícita.
- No añadas dependencias, plugins ni sistemas complejos sin necesidad.
- Si falta información, elige la solución más sencilla que encaje con la arquitectura existente y documenta cualquier decisión importante.
- No inventes rutas, nodos, recursos ni APIs: comprueba que existan en el proyecto y en la versión de Godot utilizada.
- Mantén el proyecto ejecutable después de cada cambio.
- Al terminar, resume los archivos modificados y las comprobaciones realizadas.
- Si no puedes ejecutar Godot o una prueba, dilo claramente en el resumen; no afirmes que pasó.

## Tecnología y compatibilidad

- Utilizar Godot 4.x, salvo que el proyecto ya esté configurado para otra versión.
- Antes de usar funciones específicas, comprobar la versión indicada en `project.godot`.
- Priorizar GDScript y las herramientas integradas de Godot.
- Evitar dependencias de plugins externos para funciones que puedan resolverse de forma sencilla con Godot.
- Mantener el proyecto preparado para exportación móvil, sin impedir que pueda ejecutarse y probarse en escritorio.
- No introducir código que requiera conexión a internet para jugar.

## Arquitectura

El proyecto debe separar la aplicación común de cada minijuego.

Estructura orientativa:

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
    │       └── <game_id>/
    │           ├── <game_id>.tscn
    │           └── ...
    ├── scripts/
    │   ├── app/
    │   ├── menu/
    │   ├── games/
    │   │   └── <game_id>/
    │   └── services/
    ├── assets/
    │   ├── images/
    │   ├── audio/
    │   └── fonts/
    └── tests/

Esta estructura es una guía, no un requisito para reorganizar un proyecto existente que ya tenga una convención clara. Mantener escenas, scripts y recursos de cada juego agrupados y fáciles de localizar.

### Responsabilidades

- **Main:** punto de entrada de la aplicación y contenedor de las pantallas principales.
- **Menú:** muestra los minijuegos disponibles y permite iniciar uno.
- **GameHost:** instancia y retira la escena del juego activo.
- **GameManager:** coordina transiciones entre menú y juego; no debe contener la lógica interna de los minijuegos.
- **SaveManager:** guarda y carga récords y preferencias locales.
- **AudioManager:** centraliza la reproducción y configuración del audio.
- **Cada minijuego:** controla su propio estado, reglas, interfaz específica y final de partida.

Los servicios que deban estar disponibles durante toda la aplicación pueden configurarse como autoloads. No convertir en autoload una clase que solo necesita una escena o un juego.

### Contrato de los minijuegos

Cada minijuego debe poder iniciarse y retirarse sin dejar nodos, señales, temporizadores o estado que afecten al siguiente juego.

Siempre que encaje con el diseño, cada juego debe ofrecer una interfaz coherente con este flujo:

1. Se inicia desde el menú.
2. Presenta o comienza una partida.
3. Permite pausar o volver al menú cuando corresponda.
4. Comunica cuándo termina la partida y cuál fue el resultado.
5. Guarda el récord mediante el sistema común, si el juego tiene un récord.

No crear una abstracción genérica para todas las reglas de juego. Compartir solo lo que realmente sea común, como navegación, audio, guardado y elementos visuales reutilizables.

## Navegación y ciclo de vida

- El usuario debe poder volver al menú desde cualquier juego mediante un control visible y fácil de usar.
- Las transiciones entre pantallas deben tener un responsable claro; evitar que varias escenas cambien la escena raíz por su cuenta.
- Al salir de un juego, limpiar correctamente su escena y detener los procesos que ya no sean necesarios.
- Evitar instanciar varias copias de un mismo juego por pulsaciones repetidas.
- Si hay una confirmación antes de abandonar una partida, mantenerla sencilla y coherente con el resto de la app.

## Código GDScript

- Usar nombres descriptivos y consistentes:
  - `snake_case` para variables, funciones y archivos.
  - `PascalCase` para clases.
  - `UPPER_SNAKE_CASE` para constantes.
- Añadir `class_name` solo cuando facilite el uso o la identificación de una clase.
- Preferir funciones pequeñas con una responsabilidad clara.
- Tipar variables y valores de retorno cuando mejore la claridad y sea compatible con el código existente.
- Usar señales para comunicar eventos entre componentes desacoplados.
- Evitar dependencias innecesarias entre escenas y scripts.
- No usar rutas absolutas de nodos frágiles cuando se pueda resolver la referencia mediante una señal, una referencia exportada o una estructura estable.
- Evitar valores mágicos: convertir los valores importantes en constantes o propiedades exportadas.
- No duplicar lógica común entre minijuegos. Extraerla solo cuando exista una necesidad real.
- No dejar `print()`, código de prueba, marcadores temporales ni recursos sin usar en una entrega terminada.
- Comentar el motivo de una decisión no obvia, no cada línea de código.

## Interfaz y experiencia de uso

- La interfaz debe ser legible y usable en pantallas pequeñas y grandes.
- Usar contenedores y anclajes de Godot para adaptar la interfaz; evitar depender de posiciones absolutas cuando no sean necesarias.
- Los botones principales deben tener áreas táctiles cómodas en móvil.
- Los textos importantes deben tener buen contraste y un tamaño legible.
- Mantener consistentes los controles comunes: volver, pausar, reiniciar y continuar.
- No depender exclusivamente del color para comunicar un estado.
- Comprobar que los cambios de resolución o proporción no recorten botones o información.
- Usar textos y recursos propios del proyecto.
- No añadir animaciones, efectos o pantallas que dificulten completar el flujo principal.

## Guardado

- Guardar localmente solo los datos necesarios para la experiencia, como récords y preferencias.
- Usar identificadores estables para los juegos; no usar el nombre visible del juego como clave de guardado.
- Manejar de forma segura la ausencia o invalidez de datos guardados.
- Al añadir un nuevo dato persistente, documentar su clave y su formato.
- No sobrescribir datos existentes al introducir cambios de formato sin una estrategia de migración o una razón explícita.
- Evitar guardar el estado de una partida si el diseño del juego no lo requiere.

## Recursos y rendimiento

- Usar rutas de recursos organizadas y nombres fáciles de entender.
- Reutilizar recursos compartidos cuando sea conveniente.
- Evitar cargar repetidamente recursos pesados sin necesidad.
- Liberar nodos y recursos temporales cuando dejen de usarse.
- Mantener los efectos visuales y de audio dentro de un presupuesto razonable para dispositivos móviles.
- No incluir recursos de terceros sin comprobar su licencia y registrar su procedencia cuando corresponda.
- No modificar manualmente archivos generados por Godot, como los de la carpeta `.godot/`, salvo que exista una necesidad concreta.

## Entrada y controles

- Configurar acciones en Input Map para las acciones comunes, en lugar de repartir nombres de teclas por el código.
- Admitir controles táctiles para las acciones principales de los juegos orientados a móvil.
- Si un juego también funciona en escritorio, ofrecer controles de teclado o ratón razonables.
- Mostrar instrucciones breves cuando los controles no sean evidentes.
- Evitar que una entrada de una pantalla afecte accidentalmente a la pantalla que se abre después.

## Pruebas y comprobaciones

Después de cada cambio, comprobar según corresponda:

- Que el proyecto abre sin errores de importación.
- Que la escena principal inicia correctamente.
- Que se puede abrir el menú y lanzar el juego.
- Que el juego puede terminarse, reiniciarse y cerrarse correctamente.
- Que el botón de volver conduce al menú.
- Que los récords y ajustes se conservan después de cerrar y volver a abrir la app, cuando corresponda.
- Que los errores y advertencias relevantes de Godot se han revisado.
- Que la interfaz sigue siendo usable en la resolución objetivo y en una resolución alternativa.
- Que el cambio no rompe los minijuegos existentes.

Cuando haya pruebas automatizadas, ejecutarlas y ampliar las pruebas para cubrir la funcionalidad nueva. No añadir un sistema de pruebas grande antes de que aporte valor.

## Flujo para añadir un minijuego

1. Crear una carpeta propia para el juego.
2. Añadir su escena y scripts sin mezclar su lógica con la del menú.
3. Integrarlo en el catálogo del menú usando un identificador estable.
4. Conectarlo al `GameHost` o al mecanismo común de navegación existente.
5. Añadir controles de volver y, si corresponde, pausa, reinicio y pantalla de fin.
6. Usar `SaveManager` para los récords; no crear un formato de guardado independiente sin necesidad.
7. Probar el recorrido completo desde el menú hasta la salida del juego.
8. Verificar que una partida del juego no deja estado activo al abrir otro.

## Criterios para considerar una tarea terminada

Una tarea está terminada cuando:

- El cambio cumple el objetivo solicitado y se integra con la arquitectura existente.
- El flujo principal funciona sin errores conocidos.
- No se han roto las funciones existentes relacionadas.
- El código y los recursos añadidos siguen las convenciones del proyecto.
- Se han realizado las comprobaciones posibles y se han comunicado sus resultados.
- No quedan recursos temporales, código de depuración ni tareas pendientes creadas por el cambio, salvo que se hayan señalado explícitamente.
