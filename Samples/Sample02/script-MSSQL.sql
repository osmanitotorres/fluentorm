if object_id('dbo.usuario', 'U') is not null
    drop table dbo.usuario;
go

create table dbo.usuario
(
    id               int identity(1,1) primary key,
    email            varchar(50)  null,
    cpf              varchar(14)  null,
    nickname         varchar(30)  null,
    bloqueado        bit          default 0,
    data_criacao     datetime2    default sysdatetime(),
    data_atualizacao datetime2    default sysdatetime(),
    senha            varchar(50)  null
);
go

insert into dbo.usuario (email, cpf, nickname, bloqueado, senha)
values ('teste@example.com', '000.000.000-00', 'teste', 0, '123');
go
