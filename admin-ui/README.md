# Admin UI

Frontend separado para la revision visual de encuestas.

## Desarrollo

```sh
npm install
npm run dev
```

Por defecto intenta consumir la API en la misma origin. Para apuntar a una API externa:

```sh
copy .env.example .env
```

Configura `VITE_API_BASE_URL`.

## Endpoints esperados

- `GET /api/v1/admin/manual-review`
- `GET /api/v1/admin/manual-review/{poll_id}`
- `POST /api/v1/admin/manual-review/{poll_id}/actions`

Si la API no responde, la UI usa datos mock locales para poder validar el flujo visual.
