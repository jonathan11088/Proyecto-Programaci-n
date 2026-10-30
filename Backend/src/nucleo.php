<?php
declare(strict_types=1);

// Conexion, respuestas HTTP, validacion y sesion.

function db(): PDO
{
    static $pdo = null;
    if ($pdo === null) {
        $pdo = new PDO(
            'mysql:unix_socket=' . (getenv('DB_SOCKET') ?: '/run/mysqld/mysqld.sock') . ';dbname=banco_mariano;charset=utf8mb4',
            getenv('DB_USER') ?: 'banco_app',
            getenv('DB_PASS') ?: '',
            [
                PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
                PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
                PDO::ATTR_EMULATE_PREPARES => false,
                PDO::MYSQL_ATTR_INIT_COMMAND => "SET time_zone = '-06:00'",
            ]
        );
    }
    return $pdo;
}

/** Ejecuta un procedimiento almacenado y devuelve sus filas. */
function sp(string $nombre, array $parametros = []): array
{
    $marcas = implode(',', array_fill(0, count($parametros), '?'));
    $consulta = db()->prepare("CALL $nombre($marcas)");
    $consulta->execute($parametros);
    $filas = $consulta->columnCount() > 0 ? $consulta->fetchAll() : [];
    while ($consulta->nextRowset()) {
    }
    $consulta->closeCursor();
    return $filas;
}

function responder(array $datos, int $estado = 200): never
{
    http_response_code($estado);
    header('Content-Type: application/json; charset=utf-8');
    header('Cache-Control: no-store');
    echo json_encode($datos, JSON_UNESCAPED_UNICODE);
    exit;
}

function fallar(string $mensaje, int $estado = 422): never
{
    responder(['error' => $mensaje], $estado);
}

function cuerpo(): array
{
    $datos = json_decode(file_get_contents('php://input') ?: '', true);
    return is_array($datos) ? $datos : [];
}

function texto(array $datos, string $campo): string
{
    $valor = $datos[$campo] ?? '';
    return is_string($valor) ? trim($valor) : '';
}

function validarNumeroCuenta(string $numero): string
{
    if (!preg_match('/^\d{6,20}$/', $numero)) {
        fallar('El número de cuenta debe tener entre 6 y 20 dígitos.');
    }
    return $numero;
}

function validarDpi(string $dpi): string
{
    if (!preg_match('/^\d{13}$/', $dpi)) {
        fallar('El DPI debe tener exactamente 13 dígitos.');
    }
    return $dpi;
}

function validarMonto(array $datos, string $campo, bool $permitirCero = false): string
{
    $monto = $datos[$campo] ?? '';
    $monto = is_int($monto) || is_float($monto) ? (string) $monto : (is_string($monto) ? trim($monto) : '');
    if (!preg_match('/^\d{1,12}(\.\d{1,2})?$/', $monto) || (!$permitirCero && (float) $monto <= 0)) {
        fallar($permitirCero ? 'Ingrese un monto válido (máximo 2 decimales).' : 'Ingrese un monto mayor que cero (máximo 2 decimales).');
    }
    return $monto;
}

function validarClave(array $datos, string $campo, string $confirmacion): string
{
    $clave = $datos[$campo] ?? '';
    if (!is_string($clave) || strlen($clave) < 8 || strlen($clave) > 72) {
        fallar('La contraseña debe tener entre 8 y 72 caracteres.');
    }
    if (!is_string($datos[$confirmacion] ?? null) || !hash_equals($clave, $datos[$confirmacion])) {
        fallar('La contraseña y su confirmación no coinciden.');
    }
    return password_hash($clave, PASSWORD_DEFAULT);
}

function iniciarSesion(): void
{
    session_name('BANCO_SESION');
    session_set_cookie_params([
        'path' => '/',
        'httponly' => true,
        'samesite' => 'Strict',
        'secure' => ($_SERVER['HTTP_X_FORWARDED_PROTO'] ?? '') === 'https' || !empty($_SERVER['HTTPS']),
    ]);
    session_start();
}

function usuarioActual(): ?array
{
    if (empty($_SESSION['usuario_id'])) {
        return null;
    }
    // Se consulta en cada solicitud para que un bloqueo aplique de inmediato.
    $usuario = sp('sp_usuario_sesion', [$_SESSION['usuario_id']])[0] ?? null;
    return $usuario && !$usuario['bloqueado'] ? $usuario : null;
}

function exigirRol(string $rol): array
{
    $usuario = usuarioActual();
    if ($usuario === null) {
        fallar('Debe iniciar sesión.', 401);
    }
    if ($usuario['rol'] !== $rol) {
        fallar('No tiene permiso para esta operación.', 403);
    }
    return $usuario;
}
