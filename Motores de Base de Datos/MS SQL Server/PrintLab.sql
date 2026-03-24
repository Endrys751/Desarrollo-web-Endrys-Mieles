CREATE TABLE CLIENTE (
    cliente_id     INT            NOT NULL IDENTITY(1,1),
    tipo_doc       NVARCHAR(5)    NOT NULL,
    num_doc        NVARCHAR(20)   NOT NULL,
    nombre         NVARCHAR(150)  NOT NULL,
    telefono       NVARCHAR(20),
    email          NVARCHAR(120),
    estado         NVARCHAR(10)   NOT NULL DEFAULT 'ACTIVO',
    creado_en      DATETIME2      NOT NULL DEFAULT GETDATE(),
    actualizado_en DATETIME2      NOT NULL DEFAULT GETDATE(),
    CONSTRAINT PK_CLIENTE    PRIMARY KEY (cliente_id),
    CONSTRAINT UQ_CLI_DOC    UNIQUE (num_doc),
    CONSTRAINT CK_CLI_TDOC   CHECK (tipo_doc IN ('CC','NIT','CE','PAS')),
    CONSTRAINT CK_CLI_ESTADO CHECK (estado IN ('ACTIVO','INACTIVO'))
);
GO

CREATE TABLE TRABAJO (
    trabajo_id     INT            NOT NULL IDENTITY(1,1),
    cliente_id     INT            NOT NULL,
    nombre         NVARCHAR(200)  NOT NULL,
    descripcion    NVARCHAR(MAX),
    estado         NVARCHAR(15)   NOT NULL DEFAULT 'PENDIENTE',
    fecha_inicio   DATETIME2,
    fecha_fin      DATETIME2,
    creado_en      DATETIME2      NOT NULL DEFAULT GETDATE(),
    actualizado_en DATETIME2      NOT NULL DEFAULT GETDATE(),
    CONSTRAINT PK_TRABAJO    PRIMARY KEY (trabajo_id),
    CONSTRAINT FK_TRB_CLI    FOREIGN KEY (cliente_id)
        REFERENCES CLIENTE(cliente_id)
        ON DELETE NO ACTION ON UPDATE CASCADE,
    CONSTRAINT CK_TRB_ESTADO CHECK (estado IN ('PENDIENTE','EN_PROCESO','COMPLETADO','CANCELADO'))
);
GO

CREATE TABLE SERVICIO (
    servicio_id    INT            NOT NULL IDENTITY(1,1),
    nombre         NVARCHAR(100)  NOT NULL,
    descripcion    NVARCHAR(300),
    precio_base    DECIMAL(10,2)  NOT NULL,
    estado         NVARCHAR(10)   NOT NULL DEFAULT 'ACTIVO',
    CONSTRAINT PK_SERVICIO    PRIMARY KEY (servicio_id),
    CONSTRAINT UQ_SRV_NOMBRE  UNIQUE (nombre),
    CONSTRAINT CK_SRV_PRECIO  CHECK (precio_base >= 0),
    CONSTRAINT CK_SRV_ESTADO  CHECK (estado IN ('ACTIVO','INACTIVO'))
);
GO

CREATE TABLE ARCHIVO (
    archivo_id     INT            NOT NULL IDENTITY(1,1),
    nombre         NVARCHAR(200)  NOT NULL,
    extension      NVARCHAR(10),
    ruta           NVARCHAR(500),
    tamanio_kb     INT,
    estado         NVARCHAR(10)   NOT NULL DEFAULT 'ACTIVO',
    creado_en      DATETIME2      NOT NULL DEFAULT GETDATE(),
    CONSTRAINT PK_ARCHIVO    PRIMARY KEY (archivo_id),
    CONSTRAINT CK_ARH_ESTADO CHECK (estado IN ('ACTIVO','INACTIVO'))
);
GO

CREATE TABLE TRABAJO_SERVICIO (
    ts_id          INT            NOT NULL IDENTITY(1,1),
    trabajo_id     INT            NOT NULL,
    servicio_id    INT            NOT NULL,
    cantidad       INT            NOT NULL DEFAULT 1,
    precio_unit    DECIMAL(10,2)  NOT NULL,
    subtotal       AS (cantidad * precio_unit) PERSISTED,
    CONSTRAINT PK_TS         PRIMARY KEY (ts_id),
    CONSTRAINT FK_TS_TRB     FOREIGN KEY (trabajo_id)
        REFERENCES TRABAJO(trabajo_id)  ON DELETE CASCADE,
    CONSTRAINT FK_TS_SRV     FOREIGN KEY (servicio_id)
        REFERENCES SERVICIO(servicio_id),
    CONSTRAINT CK_TS_CANT    CHECK (cantidad >= 1),
    CONSTRAINT CK_TS_PRECIO  CHECK (precio_unit >= 0)
);
GO

CREATE TABLE TRABAJO_ARCHIVO (
    ta_id          INT   NOT NULL IDENTITY(1,1),
    trabajo_id     INT   NOT NULL,
    archivo_id     INT   NOT NULL,
    copias         INT   NOT NULL DEFAULT 1,
    instrucciones  NVARCHAR(MAX),
    CONSTRAINT PK_TA         PRIMARY KEY (ta_id),
    CONSTRAINT FK_TA_TRB     FOREIGN KEY (trabajo_id)
        REFERENCES TRABAJO(trabajo_id)  ON DELETE CASCADE,
    CONSTRAINT FK_TA_ARH     FOREIGN KEY (archivo_id)
        REFERENCES ARCHIVO(archivo_id),
    CONSTRAINT CK_TA_COPIAS  CHECK (copias >= 1)
);
GO

CREATE TABLE MAQUINA (
    maquina_id     INT            NOT NULL IDENTITY(1,1),
    nombre         NVARCHAR(100)  NOT NULL,
    descripcion    NVARCHAR(300),
    tipo           NVARCHAR(50),
    estado         NVARCHAR(10)   NOT NULL DEFAULT 'ACTIVO',
    creado_en      DATETIME2      NOT NULL DEFAULT GETDATE(),
    CONSTRAINT PK_MAQUINA    PRIMARY KEY (maquina_id),
    CONSTRAINT CK_MAQ_ESTADO CHECK (estado IN ('ACTIVO','INACTIVO'))
);
GO

CREATE TABLE COLAMAQUINA (
    cola_id          INT         NOT NULL IDENTITY(1,1),
    maquina_id       INT         NOT NULL,
    trabajo_id       INT         NOT NULL,
    prioridad        INT         NOT NULL DEFAULT 5,
    estado           NVARCHAR(15) NOT NULL DEFAULT 'PENDIENTE',
    inicio_estimado  DATETIME2,
    fin_estimado     DATETIME2,
    inicio_real      DATETIME2,
    fin_real         DATETIME2,
    creado_en        DATETIME2   NOT NULL DEFAULT GETDATE(),
    CONSTRAINT PK_COLA        PRIMARY KEY (cola_id),
    CONSTRAINT FK_COLA_MAQ    FOREIGN KEY (maquina_id) REFERENCES MAQUINA(maquina_id),
    CONSTRAINT FK_COLA_TRB    FOREIGN KEY (trabajo_id) REFERENCES TRABAJO(trabajo_id),
    CONSTRAINT CK_COLA_ESTADO CHECK (estado IN ('PENDIENTE','EN_PROCESO','COMPLETADO','CANCELADO')),
    CONSTRAINT CK_COLA_PRIO   CHECK (prioridad BETWEEN 1 AND 10)
);
GO

-- Trigger anti-solapamiento en SQL Server:
CREATE TRIGGER TRG_COLA_NO_SOLAPAMIENTO
ON COLAMAQUINA
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (
        SELECT maquina_id FROM inserted WHERE estado = 'EN_PROCESO'
    )
    BEGIN
        IF EXISTS (
            SELECT 1
            FROM COLAMAQUINA c
            JOIN inserted i ON c.maquina_id = i.maquina_id
            WHERE c.estado = 'EN_PROCESO'
              AND c.cola_id <> i.cola_id
        )
        BEGIN
            RAISERROR('La máquina ya tiene un trabajo EN_PROCESO', 16, 1);
            ROLLBACK TRANSACTION;
        END
    END
END;
GO

CREATE TABLE FACTURA (
    factura_id     INT            NOT NULL IDENTITY(1,1),
    trabajo_id     INT            NOT NULL,
    fecha          DATETIME2      NOT NULL DEFAULT GETDATE(),
    subtotal       DECIMAL(10,2)  NOT NULL,
    impuesto       DECIMAL(10,2)  NOT NULL DEFAULT 0.00,
    total          DECIMAL(10,2)  NOT NULL,
    estado         NVARCHAR(10)   NOT NULL DEFAULT 'PENDIENTE',
    creado_en      DATETIME2      NOT NULL DEFAULT GETDATE(),
    CONSTRAINT PK_FACTURA    PRIMARY KEY (factura_id),
    CONSTRAINT UQ_FAC_TRB    UNIQUE (trabajo_id),
    CONSTRAINT FK_FAC_TRB    FOREIGN KEY (trabajo_id) REFERENCES TRABAJO(trabajo_id),
    CONSTRAINT CK_FAC_ESTADO CHECK (estado IN ('PENDIENTE','PAGADO','ANULADO'))
);
GO

CREATE TABLE PAGO (
    pago_id        INT            NOT NULL IDENTITY(1,1),
    factura_id     INT            NOT NULL,
    metodo         NVARCHAR(30)   NOT NULL,
    monto          DECIMAL(10,2)  NOT NULL,
    fecha          DATETIME2      NOT NULL DEFAULT GETDATE(),
    referencia_ext NVARCHAR(100),
    estado         NVARCHAR(12)   NOT NULL DEFAULT 'COMPLETADO',
    creado_en      DATETIME2      NOT NULL DEFAULT GETDATE(),
    CONSTRAINT PK_PAGO       PRIMARY KEY (pago_id),
    CONSTRAINT FK_PAG_FAC    FOREIGN KEY (factura_id) REFERENCES FACTURA(factura_id),
    CONSTRAINT CK_PAG_METODO CHECK (metodo IN ('EFECTIVO','TARJETA','TRANSFERENCIA','NEQUI','DAVIPLATA')),
    CONSTRAINT CK_PAG_MONTO  CHECK (monto > 0),
    CONSTRAINT CK_PAG_ESTADO CHECK (estado IN ('COMPLETADO','ANULADO','PENDIENTE'))
);
GO