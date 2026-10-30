-- FluentORM Sample03 - MySQL 8+
-- CREATE DATABASE fluentorm_demo CHARACTER SET utf8mb4; USE fluentorm_demo;

DROP TABLE IF EXISTS produto;
DROP TABLE IF EXISTS usuario;

CREATE TABLE usuario
(
    id               INT AUTO_INCREMENT PRIMARY KEY,
    email            VARCHAR(100) NULL,
    cpf              VARCHAR(14)  NULL,
    nickname         VARCHAR(30)  NULL,
    bloqueado        TINYINT(1)   NOT NULL DEFAULT 0,
    data_criacao     DATETIME     DEFAULT CURRENT_TIMESTAMP,
    data_atualizacao DATETIME     DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    senha            VARCHAR(100) NULL
);

CREATE TABLE produto
(
    id         BIGINT AUTO_INCREMENT PRIMARY KEY,
    codigo     CHAR(36)       NOT NULL,   -- TGUID sem chaves
    nome       VARCHAR(100)   NOT NULL,
    preco      DECIMAL(12, 2) NOT NULL,
    peso       DOUBLE         NULL,
    validade   DATE           NULL,
    foto       BLOB           NULL,
    observacao VARCHAR(200)   NULL
);
