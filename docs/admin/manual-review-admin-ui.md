# Uso del Admin UI para revision manual

El Admin UI permite revisar visualmente encuestas que el scraper no puede aprobar con seguridad. La idea es evitar cotejos manuales con SQL y convertir la revision en una bandeja de trabajo: abrir caso, comparar datos, mirar alertas, revisar fuente y registrar una decision.

## Antes de empezar

El backend de revision debe estar aplicado en PostgreSQL:

```powershell
psql -h $env:PGHOST -p $env:PGPORT -U $env:PGUSER -d $env:PGDATABASE -f sql/001_schema.sql
psql -h $env:PGHOST -p $env:PGPORT -U $env:PGUSER -d $env:PGDATABASE -f sql/002_indexes.sql
```

El frontend vive en:

```text
admin-ui/
```

Para arrancarlo:

```powershell
cd admin-ui
npm install
npm run dev
```

Por defecto, el Admin UI intenta consumir la API desde la misma origin. Si la API esta en otro host o puerto, crea `admin-ui/.env`:

```text
VITE_API_BASE_URL=http://localhost:8000
```

Si la API no responde, la pantalla usa datos mock locales. Esto sirve para probar la experiencia visual, pero las decisiones no quedan persistidas en la base de datos.

## Flujo de trabajo

1. Ejecutar el scraper.

```powershell
Rscript scripts/run_scraper.R
```

2. Abrir el Admin UI.

```text
http://127.0.0.1:5173
```

3. Revisar la bandeja de encuestas pendientes.

4. Abrir una encuesta.

5. Comprobar resultados, anomalias, fuente y razones de matching.

6. Registrar una decision.

7. Confirmar que la encuesta aprobada ya puede aparecer en las vistas publicas.

## Bandeja de revision

La columna izquierda muestra las encuestas que requieren atencion. Cada fila resume:

- encuestadora
- medio
- fecha de campo
- estado de revision
- numero de errores y warnings
- prioridad de revision

Los filtros superiores permiten ver:

- `Todas`: todos los casos disponibles en la cola.
- `Pendientes`: casos sin decision operativa.
- `A corregir`: casos marcados como `needs_fix`.
- `Revisadas`: casos aprobados.
- `Descartadas`: casos rechazados.

La busqueda permite localizar por encuestadora, medio, `poll_id`, eleccion, fuente o codigo de anomalia.

## Pantalla de detalle

Al seleccionar una encuesta se abre la ficha completa. Esta pantalla esta pensada para responder cuatro preguntas:

- Es realmente una encuesta valida?
- Coincide con una encuesta ya existente?
- Hay datos mal parseados o incompletos?
- La fuente respalda los datos normalizados?

### Cabecera

La cabecera muestra:

- encuestadora
- medio
- fechas de campo
- tamano muestral
- suma de voto
- confianza del matching
- numero de anomalias

La confianza del matching ayuda a detectar casos ambiguos. Una confianza baja no significa necesariamente que la encuesta sea incorrecta, solo que el sistema no encontro una correspondencia clara.

### Resultados

La tabla de resultados muestra una fila por partido:

- partido normalizado
- etiqueta cruda importada
- porcentaje de voto
- barra visual
- media reciente comparable
- diferencia frente a esa media

Usa esta tabla para detectar errores visibles, por ejemplo:

- un partido con porcentaje imposible
- un partido no catalogado
- una suma de voto demasiado baja o alta
- un decimal mal interpretado
- una encuesta asignada al partido equivocado

### Anomalias

Las anomalias se muestran como bloques con severidad:

- `error`: revisar antes de aprobar.
- `warning`: puede ser valido, pero requiere atencion.
- `info`: informacion util para auditar.

Codigos habituales:

- `manual_review_status`: la encuesta entro en revision manual.
- `low_identity_confidence`: matching con confianza inferior a 0.85.
- `missing_fieldwork_dates`: faltan fechas de campo.
- `fieldwork_after_publication`: la fecha de campo termina despues de la publicacion.
- `missing_sample_size`: falta muestra.
- `missing_source_url`: no hay URL externa de fuente.
- `unknown_party`: hay partidos no catalogados.
- `vote_share_out_of_range`: hay valores fuera de 0-100.
- `vote_share_sum_low`: suma de voto sospechosamente baja.
- `vote_share_sum_high`: suma de voto sospechosamente alta.

### Fuente

El bloque de fuente muestra:

- fecha de publicacion
- titulo de referencia
- pagina de Wikipedia
- enlace externo si existe
- enlace a Wikipedia si existe

Cuando haya dudas, abre la fuente y compara visualmente los datos con la tabla de resultados.

### Matching

El bloque de matching explica por que el scraper marco el caso como ambiguo o probable:

- `same_pollster`
- `same_media`
- `same_sample_size`
- `close_publication_date`
- `close_fieldwork_dates`
- `identical_vote_results`
- `ambiguous_or_low_confidence`
- `no_probable_candidates`

Estas razones son orientativas. La decision final la toma el administrador.

### Encuestas parecidas

El bloque `Encuestas parecidas` muestra las encuestas existentes que el scraper considero candidatas durante el matching. Sirve para cotejar si la encuesta en revision es realmente nueva o si corresponde a una ya registrada.

Cada candidata muestra:

- `poll_id` de la encuesta existente.
- confianza del matching.
- encuestadora y medio.
- fechas de campo.
- muestra.
- razones de similitud.
- resultados principales.

Si aparece una candidata con confianza alta y datos muy parecidos, revisa la fuente antes de decidir entre `Aprobar nueva` y `Aprobar match`.

## Decisiones disponibles

### Aprobar nueva

Usar cuando la encuesta es valida y no corresponde a una encuesta existente.

Efecto esperado:

```text
identity_status = 'new_poll'
is_active = true
```

La encuesta podra aparecer en vistas publicas.

### Aprobar match

Usar cuando la encuesta es valida y la correspondencia propuesta por el sistema es aceptable.

Efecto esperado:

```text
identity_status = 'probable_match'
is_active = true
```

La encuesta podra aparecer en vistas publicas.

### Marcar fix

Usar cuando la encuesta parece recuperable, pero necesita correccion de datos, parser, catalogo de partidos o fuente.

Efecto esperado:

```text
identity_status = 'manual_review'
review_status = 'needs_fix'
```

Debe dejarse una nota explicando que corregir.

### Descartar

Usar cuando la fila no debe publicarse.

Efecto esperado:

```text
identity_status = 'manual_review'
is_active = false
review_status = 'rejected'
```

Ejemplos:

- fila duplicada incorrecta
- fila que no es una encuesta
- fuente insuficiente
- datos imposibles y no corregibles

### Comentar

Usar para dejar una nota sin cambiar el estado de la encuesta.

## Buenas practicas

- Revisar primero los casos con errores.
- No aprobar una encuesta sin fuente si tambien hay otros warnings relevantes.
- Usar `Aprobar match` solo si el contexto de matching tiene sentido.
- Usar `Marcar fix` cuando el problema sea corregible en parser/catalogo.
- Escribir notas cortas pero accionables.
- No usar la UI para corregir datos directamente si el problema viene del ETL; corregir la causa y reejecutar el scraper.

## Auditoria

Cada decision queda registrada en:

```text
poll_review_actions
```

Ademas, el sistema registra un evento en:

```text
poll_identity_events
```

Esto permite reconstruir quien reviso una encuesta, que decision tomo y cuando.

## Comprobaciones despues de aprobar

Una encuesta aprobada deberia aparecer en las vistas publicas:

```sql
select *
from api_polls_public
where poll_id = 202;

select *
from api_poll_results_public
where poll_id = 202;
```

Si no aparece, comprobar:

- `polls.is_active = true`
- `polls.identity_status <> 'manual_review'`
- que existan resultados en `poll_results`

## Problemas frecuentes

### La UI muestra datos de ejemplo

La API no esta respondiendo o `VITE_API_BASE_URL` no apunta al backend correcto. Revisa la consola del navegador y el `.env` de `admin-ui/`.

### Una decision no se guarda

Comprueba que el endpoint `POST /api/v1/admin/manual-review/{poll_id}/actions` esta implementado y que el usuario tiene permisos.

### Una encuesta sigue en la bandeja tras aprobar

Puede tener anomalias que la mantienen visible. Revisa `admin_poll_review_queue` y `admin_poll_review_anomalies`.

### Faltan colores o nombres de partidos

El partido puede no existir en `parties`. Marcar como fix si debe anadirse al catalogo.
