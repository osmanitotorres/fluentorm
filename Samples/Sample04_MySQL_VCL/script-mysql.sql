-- FluentORM Sample04 - estrutura (o botao "Criar banco/tabela" faz o mesmo).
CREATE DATABASE IF NOT EXISTS fluentorm_demo CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE fluentorm_demo;

CREATE TABLE IF NOT EXISTS cliente (
  id              INT AUTO_INCREMENT PRIMARY KEY,
  nome            VARCHAR(100)   NOT NULL,
  email           VARCHAR(120)   NULL,
  cpf             VARCHAR(14)    NULL,
  telefone        VARCHAR(20)    NULL,
  data_nascimento DATE           NULL,
  limite_credito  DECIMAL(12,2)  NOT NULL DEFAULT 0,
  ativo           TINYINT(1)     NOT NULL DEFAULT 1,
  observacao      TEXT           NULL,
  criado_em       DATETIME       NOT NULL DEFAULT CURRENT_TIMESTAMP,
  atualizado_em   DATETIME       NULL ON UPDATE CURRENT_TIMESTAMP,
  KEY ix_cliente_nome (nome)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Se o usuario nao tiver permissao para criar bancos, rode como root:
-- GRANT ALL PRIVILEGES ON fluentorm_demo.* TO 'osmanito'@'localhost';
