create table usuario
(
    id               int auto_increment
        primary key,
    email            varchar(50)                          null,
    cpf              varchar(14)                          null,
    nickname         varchar(30)                          null,
    bloqueado        tinyint(1) default 0                 null,
    data_criacao     datetime   default CURRENT_TIMESTAMP null,
    data_atualizacao datetime   default CURRENT_TIMESTAMP null on update CURRENT_TIMESTAMP,
    senha            varchar(50)                          null
);

