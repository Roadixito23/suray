-- Tabla de horarios
CREATE TABLE horarios (
    id INT AUTO_INCREMENT PRIMARY KEY,
    region ENUM('aysen', 'coyhaique') NOT NULL,
    tipo_dia ENUM('lunesViernes', 'sabados', 'domingosFeriados') NOT NULL,
    hora TIME NOT NULL,
    activo BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_region_tipo (region, tipo_dia),
    INDEX idx_activo (activo)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Tabla de feriados
CREATE TABLE feriados (
    id INT AUTO_INCREMENT PRIMARY KEY,
    anio INT NOT NULL,
    mes TINYINT NOT NULL,
    dia TINYINT NOT NULL,
    nombre VARCHAR(100) NOT NULL,
    activo BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY unique_fecha (anio, mes, dia),
    INDEX idx_anio (anio),
    INDEX idx_activo (activo)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Tabla de estaciones de ruta
CREATE TABLE ruta_estaciones (
    id VARCHAR(50) PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    full_name VARCHAR(200) NOT NULL,
    km INT NOT NULL,
    side ENUM('left', 'center', 'right') DEFAULT 'center',
    is_terminal BOOLEAN DEFAULT FALSE,
    icon VARCHAR(50),
    activo BOOLEAN DEFAULT TRUE,
    orden INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_km (km),
    INDEX idx_activo (activo),
    INDEX idx_orden (orden)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;