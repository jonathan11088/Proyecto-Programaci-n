# Banco Mariano: Sistema de Banca en Línea

Proyecto del curso Desarrollo Web (UMG). Stack: HTML5, CSS3, JavaScript, PHP 8.2, MySQL/MariaDB y Apache.

## Estructura

| Carpeta | Contenido |
| --- | --- |
| `Frontend/` | Páginas, estilos y JavaScript |
| `Backend/public/` | Punto de entrada de la API (`/api`) |
| `Backend/src/` | Rutas, validación y sesión |
| `Backend/database/` | Script de la BD en blanco y procedimientos almacenados |
| `deploy/` y `Dockerfile` | Configuración de Apache, MariaDB y arranque en Render |
| `Docs/` | Documento de entrega y diagramas |

Un solo servicio entrega todo: Apache sirve el Frontend en `/` y la API en `/api`.

## Publicar en Render

1. Cree un repositorio privado o público en GitHub y suba esta carpeta.
2. En Render elija **New > Blueprint** y seleccione el repositorio. `render.yaml` crea el servicio.
3. Espere a que el despliegue termine y abra la URL `https://...onrender.com`.
4. En **Environment** copie `ADMIN_PASSWORD`. El usuario es `admin`.

## Limitaciones del plan gratuito

- El servicio se duerme tras 15 minutos sin tráfico y puede tardar hasta un minuto en despertar.
- MySQL corre dentro del servicio, con disco efímero. **Al dormirse, reiniciarse o redesplegarse, la BD y el log de Apache vuelven a quedar en blanco**, solo con el administrador.

## Probar en local (opcional)

```bash
docker build -t banco-mariano .
```

```bash
docker run --rm -p 8088:10000 -e ADMIN_PASSWORD=UnaClaveLocal123 banco-mariano
```

Luego abra http://localhost:8088.

## Decisiones de interpretación del enunciado

- **Transacciones** cuenta depósitos, retiros y transferencias. El monto inicial de una cuenta aparece en el estado de cuenta como apertura, pero no cuenta como depósito.
- El monitor muestra las cantidades del día y su histórico. La gráfica permite ver hoy o el histórico.
- Todo acceso a datos usa procedimientos almacenados. El usuario de la aplicación solo tiene permiso `EXECUTE`.
- Días y límites diarios usan la hora de Guatemala (UTC-6).
