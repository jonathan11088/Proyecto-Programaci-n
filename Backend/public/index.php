<?php
declare(strict_types=1);

require __DIR__ . '/../src/nucleo.php';

$metodo = $_SERVER['REQUEST_METHOD'];
$ruta = preg_replace('#^/api#', '', parse_url($_SERVER['REQUEST_URI'], PHP_URL_PATH)) ?: '/';
$ruta = rtrim($ruta, '/') ?: '/';

try {
    if ($ruta === '/health') {
        responder(['estado' => 'ok']);
    }

    // Exigir JSON impide que un formulario de otro sitio dispare operaciones.
    if ($metodo === 'POST' && !str_starts_with($_SERVER['CONTENT_TYPE'] ?? '', 'application/json')) {
        fallar('Tipo de contenido no admitido.', 415);
    }

    iniciarSesion();
    require __DIR__ . '/../src/rutas.php';
    fallar('Ruta no encontrada.', 404);
} catch (PDOException $e) {
    // 1644: error de negocio lanzado con SIGNAL dentro de un procedimiento.
    if (($e->errorInfo[1] ?? 0) === 1644) {
        fallar((string) $e->errorInfo[2]);
    }
    // 1062: dos solicitudes simultaneas chocaron con una llave unica.
    if (($e->errorInfo[1] ?? 0) === 1062) {
        fallar('El registro ya existe.');
    }
    error_log((string) $e);
    fallar('Ocurrió un error interno. Intente de nuevo.', 500);
} catch (Throwable $e) {
    error_log((string) $e);
    fallar('Ocurrió un error interno. Intente de nuevo.', 500);
}
