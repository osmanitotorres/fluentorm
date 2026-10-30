-- FluentORM Sample03 - SQL Server 2016+
-- CREATE DATABASE fluentorm_demo; GO; USE fluentorm_demo; GO

IF OBJECT_ID('dbo.produto', 'U') IS NOT NULL DROP TABLE dbo.produto;
IF OBJECT_ID('dbo.usuario', 'U') IS NOT NULL DROP TABLE dbo.usuario;
GO

CREATE TABLE dbo.usuario
(
    id               INT IDENTITY(1,1) PRIMARY KEY,
    email            NVARCHAR(100) NULL,
    cpf              VARCHAR(14)   NULL,
    nickname         NVARCHAR(30)  NULL,
    bloqueado        BIT           NOT NULL DEFAULT 0,
    data_criacao     DATETIME2     DEFAULT SYSDATETIME(),
    data_atualizacao DATETIME2     DEFAULT SYSDATETIME(),
    senha            NVARCHAR(100) NULL
);
GO

CREATE TABLE dbo.produto
(
    id         BIGINT IDENTITY(1,1) PRIMARY KEY,
    codigo     UNIQUEIDENTIFIER NOT NULL,
    nome       NVARCHAR(100)    NOT NULL,
    preco      DECIMAL(12, 2)   NOT NULL,
    peso       FLOAT            NULL,
    validade   DATE             NULL,
    foto       VARBINARY(MAX)   NULL,
    observacao NVARCHAR(200)    NULL
);
GO

-- Trigger de auditoria: com ela, "INSERT ... OUTPUT INSERTED.id" (sem INTO)
-- falharia com o erro 334. O TRepository usa OUTPUT ... INTO @tabela e funciona.
CREATE TRIGGER trg_produto_auditoria ON dbo.produto AFTER INSERT, UPDATE AS
BEGIN
    SET NOCOUNT ON;
END;
GO
