-- Banco Mariano: estructura de la base de datos (en blanco).
CREATE DATABASE IF NOT EXISTS banco_mariano CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE banco_mariano;

CREATE TABLE cuentas (
  id            INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  numero        VARCHAR(20)   NOT NULL,
  nombre        VARCHAR(120)  NOT NULL,
  dpi           CHAR(13)      NOT NULL,
  saldo         DECIMAL(14,2) NOT NULL DEFAULT 0,
  creado_en     DATETIME      NOT NULL,
  UNIQUE KEY uq_cuentas_numero (numero),
  KEY ix_cuentas_creado (creado_en),
  CONSTRAINT ck_cuentas_saldo CHECK (saldo >= 0)
) ENGINE=InnoDB;

CREATE TABLE usuarios (
  id              INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  nombre          VARCHAR(120) NOT NULL,
  usuario         VARCHAR(120) NOT NULL,
  clave_hash      VARCHAR(255) NOT NULL,
  rol             ENUM('admin','cajero','cliente') NOT NULL,
  bloqueado       TINYINT(1)   NOT NULL DEFAULT 0,
  cuenta_id       INT UNSIGNED NULL,
  intentos        TINYINT UNSIGNED NOT NULL DEFAULT 0,
  bloqueado_hasta DATETIME     NULL,
  creado_en       DATETIME     NOT NULL,
  UNIQUE KEY uq_usuarios_usuario (usuario),
  UNIQUE KEY uq_usuarios_cuenta (cuenta_id),
  KEY ix_usuarios_rol_creado (rol, creado_en),
  CONSTRAINT fk_usuarios_cuenta FOREIGN KEY (cuenta_id) REFERENCES cuentas (id)
) ENGINE=InnoDB;

CREATE TABLE cuentas_terceros (
  id                 INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  usuario_id         INT UNSIGNED  NOT NULL,
  cuenta_id          INT UNSIGNED  NOT NULL,
  alias              VARCHAR(60)   NOT NULL,
  monto_maximo       DECIMAL(14,2) NOT NULL,
  max_transacciones  INT UNSIGNED  NOT NULL,
  creado_en          DATETIME      NOT NULL,
  UNIQUE KEY uq_tercero_usuario_cuenta (usuario_id, cuenta_id),
  CONSTRAINT fk_tercero_usuario FOREIGN KEY (usuario_id) REFERENCES usuarios (id),
  CONSTRAINT fk_tercero_cuenta FOREIGN KEY (cuenta_id) REFERENCES cuentas (id)
) ENGINE=InnoDB;

CREATE TABLE movimientos (
  id                INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  tipo              ENUM('apertura','deposito','retiro','transferencia') NOT NULL,
  cuenta_origen_id  INT UNSIGNED  NULL,
  cuenta_destino_id INT UNSIGNED  NULL,
  monto             DECIMAL(14,2) NOT NULL,
  saldo_origen      DECIMAL(14,2) NULL,
  saldo_destino     DECIMAL(14,2) NULL,
  tercero_id        INT UNSIGNED  NULL,
  realizado_por     INT UNSIGNED  NOT NULL,
  creado_en         DATETIME      NOT NULL,
  KEY ix_mov_origen (cuenta_origen_id, creado_en),
  KEY ix_mov_destino (cuenta_destino_id, creado_en),
  KEY ix_mov_tercero (tercero_id, creado_en),
  KEY ix_mov_tipo (tipo, creado_en),
  CONSTRAINT fk_mov_origen FOREIGN KEY (cuenta_origen_id) REFERENCES cuentas (id),
  CONSTRAINT fk_mov_destino FOREIGN KEY (cuenta_destino_id) REFERENCES cuentas (id),
  CONSTRAINT fk_mov_tercero FOREIGN KEY (tercero_id) REFERENCES cuentas_terceros (id),
  CONSTRAINT fk_mov_usuario FOREIGN KEY (realizado_por) REFERENCES usuarios (id)
) ENGINE=InnoDB;
