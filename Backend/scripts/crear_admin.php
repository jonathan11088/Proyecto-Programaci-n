<?php
declare(strict_types=1);

// Crea el administrador inicial si no existe. Se ejecuta al arrancar el contenedor.
require __DIR__ . '/../src/nucleo.php';

$usuario = strtolower(getenv('ADMIN_USER') ?: 'admin');
$clave = getenv('ADMIN_PASSWORD') ?: '';
if (strlen($clave) < 8) {
    fwrite(STDERR, "ADMIN_PASSWORD debe tener al menos 8 caracteres.\n");
    exit(1);
}
sp('sp_crear_admin_inicial', [$usuario, 'Administrador', password_hash($clave, PASSWORD_DEFAULT)]);
echo "Administrador listo: $usuario\n";
