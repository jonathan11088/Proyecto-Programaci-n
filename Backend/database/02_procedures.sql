-- Banco Mariano: todo acceso a datos pasa por estos procedimientos almacenados.
SET NAMES utf8mb4;
USE banco_mariano;
DELIMITER $$

-- ---------- Autenticacion ----------
CREATE PROCEDURE sp_crear_admin_inicial(IN p_usuario VARCHAR(120), IN p_nombre VARCHAR(120), IN p_hash VARCHAR(255))
BEGIN
  IF NOT EXISTS (SELECT 1 FROM usuarios WHERE rol = 'admin') THEN
    INSERT INTO usuarios (nombre, usuario, clave_hash, rol, creado_en)
    VALUES (p_nombre, p_usuario, p_hash, 'admin', NOW());
  END IF;
END$$

CREATE PROCEDURE sp_usuario_para_login(IN p_usuario VARCHAR(120), IN p_rol VARCHAR(10))
BEGIN
  SELECT id, nombre, usuario, clave_hash, rol, bloqueado,
         (bloqueado_hasta IS NOT NULL AND bloqueado_hasta > NOW()) AS bloqueo_temporal
  FROM usuarios WHERE usuario = p_usuario AND rol = p_rol;
END$$

CREATE PROCEDURE sp_login_fallido(IN p_id INT UNSIGNED)
BEGIN
  UPDATE usuarios
  SET bloqueado_hasta = IF(intentos + 1 >= 5, NOW() + INTERVAL 15 MINUTE, bloqueado_hasta),
      intentos = IF(intentos + 1 >= 5, 0, intentos + 1)
  WHERE id = p_id;
END$$

CREATE PROCEDURE sp_login_exitoso(IN p_id INT UNSIGNED)
BEGIN
  UPDATE usuarios SET intentos = 0, bloqueado_hasta = NULL WHERE id = p_id;
END$$

CREATE PROCEDURE sp_usuario_sesion(IN p_id INT UNSIGNED)
BEGIN
  SELECT id, nombre, usuario, rol, bloqueado, cuenta_id FROM usuarios WHERE id = p_id;
END$$

-- ---------- Registro de cliente ----------
CREATE PROCEDURE sp_registrar_cliente(IN p_numero VARCHAR(20), IN p_correo VARCHAR(120),
                                      IN p_dpi CHAR(13), IN p_hash VARCHAR(255))
BEGIN
  DECLARE v_cuenta INT UNSIGNED DEFAULT NULL;
  DECLARE v_dpi CHAR(13) DEFAULT NULL;
  DECLARE v_nombre VARCHAR(120) DEFAULT NULL;
  DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; RESIGNAL; END;

  START TRANSACTION;
  SELECT id, dpi, nombre INTO v_cuenta, v_dpi, v_nombre FROM cuentas WHERE numero = p_numero FOR UPDATE;
  IF v_cuenta IS NULL THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La cuenta bancaria no existe.';
  END IF;
  IF v_dpi <> p_dpi THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El DPI no coincide con el registrado en la cuenta.';
  END IF;
  IF EXISTS (SELECT 1 FROM usuarios WHERE cuenta_id = v_cuenta) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Ya existe un usuario registrado para esta cuenta.';
  END IF;
  IF EXISTS (SELECT 1 FROM usuarios WHERE usuario = p_correo) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El correo electrónico ya está registrado.';
  END IF;
  INSERT INTO usuarios (nombre, usuario, clave_hash, rol, cuenta_id, creado_en)
  VALUES (v_nombre, p_correo, p_hash, 'cliente', v_cuenta, NOW());
  COMMIT;
END$$

-- ---------- Administrador ----------
CREATE PROCEDURE sp_listar_cajeros()
BEGIN
  SELECT id, nombre, usuario, bloqueado, creado_en FROM usuarios WHERE rol = 'cajero' ORDER BY nombre;
END$$

CREATE PROCEDURE sp_crear_cajero(IN p_nombre VARCHAR(120), IN p_usuario VARCHAR(120), IN p_hash VARCHAR(255))
BEGIN
  IF EXISTS (SELECT 1 FROM usuarios WHERE usuario = p_usuario) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El nombre de usuario ya existe.';
  END IF;
  INSERT INTO usuarios (nombre, usuario, clave_hash, rol, creado_en)
  VALUES (p_nombre, p_usuario, p_hash, 'cajero', NOW());
END$$

CREATE PROCEDURE sp_bloquear_cajero(IN p_id INT UNSIGNED, IN p_bloqueado TINYINT)
BEGIN
  IF NOT EXISTS (SELECT 1 FROM usuarios WHERE id = p_id AND rol = 'cajero') THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El cajero no existe.';
  END IF;
  UPDATE usuarios SET bloqueado = p_bloqueado WHERE id = p_id AND rol = 'cajero';
END$$

CREATE PROCEDURE sp_monitor()
BEGIN
  DECLARE v_hoy DATETIME DEFAULT CURDATE();
  DECLARE v_man DATETIME DEFAULT CURDATE() + INTERVAL 1 DAY;
  SELECT
    (SELECT COUNT(*) FROM cuentas WHERE creado_en >= v_hoy AND creado_en < v_man) AS cuentas_hoy,
    (SELECT COUNT(*) FROM usuarios WHERE rol = 'cliente' AND creado_en >= v_hoy AND creado_en < v_man) AS clientes_hoy,
    COALESCE(SUM(tipo <> 'apertura' AND creado_en >= v_hoy AND creado_en < v_man), 0) AS transacciones_hoy,
    COALESCE(SUM(tipo = 'deposito' AND creado_en >= v_hoy AND creado_en < v_man), 0) AS depositos_hoy,
    COALESCE(SUM(tipo = 'retiro' AND creado_en >= v_hoy AND creado_en < v_man), 0) AS retiros_hoy,
    COALESCE(SUM(tipo <> 'apertura'), 0) AS transacciones_total,
    COALESCE(SUM(tipo = 'deposito'), 0) AS depositos_total,
    COALESCE(SUM(tipo = 'retiro'), 0) AS retiros_total,
    COALESCE(SUM(IF(tipo = 'deposito' AND creado_en >= v_hoy AND creado_en < v_man, monto, 0)), 0) AS monto_depositos_hoy,
    COALESCE(SUM(IF(tipo = 'retiro' AND creado_en >= v_hoy AND creado_en < v_man, monto, 0)), 0) AS monto_retiros_hoy,
    COALESCE(SUM(IF(tipo = 'deposito', monto, 0)), 0) AS monto_depositos_total,
    COALESCE(SUM(IF(tipo = 'retiro', monto, 0)), 0) AS monto_retiros_total
  FROM movimientos;
END$$

-- ---------- Cajero ----------
CREATE PROCEDURE sp_crear_cuenta(IN p_nombre VARCHAR(120), IN p_numero VARCHAR(20), IN p_dpi CHAR(13),
                                 IN p_monto DECIMAL(14,2), IN p_cajero INT UNSIGNED)
BEGIN
  DECLARE v_cuenta INT UNSIGNED;
  DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; RESIGNAL; END;

  IF p_monto < 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El monto inicial no puede ser negativo.';
  END IF;
  START TRANSACTION;
  IF EXISTS (SELECT 1 FROM cuentas WHERE numero = p_numero) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El número de cuenta ya existe.';
  END IF;
  INSERT INTO cuentas (numero, nombre, dpi, saldo, creado_en) VALUES (p_numero, p_nombre, p_dpi, p_monto, NOW());
  SET v_cuenta = LAST_INSERT_ID();
  IF p_monto > 0 THEN
    INSERT INTO movimientos (tipo, cuenta_destino_id, monto, saldo_destino, realizado_por, creado_en)
    VALUES ('apertura', v_cuenta, p_monto, p_monto, p_cajero, NOW());
  END IF;
  COMMIT;
END$$

CREATE PROCEDURE sp_depositar(IN p_numero VARCHAR(20), IN p_monto DECIMAL(14,2), IN p_cajero INT UNSIGNED)
BEGIN
  DECLARE v_cuenta INT UNSIGNED DEFAULT NULL;
  DECLARE v_saldo DECIMAL(14,2) DEFAULT 0;
  DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; RESIGNAL; END;

  IF p_monto <= 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La cantidad debe ser mayor que cero.';
  END IF;
  START TRANSACTION;
  SELECT id, saldo INTO v_cuenta, v_saldo FROM cuentas WHERE numero = p_numero FOR UPDATE;
  IF v_cuenta IS NULL THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La cuenta bancaria no existe.';
  END IF;
  SET v_saldo = v_saldo + p_monto;
  UPDATE cuentas SET saldo = v_saldo WHERE id = v_cuenta;
  INSERT INTO movimientos (tipo, cuenta_destino_id, monto, saldo_destino, realizado_por, creado_en)
  VALUES ('deposito', v_cuenta, p_monto, v_saldo, p_cajero, NOW());
  COMMIT;
  SELECT v_saldo AS saldo;
END$$

CREATE PROCEDURE sp_retirar(IN p_numero VARCHAR(20), IN p_monto DECIMAL(14,2), IN p_cajero INT UNSIGNED)
BEGIN
  DECLARE v_cuenta INT UNSIGNED DEFAULT NULL;
  DECLARE v_saldo DECIMAL(14,2) DEFAULT 0;
  DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; RESIGNAL; END;

  IF p_monto <= 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La cantidad debe ser mayor que cero.';
  END IF;
  START TRANSACTION;
  SELECT id, saldo INTO v_cuenta, v_saldo FROM cuentas WHERE numero = p_numero FOR UPDATE;
  IF v_cuenta IS NULL THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La cuenta bancaria no existe.';
  END IF;
  IF v_saldo < p_monto THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Saldo insuficiente.';
  END IF;
  SET v_saldo = v_saldo - p_monto;
  UPDATE cuentas SET saldo = v_saldo WHERE id = v_cuenta;
  INSERT INTO movimientos (tipo, cuenta_origen_id, monto, saldo_origen, realizado_por, creado_en)
  VALUES ('retiro', v_cuenta, p_monto, v_saldo, p_cajero, NOW());
  COMMIT;
  SELECT v_saldo AS saldo;
END$$

-- ---------- Cliente ----------
CREATE PROCEDURE sp_resumen_cliente(IN p_usuario INT UNSIGNED)
BEGIN
  SELECT c.numero, c.nombre, c.saldo
  FROM usuarios u JOIN cuentas c ON c.id = u.cuenta_id WHERE u.id = p_usuario;
END$$

CREATE PROCEDURE sp_agregar_tercero(IN p_usuario INT UNSIGNED, IN p_numero VARCHAR(20), IN p_monto DECIMAL(14,2),
                                    IN p_max INT UNSIGNED, IN p_alias VARCHAR(60))
BEGIN
  DECLARE v_cuenta INT UNSIGNED DEFAULT NULL;
  DECLARE v_propia INT UNSIGNED DEFAULT NULL;

  IF p_monto <= 0 OR p_max < 1 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El monto máximo y la cantidad diaria deben ser mayores que cero.';
  END IF;
  SELECT id INTO v_cuenta FROM cuentas WHERE numero = p_numero;
  IF v_cuenta IS NULL THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La cuenta bancaria no existe.';
  END IF;
  SELECT cuenta_id INTO v_propia FROM usuarios WHERE id = p_usuario;
  IF v_propia = v_cuenta THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'No puede agregar su propia cuenta como cuenta de tercero.';
  END IF;
  IF EXISTS (SELECT 1 FROM cuentas_terceros WHERE usuario_id = p_usuario AND cuenta_id = v_cuenta) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Esta cuenta ya está registrada como tercero.';
  END IF;
  INSERT INTO cuentas_terceros (usuario_id, cuenta_id, alias, monto_maximo, max_transacciones, creado_en)
  VALUES (p_usuario, v_cuenta, p_alias, p_monto, p_max, NOW());
END$$

CREATE PROCEDURE sp_listar_terceros(IN p_usuario INT UNSIGNED)
BEGIN
  SELECT t.id, t.alias, c.numero, t.monto_maximo, t.max_transacciones,
         (SELECT COUNT(*) FROM movimientos m
          WHERE m.tercero_id = t.id AND m.creado_en >= CURDATE() AND m.creado_en < CURDATE() + INTERVAL 1 DAY) AS usadas_hoy
  FROM cuentas_terceros t JOIN cuentas c ON c.id = t.cuenta_id
  WHERE t.usuario_id = p_usuario ORDER BY t.alias;
END$$

CREATE PROCEDURE sp_transferir(IN p_usuario INT UNSIGNED, IN p_tercero INT UNSIGNED, IN p_monto DECIMAL(14,2))
BEGIN
  DECLARE v_origen INT UNSIGNED DEFAULT NULL;
  DECLARE v_destino INT UNSIGNED DEFAULT NULL;
  DECLARE v_maximo DECIMAL(14,2) DEFAULT 0;
  DECLARE v_limite INT UNSIGNED DEFAULT 0;
  DECLARE v_usadas INT UNSIGNED DEFAULT 0;
  DECLARE v_saldo_origen DECIMAL(14,2) DEFAULT 0;
  DECLARE v_saldo_destino DECIMAL(14,2) DEFAULT 0;
  DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; RESIGNAL; END;

  IF p_monto <= 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La cantidad debe ser mayor que cero.';
  END IF;

  START TRANSACTION;
  -- El bloqueo de la fila del tercero serializa el conteo diario.
  SELECT cuenta_id, monto_maximo, max_transacciones INTO v_destino, v_maximo, v_limite
  FROM cuentas_terceros WHERE id = p_tercero AND usuario_id = p_usuario FOR UPDATE;
  IF v_destino IS NULL THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La cuenta de tercero no está disponible para este usuario.';
  END IF;
  IF p_monto > v_maximo THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El monto supera el máximo permitido para esta cuenta.';
  END IF;
  SELECT COUNT(*) INTO v_usadas FROM movimientos
  WHERE tercero_id = p_tercero AND creado_en >= CURDATE() AND creado_en < CURDATE() + INTERVAL 1 DAY;
  IF v_usadas >= v_limite THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Se alcanzó el máximo de transferencias diarias para esta cuenta.';
  END IF;

  SELECT cuenta_id INTO v_origen FROM usuarios WHERE id = p_usuario;
  -- Bloqueo en orden de id para evitar interbloqueos entre transferencias cruzadas.
  IF v_origen < v_destino THEN
    SELECT saldo INTO v_saldo_origen FROM cuentas WHERE id = v_origen FOR UPDATE;
    SELECT saldo INTO v_saldo_destino FROM cuentas WHERE id = v_destino FOR UPDATE;
  ELSE
    SELECT saldo INTO v_saldo_destino FROM cuentas WHERE id = v_destino FOR UPDATE;
    SELECT saldo INTO v_saldo_origen FROM cuentas WHERE id = v_origen FOR UPDATE;
  END IF;
  IF v_saldo_origen < p_monto THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Saldo insuficiente.';
  END IF;

  SET v_saldo_origen = v_saldo_origen - p_monto;
  SET v_saldo_destino = v_saldo_destino + p_monto;
  UPDATE cuentas SET saldo = v_saldo_origen WHERE id = v_origen;
  UPDATE cuentas SET saldo = v_saldo_destino WHERE id = v_destino;
  INSERT INTO movimientos (tipo, cuenta_origen_id, cuenta_destino_id, monto, saldo_origen, saldo_destino,
                           tercero_id, realizado_por, creado_en)
  VALUES ('transferencia', v_origen, v_destino, p_monto, v_saldo_origen, v_saldo_destino, p_tercero, p_usuario, NOW());
  COMMIT;
  SELECT v_saldo_origen AS saldo;
END$$

CREATE PROCEDURE sp_estado_cuenta(IN p_usuario INT UNSIGNED)
BEGIN
  DECLARE v_cuenta INT UNSIGNED DEFAULT NULL;
  SELECT cuenta_id INTO v_cuenta FROM usuarios WHERE id = p_usuario;
  SELECT m.id, m.creado_en, m.tipo,
         IF(m.cuenta_origen_id = v_cuenta, m.monto, NULL) AS debito,
         IF(m.cuenta_destino_id = v_cuenta, m.monto, NULL) AS credito,
         IF(m.cuenta_origen_id = v_cuenta, m.saldo_origen, m.saldo_destino) AS saldo,
         IF(m.tipo = 'transferencia',
            IF(m.cuenta_origen_id = v_cuenta, co_dest.numero, co_orig.numero), NULL) AS contraparte
  FROM movimientos m
  LEFT JOIN cuentas co_orig ON co_orig.id = m.cuenta_origen_id
  LEFT JOIN cuentas co_dest ON co_dest.id = m.cuenta_destino_id
  WHERE m.cuenta_origen_id = v_cuenta OR m.cuenta_destino_id = v_cuenta
  ORDER BY m.id DESC;
END$$

DELIMITER ;
