SHOW DATABASES LIKE 'printlab';

CREATE DATABASE IF NOT EXISTS printlab CHARACTER SET  utf8mb4 COLLATE  utf8mb4_spanish_ci;

    USE printlab;
       
    SELECT DATABASE();
    
    CREATE TABLE CLIENTE (
    cliente_id     INT           NOT NULL AUTO_INCREMENT,
    tipo_doc       VARCHAR(5)    NOT NULL,
    num_doc        VARCHAR(20)   NOT NULL,
    nombre         VARCHAR(150)  NOT NULL,
    telefono       VARCHAR(20),
    email          VARCHAR(120),
    estado         VARCHAR(10)   NOT NULL DEFAULT 'ACTIVO',
    creado_en      TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    actualizado_en TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP
                                 ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT PK_CLIENTE   PRIMARY KEY (cliente_id),
    CONSTRAINT UQ_CLI_DOC   UNIQUE (num_doc),
    CONSTRAINT CK_CLI_TDOC  CHECK (tipo_doc IN ('CC','NIT','CE','PAS')),
    CONSTRAINT CK_CLI_ESTADO CHECK (estado IN ('ACTIVO','INACTIVO'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_spanish_ci;

CREATE TABLE TRABAJO (
    trabajo_id     INT           NOT NULL AUTO_INCREMENT,
    cliente_id     INT           NOT NULL,
    nombre         VARCHAR(200)  NOT NULL,
    descripcion    TEXT,
    estado         VARCHAR(15)   NOT NULL DEFAULT 'PENDIENTE',
    fecha_inicio   DATETIME,
    fecha_fin      DATETIME,
    creado_en      TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    actualizado_en TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP
                                 ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT PK_TRABAJO    PRIMARY KEY (trabajo_id),
    CONSTRAINT FK_TRB_CLI    FOREIGN KEY (cliente_id)
        REFERENCES CLIENTE(cliente_id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT CK_TRB_ESTADO CHECK (estado IN ('PENDIENTE','EN_PROCESO','COMPLETADO','CANCELADO'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE SERVICIO (
    servicio_id    INT            NOT NULL AUTO_INCREMENT,
    nombre         VARCHAR(100)   NOT NULL,
    descripcion    VARCHAR(300),
    precio_base    DECIMAL(10,2)  NOT NULL,
    estado         VARCHAR(10)    NOT NULL DEFAULT 'ACTIVO',
    CONSTRAINT PK_SERVICIO    PRIMARY KEY (servicio_id),
    CONSTRAINT UQ_SRV_NOMBRE  UNIQUE (nombre),
    CONSTRAINT CK_SRV_PRECIO  CHECK (precio_base >= 0),
    CONSTRAINT CK_SRV_ESTADO  CHECK (estado IN ('ACTIVO','INACTIVO'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE ARCHIVO (
    archivo_id     INT            NOT NULL AUTO_INCREMENT,
    nombre         VARCHAR(200)   NOT NULL,
    extension      VARCHAR(10),
    ruta           VARCHAR(500),
    tamanio_kb     INT,
    estado         VARCHAR(10)    NOT NULL DEFAULT 'ACTIVO',
    creado_en      TIMESTAMP      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT PK_ARCHIVO    PRIMARY KEY (archivo_id),
    CONSTRAINT CK_ARH_ESTADO CHECK (estado IN ('ACTIVO','INACTIVO'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE TRABAJO_SERVICIO (
    ts_id          INT            NOT NULL AUTO_INCREMENT,
    trabajo_id     INT            NOT NULL,
    servicio_id    INT            NOT NULL,
    cantidad       INT            NOT NULL DEFAULT 1,
    precio_unit    DECIMAL(10,2)  NOT NULL,
    subtotal       DECIMAL(10,2)  GENERATED ALWAYS AS (cantidad * precio_unit) STORED,
    CONSTRAINT PK_TS         PRIMARY KEY (ts_id),
    CONSTRAINT FK_TS_TRB     FOREIGN KEY (trabajo_id)
        REFERENCES TRABAJO(trabajo_id)  ON DELETE CASCADE,
    CONSTRAINT FK_TS_SRV     FOREIGN KEY (servicio_id)
        REFERENCES SERVICIO(servicio_id),
    CONSTRAINT CK_TS_CANT    CHECK (cantidad >= 1),
    CONSTRAINT CK_TS_PRECIO  CHECK (precio_unit >= 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE TRABAJO_ARCHIVO (
    ta_id          INT   NOT NULL AUTO_INCREMENT,
    trabajo_id     INT   NOT NULL,
    archivo_id     INT   NOT NULL,
    copias         INT   NOT NULL DEFAULT 1,
    instrucciones  TEXT,
    CONSTRAINT PK_TA         PRIMARY KEY (ta_id),
    CONSTRAINT FK_TA_TRB     FOREIGN KEY (trabajo_id)
        REFERENCES TRABAJO(trabajo_id)  ON DELETE CASCADE,
    CONSTRAINT FK_TA_ARH     FOREIGN KEY (archivo_id)
        REFERENCES ARCHIVO(archivo_id),
    CONSTRAINT CK_TA_COPIAS  CHECK (copias >= 1)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE MAQUINA (
    maquina_id     INT           NOT NULL AUTO_INCREMENT,
    nombre         VARCHAR(100)  NOT NULL,
    descripcion    VARCHAR(300),
    tipo           VARCHAR(50),
    estado         VARCHAR(10)   NOT NULL DEFAULT 'ACTIVO',
    creado_en      TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT PK_MAQUINA    PRIMARY KEY (maquina_id),
    CONSTRAINT CK_MAQ_ESTADO CHECK (estado IN ('ACTIVO','INACTIVO'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE COLAMAQUINA (
    cola_id          INT        NOT NULL AUTO_INCREMENT,
    maquina_id       INT        NOT NULL,
    trabajo_id       INT        NOT NULL,
    prioridad        INT        NOT NULL DEFAULT 5,
    estado           VARCHAR(15) NOT NULL DEFAULT 'PENDIENTE',
    inicio_estimado  DATETIME,
    fin_estimado     DATETIME,
    inicio_real      DATETIME,
    fin_real         DATETIME,
    creado_en        TIMESTAMP  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT PK_COLA        PRIMARY KEY (cola_id),
    CONSTRAINT FK_COLA_MAQ    FOREIGN KEY (maquina_id)
        REFERENCES MAQUINA(maquina_id),
    CONSTRAINT FK_COLA_TRB    FOREIGN KEY (trabajo_id)
        REFERENCES TRABAJO(trabajo_id),
    CONSTRAINT CK_COLA_ESTADO CHECK (estado IN ('PENDIENTE','EN_PROCESO','COMPLETADO','CANCELADO')),
    CONSTRAINT CK_COLA_PRIO   CHECK (prioridad BETWEEN 1 AND 10)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

DELIMITER $$
CREATE TRIGGER TRG_COLA_NO_SOLAPAMIENTO
BEFORE INSERT ON COLAMAQUINA
FOR EACH ROW
BEGIN
    DECLARE cnt INT;
    IF NEW.estado = 'EN_PROCESO' THEN
        SELECT COUNT(*) INTO cnt
        FROM COLAMAQUINA
        WHERE maquina_id = NEW.maquina_id
          AND estado = 'EN_PROCESO';
        IF cnt > 0 THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'La máquina ya tiene un trabajo EN_PROCESO';
        END IF;
    END IF;
END$$
DELIMITER ;

CREATE TABLE FACTURA (
    factura_id     INT            NOT NULL AUTO_INCREMENT,
    trabajo_id     INT            NOT NULL,
    fecha          TIMESTAMP      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    subtotal       DECIMAL(10,2)  NOT NULL,
    impuesto       DECIMAL(10,2)  NOT NULL DEFAULT 0.00,
    total          DECIMAL(10,2)  NOT NULL,
    estado         VARCHAR(10)    NOT NULL DEFAULT 'PENDIENTE',
    creado_en      TIMESTAMP      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT PK_FACTURA    PRIMARY KEY (factura_id),
    CONSTRAINT UQ_FAC_TRB    UNIQUE (trabajo_id),
    CONSTRAINT FK_FAC_TRB    FOREIGN KEY (trabajo_id)
        REFERENCES TRABAJO(trabajo_id),
    CONSTRAINT CK_FAC_ESTADO CHECK (estado IN ('PENDIENTE','PAGADO','ANULADO'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE PAGO (
    pago_id        INT            NOT NULL AUTO_INCREMENT,
    factura_id     INT            NOT NULL,
    metodo         VARCHAR(30)    NOT NULL,
    monto          DECIMAL(10,2)  NOT NULL,
    fecha          TIMESTAMP      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    referencia_ext VARCHAR(100),
    estado         VARCHAR(12)    NOT NULL DEFAULT 'COMPLETADO',
    creado_en      TIMESTAMP      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT PK_PAGO       PRIMARY KEY (pago_id),
    CONSTRAINT FK_PAG_FAC    FOREIGN KEY (factura_id)
        REFERENCES FACTURA(factura_id),
    CONSTRAINT CK_PAG_METODO CHECK (metodo IN ('EFECTIVO','TARJETA','TRANSFERENCIA','NEQUI','DAVIPLATA')),
    CONSTRAINT CK_PAG_MONTO  CHECK (monto > 0),
    CONSTRAINT CK_PAG_ESTADO CHECK (estado IN ('COMPLETADO','ANULADO','PENDIENTE'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

SHOW TABLES;

DESCRIBE COLAMAQUINA;

SELECT
    kcu.TABLE_NAME       AS tabla,
    kcu.COLUMN_NAME      AS columna,
    kcu.CONSTRAINT_NAME  AS nombre_fk,
    kcu.REFERENCED_TABLE_NAME  AS tabla_ref,
    kcu.REFERENCED_COLUMN_NAME AS columna_ref
FROM information_schema.KEY_COLUMN_USAGE kcu
WHERE kcu.TABLE_SCHEMA = 'printlab'
  AND kcu.REFERENCED_TABLE_NAME IS NOT NULL
ORDER BY kcu.TABLE_NAME;

SHOW TRIGGERS FROM printlab;