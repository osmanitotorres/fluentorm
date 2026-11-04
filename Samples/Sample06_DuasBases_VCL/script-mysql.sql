-- FluentORM Sample06 - MySQL (o botao "Criar banco/tabela" faz o mesmo)
CREATE DATABASE IF NOT EXISTS fluentorm_sample06 CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE fluentorm_sample06;

CREATE TABLE IF NOT EXISTS cliente (
  id              INT AUTO_INCREMENT PRIMARY KEY,
  nome            VARCHAR(100)  NOT NULL,
  email           VARCHAR(120)  NULL,
  cpf             VARCHAR(14)   NULL,
  data_nascimento DATE          NULL,
  limite_credito  DECIMAL(12,2) NOT NULL DEFAULT 0,
  ativo           TINYINT(1)    NOT NULL DEFAULT 1,
  origem          VARCHAR(40)   NULL,
  criado_em       DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
