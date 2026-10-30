<?php
declare(strict_types=1);

// Tabla de rutas de la API. Se incluye desde public/index.php.

$operacion = "$metodo $ruta";

// ---------- Autenticacion y registro ----------
if ($operacion === 'POST /auth/login') {
    $datos = cuerpo();
    $rol = texto($datos, 'rol');
    $usuario = strtolower(texto($datos, 'usuario'));
    $clave = $datos['clave'] ?? '';
    if (!in_array($rol, ['admin', 'cajero', 'cliente'], true) || $usuario === '' || !is_string($clave) || $clave === '') {
        fallar('Ingrese usuario y clave.');
    }
    $fila = sp('sp_usuario_para_login', [$usuario, $rol])[0] ?? null;
    if ($fila && $fila['bloqueo_temporal']) {
        fallar('Demasiados intentos fallidos. Intente de nuevo en 15 minutos.', 429);
    }
    if (!$fila || !password_verify($clave, $fila['clave_hash'])) {
        if ($fila) {
            sp('sp_login_fallido', [$fila['id']]);
        }
        fallar('Usuario o clave incorrectos.', 401);
    }
    if ($fila['bloqueado']) {
        fallar('Este usuario está bloqueado. Contacte al administrador.', 403);
    }
    sp('sp_login_exitoso', [$fila['id']]);
    session_regenerate_id(true);
    $_SESSION['usuario_id'] = (int) $fila['id'];
    responder(['nombre' => $fila['nombre'], 'rol' => $fila['rol']]);
}

if ($operacion === 'POST /auth/logout') {
    $_SESSION = [];
    session_destroy();
    setcookie(session_name(), '', ['expires' => time() - 3600, 'path' => '/']);
    responder(['ok' => true]);
}

if ($operacion === 'GET /auth/me') {
    $usuario = usuarioActual();
    if ($usuario === null) {
        fallar('Debe iniciar sesión.', 401);
    }
    responder(['nombre' => $usuario['nombre'], 'usuario' => $usuario['usuario'], 'rol' => $usuario['rol']]);
}

if ($operacion === 'POST /registro') {
    $datos = cuerpo();
    $numero = validarNumeroCuenta(texto($datos, 'numero'));
    $correo = strtolower(texto($datos, 'correo'));
    if (!filter_var($correo, FILTER_VALIDATE_EMAIL) || strlen($correo) > 120) {
        fallar('Ingrese un correo electrónico válido.');
    }
    $dpi = validarDpi(texto($datos, 'dpi'));
    $hash = validarClave($datos, 'clave', 'confirmacion');
    sp('sp_registrar_cliente', [$numero, $correo, $dpi, $hash]);
    responder(['mensaje' => 'Usuario creado. Ya puede iniciar sesión.'], 201);
}

// ---------- Administrador ----------
if ($operacion === 'GET /admin/cajeros') {
    exigirRol('admin');
    responder(['cajeros' => sp('sp_listar_cajeros')]);
}

if ($operacion === 'POST /admin/cajeros') {
    exigirRol('admin');
    $datos = cuerpo();
    $nombre = texto($datos, 'nombre');
    $usuario = strtolower(texto($datos, 'usuario'));
    if ($nombre === '' || mb_strlen($nombre) > 120) {
        fallar('Ingrese el nombre completo.');
    }
    if (!preg_match('/^[a-z0-9._-]{3,60}$/', $usuario)) {
        fallar('El usuario debe tener de 3 a 60 caracteres: letras, números, punto, guion.');
    }
    $hash = validarClave($datos, 'clave', 'confirmacion');
    sp('sp_crear_cajero', [$nombre, $usuario, $hash]);
    responder(['mensaje' => 'Cajero creado.'], 201);
}

if ($metodo === 'POST' && preg_match('#^/admin/cajeros/(\d+)/bloqueo$#', $ruta, $partes)) {
    exigirRol('admin');
    sp('sp_bloquear_cajero', [(int) $partes[1], empty(cuerpo()['bloqueado']) ? 0 : 1]);
    responder(['ok' => true]);
}

if ($operacion === 'GET /admin/monitor') {
    exigirRol('admin');
    responder(sp('sp_monitor')[0]);
}

if ($operacion === 'GET /admin/logs') {
    exigirRol('admin');
    $reporte = getenv('LOG_REPORT') ?: '/var/lib/banco/reporte.html';
    header('Cache-Control: no-store');
    if (!is_file($reporte)) {
        header('Content-Type: text/plain; charset=utf-8');
        echo 'El reporte aún no se ha generado. Se actualiza cada minuto; intente de nuevo.';
        exit;
    }
    header('Content-Type: text/html; charset=utf-8');
    readfile($reporte);
    exit;
}

// ---------- Cajero ----------
if ($operacion === 'POST /cajero/cuentas') {
    $cajero = exigirRol('cajero');
    $datos = cuerpo();
    $nombre = texto($datos, 'nombre');
    if ($nombre === '' || mb_strlen($nombre) > 120) {
        fallar('Ingrese el nombre de la cuenta.');
    }
    sp('sp_crear_cuenta', [
        $nombre,
        validarNumeroCuenta(texto($datos, 'numero')),
        validarDpi(texto($datos, 'dpi')),
        validarMonto($datos, 'monto', true),
        $cajero['id'],
    ]);
    responder(['mensaje' => 'Cuenta creada.'], 201);
}

if ($operacion === 'POST /cajero/depositos' || $operacion === 'POST /cajero/retiros') {
    $cajero = exigirRol('cajero');
    $datos = cuerpo();
    $procedimiento = $ruta === '/cajero/depositos' ? 'sp_depositar' : 'sp_retirar';
    $fila = sp($procedimiento, [validarNumeroCuenta(texto($datos, 'numero')), validarMonto($datos, 'monto'), $cajero['id']]);
    responder(['mensaje' => 'Operación realizada.', 'saldo' => $fila[0]['saldo']]);
}

// ---------- Cliente ----------
if ($operacion === 'GET /cliente/resumen') {
    $cliente = exigirRol('cliente');
    responder(sp('sp_resumen_cliente', [$cliente['id']])[0]);
}

if ($operacion === 'GET /cliente/terceros') {
    $cliente = exigirRol('cliente');
    responder(['terceros' => sp('sp_listar_terceros', [$cliente['id']])]);
}

if ($operacion === 'POST /cliente/terceros') {
    $cliente = exigirRol('cliente');
    $datos = cuerpo();
    $alias = texto($datos, 'alias');
    $maximo = filter_var($datos['max_transacciones'] ?? null, FILTER_VALIDATE_INT, ['options' => ['min_range' => 1, 'max_range' => 1000]]);
    if ($alias === '' || mb_strlen($alias) > 60) {
        fallar('Ingrese un alias de hasta 60 caracteres.');
    }
    if ($maximo === false) {
        fallar('La cantidad máxima diaria debe ser un entero entre 1 y 1000.');
    }
    sp('sp_agregar_tercero', [$cliente['id'], validarNumeroCuenta(texto($datos, 'numero')), validarMonto($datos, 'monto_maximo'), $maximo, $alias]);
    responder(['mensaje' => 'Cuenta de tercero agregada.'], 201);
}

if ($operacion === 'POST /cliente/transferencias') {
    $cliente = exigirRol('cliente');
    $datos = cuerpo();
    $tercero = filter_var($datos['tercero_id'] ?? null, FILTER_VALIDATE_INT, ['options' => ['min_range' => 1]]);
    if ($tercero === false) {
        fallar('Seleccione una cuenta de tercero.');
    }
    $fila = sp('sp_transferir', [$cliente['id'], $tercero, validarMonto($datos, 'monto')]);
    responder(['mensaje' => 'Transferencia realizada.', 'saldo' => $fila[0]['saldo']]);
}

if ($operacion === 'GET /cliente/estado-cuenta') {
    $cliente = exigirRol('cliente');
    responder([
        'cuenta' => sp('sp_resumen_cliente', [$cliente['id']])[0],
        'movimientos' => sp('sp_estado_cuenta', [$cliente['id']]),
    ]);
}
