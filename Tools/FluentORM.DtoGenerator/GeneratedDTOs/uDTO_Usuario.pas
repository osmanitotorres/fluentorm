// ------------------------------------------------------------------
// Classe gerada automaticamente pelo FluentORM DTO Generator
// Data: 25/02/2026
// Ajuste manualmente conforme necessario.
// ------------------------------------------------------------------

unit uDTO_Usuario;

interface

uses
  uFluentORM.Attributes;

type
  [Table('usuario')]
  TUsuarioDTO = class
  private
    FId: Integer;
    FNome: string;
    FPass: string;
    FDataCriacao: TDateTime;
  public
    [Key(True)]
    [Column('id')]
    property Id: Integer read FId write FId;

    [Column('nome')]
    property Nome: string read FNome write FNome;

    [Column('pass')]
    property Pass: string read FPass write FPass;

    [ReadOnly]
    [Column('data_criacao')]
    property DataCriacao: TDateTime read FDataCriacao write FDataCriacao;

  end;

implementation

end.
