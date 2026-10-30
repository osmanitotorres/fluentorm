unit uSample03.Entities;

{ DTOs usados pelo Sample03. As mesmas classes funcionam nos tres bancos;
  as diferencas de dialeto ficam a cargo do TRepository<T>. }

interface

uses
  System.SysUtils,
  uFluentORM.Attributes;

type
  [Table('usuario')]
  TUsuarioDTO = class
  private
    FId: Integer;
    FEmail: string;
    FCpf: string;
    FNickname: string;
    FBloqueado: Boolean;
    FDataCriacao: TDateTime;
    FSenha: string;
  public
    [Key(True)]                // identity / auto_increment / generated as identity
    [Column('id')]
    property Id: Integer read FId write FId;

    [Column('email')]
    property Email: string read FEmail write FEmail;

    [Column('cpf')]
    property Cpf: string read FCpf write FCpf;

    [Column('nickname')]
    property Nickname: string read FNickname write FNickname;

    [Column('bloqueado')]      // tinyint(1) / bit / boolean
    property Bloqueado: Boolean read FBloqueado write FBloqueado;

    [ReadOnly]                 // preenchido pelo DEFAULT do banco
    [Column('data_criacao')]
    property DataCriacao: TDateTime read FDataCriacao write FDataCriacao;

    [Column('senha')]
    property Senha: string read FSenha write FSenha;
  end;

  /// Demonstra o mapeamento de tipos: Int64, TGUID, Currency, Double, TDate,
  /// TBytes (blob) e Variant (coluna nullable).
  [Table('produto')]
  TProdutoDTO = class
  private
    FId: Int64;
    FCodigo: TGUID;
    FNome: string;
    FPreco: Currency;
    FPeso: Double;
    FValidade: TDate;
    FFoto: TBytes;
    FObservacao: Variant;
  public
    [Key(True)]
    [Column('id')]
    property Id: Int64 read FId write FId;

    [Column('codigo')]         // char(36) / uniqueidentifier / uuid
    property Codigo: TGUID read FCodigo write FCodigo;

    [Column('nome')]
    property Nome: string read FNome write FNome;

    [Column('preco')]          // decimal / numeric
    property Preco: Currency read FPreco write FPreco;

    [Column('peso')]           // double / float / double precision
    property Peso: Double read FPeso write FPeso;

    [Column('validade')]       // date
    property Validade: TDate read FValidade write FValidade;

    [Column('foto')]           // blob / varbinary(max) / bytea
    property Foto: TBytes read FFoto write FFoto;

    [Column('observacao')]     // Null -> NULL no banco
    property Observacao: Variant read FObservacao write FObservacao;
  end;

implementation

end.
