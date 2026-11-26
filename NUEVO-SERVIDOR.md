# Primeras instrucciones para el Claude de un servidor nuevo

Si lees esto, acaban de instalarte en un servidor de Z4 Studios con el apartado 4 del `README.md`. El objetivo de esta primera sesión es que puedas trabajar aquí como el Claude de los demás servidores. No cambies nada sin el OK de Carlos (sección D del CLAUDE.md global).

## Cómo está organizado

- **`~/.claude/CLAUDE.md` (global):** instrucciones de Carlos, comunes a todos los servidores. Ya lo tienes cargado. Léete sobre todo las secciones D, H, L, O y P.
- **CLAUDE.md del proyecto** (`<ruta del proyecto>/CLAUDE.md`): lo propio de este servidor y proyecto, con su Estado, Hechos comprobados y Pendientes. Aquí aún no existe: lo vas a redactar tú.
- **Memoria automática** (`~/.claude/projects/<proyecto>/memory/`): una por proyecto.
- **`~/claude-config`:** el respaldo de todo lo anterior, sincronizado con `sync.sh`. Tu nombre clave está en `~/claude-config/.servidor`; tus proyectos, en `~/claude-config/<servidor>/proyectos.txt`.

## Pasos

1. Lee `~/claude-config/README.md` y comprueba `.servidor` y `proyectos.txt`. Confirma con Carlos el nombre clave, la ruta del proyecto y qué hay en el servidor (producción o staging, qué webs, de qué cliente).
2. Reconoce el servidor **solo con comandos de lectura**: sistema y disco (`lsb_release -ds`, `df -h`), contenedores (`docker ps`, archivos compose), webs y sus rutas, cron (`/etc/cron.d`, `crontab -l`), copias de seguridad y si la carpeta del proyecto es un repo git. Si un comando necesita `sudo`, pídeselo a Carlos con el comando exacto.
3. Redacta el CLAUDE.md del proyecto. Como referencia de **estructura**, usa `~/claude-config/staging-hz499/z4/CLAUDE.md`, pero no copies sus hechos, que son de otro cliente:
   - **Qué es esto:** el nombre clave del servidor, qué aloja y si es producción.
   - **Documentos del cliente:** historial y ficha técnica. Pídeselos a Carlos (sección O).
   - **Archivos:** una tabla de rutas con «¿Se puede tocar?».
   - **Reglas obligatorias:** las propias de este servidor. En producción, más estrictas: qué comandos piden permiso siempre y qué no se toca nunca.
   - **Hechos ya comprobados**, **Estado** y **Pendientes**.
4. Memoria: empieza vacía. No copies la de otros servidores. Las lecciones que valen para cualquier servidor ya están en el CLAUDE.md global. A partir de ahora, antes de guardar una lección, decide si es de este proyecto o vale para todos (sección P del global).
5. Rellena la fila de este servidor en la tabla «Servidores» del `README.md` (acceso y proyectos).
6. Enseña los diffs a Carlos y, con su OK, aplícalos. El README es del repo y `sync.sh` no lo copia: haz commit solo de ese archivo (`git -C ~/claude-config commit README.md -m "docs: …"`). Después ejecuta `~/claude-config/sync.sh` y `~/claude-config/sync.sh --si "docs: …"`, que sube el CLAUDE.md, la memoria y también ese commit.
7. Propón documentar el alta del servidor según la sección O: z4stack → Historial.
