// ------------------------------------------------------------------
// Classe gerada automaticamente pelo FluentORM DTO Generator
// Data: 03/11/2026
// Ajuste manualmente conforme necessario.
// ------------------------------------------------------------------

unit uDTO_Cliente;

interface

uses
  uFluentORM.Attributes;

type
  [Table('cliente')]
  TClienteDTO = class
  private
    FId: Integer;
    FNome: string;
    FEmail: string;
    FCpf: string;
    FTelefone: string;
    FDataNascimento: TDateTime;
    FLimiteCredito: Currency;
    FAtivo: Boolean;
    FObservacao: string;
    FCriadoEm: TDateTime;
    FAtualizadoEm: TDateTime;
  public
    [Key(True)]
    [Column('id')]
    property Id: Integer read FId write FId;

    [Column('nome')]
    property Nome: string read FNome write FNome;

    [Column('email')]
    property Email: string read FEmail write FEmail;

    [Column('cpf')]
    property Cpf: string read FCpf write FCpf;

    [Column('telefone')]
    property Telefone: string read FTelefone write FTelefone;

    [Column('data_nascimento')]
    property DataNascimento: TDateTime read FDataNascimento write FDataNascimento;

    [Column('limite_credito')]
    property LimiteCredito: Currency read FLimiteCredito write FLimiteCredito;

    [Column('ativo')]
    property Ativo: Boolean read FAtivo write FAtivo;

    [Column('observacao')]
    property Observacao: string read FObservacao write FObservacao;

    [Column('criado_em')]
    property CriadoEm: TDateTime read FCriadoEm write FCriadoEm;

    [Column('atualizado_em')]
    property AtualizadoEm: TDateTime read FAtualizadoEm write FAtualizadoEm;

  end;

implementation

end.
