CREATE DATABASE printlab

    WITH OWNER      = postgres
         ENCODING   = 'UTF8'
         LC_COLLATE = 'es_CO.UTF-8'
         LC_CTYPE   = 'es_CO.UTF-8'
         TEMPLATE   = template0
         CONNECTION LIMIT = -1;

		 COMMENT ON DATABASE printlab
    IS 'PrintLab - Centro de copiado e impresión';

CREATE SEQUENCE seq_cliente    START 1 INCREMENT 1;
CREATE SEQUENCE seq_trabajo    START 1 INCREMENT 1;
CREATE SEQUENCE seq_servicio   START 1 INCREMENT 1;
CREATE SEQUENCE seq_archivo    START 1 INCREMENT 1;
CREATE SEQUENCE seq_ts         START 1 INCREMENT 1;
CREATE SEQUENCE seq_ta         START 1 INCREMENT 1;
CREATE SEQUENCE seq_maquina    START 1 INCREMENT 1;
CREATE SEQUENCE seq_cola       START 1 INCREMENT 1;
CREATE SEQUENCE seq_factura    START 1 INCREMENT 1;
CREATE SEQUENCE seq_pago       START 1 INCREMENT 1;

CREATE TABLE CLIENTE (
    cliente_id     INTEGER       NOT NULL DEFAULT nextval('seq_cliente'),
    tipo_doc       VARCHAR(5)    NOT NULL,
    num_doc        VARCHAR(20)   NOT NULL,
    nombre         VARCHAR(150)  NOT NULL,
    telefono       VARCHAR(20),
    email          VARCHAR(120),
    estado         VARCHAR(10)   NOT NULL DEFAULT 'ACTIVO',
    creado_en      TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    actualizado_en TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT PK_CLIENTE    PRIMARY KEY (cliente_id),
    CONSTRAINT UQ_CLI_DOC    UNIQUE (num_doc),
    CONSTRAINT CK_CLI_TDOC   CHECK (tipo_doc IN ('CC','NIT','CE','PAS')),
    CONSTRAINT CK_CLI_ESTADO CHECK (estado IN ('ACTIVO','INACTIVO'))
);

CREATE TABLE TRABAJO (
    trabajo_id     INTEGER       NOT NULL DEFAULT nextval('seq_trabajo'),
    cliente_id     INTEGER       NOT NULL,
    nombre         VARCHAR(200)  NOT NULL,
    descripcion    TEXT,
    estado         VARCHAR(15)   NOT NULL DEFAULT 'PENDIENTE',
    fecha_inicio   TIMESTAMP,
    fecha_fin      TIMESTAMP,
    creado_en      TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    actualizado_en TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT PK_TRABAJO    PRIMARY KEY (trabajo_id),
    CONSTRAINT FK_TRB_CLI    FOREIGN KEY (cliente_id)
        REFERENCES CLIENTE(cliente_id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT CK_TRB_ESTADO CHECK (estado IN ('PENDIENTE','EN_PROCESO','COMPLETADO','CANCELADO'))
);

CREATE TABLE SERVICIO (
    servicio_id    INTEGER        NOT NULL DEFAULT nextval('seq_servicio'),
    nombre         VARCHAR(100)   NOT NULL,
    descripcion    VARCHAR(300),
    precio_base    NUMERIC(10,2)  NOT NULL,
    estado         VARCHAR(10)    NOT NULL DEFAULT 'ACTIVO',
    CONSTRAINT PK_SERVICIO    PRIMARY KEY (servicio_id),
    CONSTRAINT UQ_SRV_NOMBRE  UNIQUE (nombre),
    CONSTRAINT CK_SRV_PRECIO  CHECK (precio_base >= 0),
    CONSTRAINT CK_SRV_ESTADO  CHECK (estado IN ('ACTIVO','INACTIVO'))
);

CREATE TABLE ARCHIVO (
    archivo_id     INTEGER        NOT NULL DEFAULT nextval('seq_archivo'),
    nombre         VARCHAR(200)   NOT NULL,
    extension      VARCHAR(10),
    ruta           VARCHAR(500),
    tamanio_kb     INTEGER,
    estado         VARCHAR(10)    NOT NULL DEFAULT 'ACTIVO',
    creado_en      TIMESTAMP      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT PK_ARCHIVO    PRIMARY KEY (archivo_id),
    CONSTRAINT CK_ARH_ESTADO CHECK (estado IN ('ACTIVO','INACTIVO'))
);

CREATE TABLE TRABAJO_SERVICIO (
    ts_id          INTEGER        NOT NULL DEFAULT nextval('seq_ts'),
    trabajo_id     INTEGER        NOT NULL,
    servicio_id    INTEGER        NOT NULL,
    cantidad       INTEGER        NOT NULL DEFAULT 1,
    precio_unit    NUMERIC(10,2)  NOT NULL,
    subtotal       NUMERIC(10,2)  GENERATED ALWAYS AS (cantidad * precio_unit) STORED,
    CONSTRAINT PK_TS         PRIMARY KEY (ts_id),
    CONSTRAINT FK_TS_TRB     FOREIGN KEY (trabajo_id)  REFERENCES TRABAJO(trabajo_id)  ON DELETE CASCADE,
    CONSTRAINT FK_TS_SRV     FOREIGN KEY (servicio_id) REFERENCES SERVICIO(servicio_id),
    CONSTRAINT CK_TS_CANT    CHECK (cantidad >= 1),
    CONSTRAINT CK_TS_PRECIO  CHECK (precio_unit >= 0)
);

CREATE TABLE TRABAJO_ARCHIVO (
    ta_id          INTEGER   NOT NULL DEFAULT nextval('seq_ta'),
    trabajo_id     INTEGER   NOT NULL,
    archivo_id     INTEGER   NOT NULL,
    copias         INTEGER   NOT NULL DEFAULT 1,
    instrucciones  TEXT,
    CONSTRAINT PK_TA         PRIMARY KEY (ta_id),
    CONSTRAINT FK_TA_TRB     FOREIGN KEY (trabajo_id) REFERENCES TRABAJO(trabajo_id) ON DELETE CASCADE,
    CONSTRAINT FK_TA_ARH     FOREIGN KEY (archivo_id) REFERENCES ARCHIVO(archivo_id),
    CONSTRAINT CK_TA_COPIAS  CHECK (copias >= 1)
);

CREATE TABLE MAQUINA (
    maquina_id     INTEGER       NOT NULL DEFAULT nextval('seq_maquina'),
    nombre         VARCHAR(100)  NOT NULL,
    descripcion    VARCHAR(300),
    tipo           VARCHAR(50),
    estado         VARCHAR(10)   NOT NULL DEFAULT 'ACTIVO',
    creado_en      TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT PK_MAQUINA    PRIMARY KEY (maquina_id),
    CONSTRAINT CK_MAQ_ESTADO CHECK (estado IN ('ACTIVO','INACTIVO'))
);

CREATE TABLE COLAMAQUINA (
    cola_id          INTEGER     NOT NULL DEFAULT nextval('seq_cola'),
    maquina_id       INTEGER     NOT NULL,
    trabajo_id       INTEGER     NOT NULL,
    prioridad        INTEGER     NOT NULL DEFAULT 5,
    estado           VARCHAR(15) NOT NULL DEFAULT 'PENDIENTE',
    inicio_estimado  TIMESTAMP,
    fin_estimado     TIMESTAMP,
    inicio_real      TIMESTAMP,
    fin_real         TIMESTAMP,
    creado_en        TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT PK_COLA        PRIMARY KEY (cola_id),
    CONSTRAINT FK_COLA_MAQ    FOREIGN KEY (maquina_id) REFERENCES MAQUINA(maquina_id),
    CONSTRAINT FK_COLA_TRB    FOREIGN KEY (trabajo_id) REFERENCES TRABAJO(trabajo_id),
    CONSTRAINT CK_COLA_ESTADO CHECK (estado IN ('PENDIENTE','EN_PROCESO','COMPLETADO','CANCELADO')),
    CONSTRAINT CK_COLA_PRIO   CHECK (prioridad BETWEEN 1 AND 10)
);

CREATE OR REPLACE FUNCTION fn_no_solapamiento_cola()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.estado = 'EN_PROCESO' THEN
        IF EXISTS (
            SELECT 1 FROM COLAMAQUINA
            WHERE maquina_id = NEW.maquina_id
              AND estado = 'EN_PROCESO'
              AND cola_id <> COALESCE(NEW.cola_id, -1)
        ) THEN
            RAISE EXCEPTION 'La máquina % ya tiene un trabajo EN_PROCESO', NEW.maquina_id;
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER TRG_COLA_NO_SOLAPAMIENTO
    BEFORE INSERT OR UPDATE ON COLAMAQUINA
    FOR EACH ROW EXECUTE FUNCTION fn_no_solapamiento_cola();

CREATE TABLE FACTURA (
    factura_id     INTEGER        NOT NULL DEFAULT nextval('seq_factura'),
    trabajo_id     INTEGER        NOT NULL,
    fecha          TIMESTAMP      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    subtotal       NUMERIC(10,2)  NOT NULL,
    impuesto       NUMERIC(10,2)  NOT NULL DEFAULT 0.00,
    total          NUMERIC(10,2)  NOT NULL,
    estado         VARCHAR(10)    NOT NULL DEFAULT 'PENDIENTE',
    creado_en      TIMESTAMP      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT PK_FACTURA    PRIMARY KEY (factura_id),
    CONSTRAINT UQ_FAC_TRB    UNIQUE (trabajo_id),
    CONSTRAINT FK_FAC_TRB    FOREIGN KEY (trabajo_id) REFERENCES TRABAJO(trabajo_id),
    CONSTRAINT CK_FAC_ESTADO CHECK (estado IN ('PENDIENTE','PAGADO','ANULADO'))
);

CREATE TABLE PAGO (
    pago_id        INTEGER        NOT NULL DEFAULT nextval('seq_pago'),
    factura_id     INTEGER        NOT NULL,
    metodo         VARCHAR(30)    NOT NULL,
    monto          NUMERIC(10,2)  NOT NULL,
    fecha          TIMESTAMP      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    referencia_ext VARCHAR(100),
    estado         VARCHAR(12)    NOT NULL DEFAULT 'COMPLETADO',
    creado_en      TIMESTAMP      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT PK_PAGO       PRIMARY KEY (pago_id),
    CONSTRAINT FK_PAG_FAC    FOREIGN KEY (factura_id) REFERENCES FACTURA(factura_id),
    CONSTRAINT CK_PAG_METODO CHECK (metodo IN ('EFECTIVO','TARJETA','TRANSFERENCIA','NEQUI','DAVIPLATA')),
    CONSTRAINT CK_PAG_MONTO  CHECK (monto > 0),
    CONSTRAINT CK_PAG_ESTADO CHECK (estado IN ('COMPLETADO','ANULADO','PENDIENTE'))
);
