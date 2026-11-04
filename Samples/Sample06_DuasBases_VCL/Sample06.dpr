program Sample06;

{ FluentORM - Sample06: duas bases de dados ao mesmo tempo (MySQL e/ou
  PostgreSQL), escolhidas na tela. Compile em Win64. }

uses
  Vcl.Forms,
  uFluentORM.Types in '..\..\uFluentORM.Types.pas',
  uFluentORM in '..\..\uFluentORM.pas',
  uFluentORM.Attributes in '..\..\uFluentORM.Attributes.pas',
  uFluentORM.Metadata in '..\..\uFluentORM.Metadata.pas',
  uFluentORM.Executor in '..\..\uFluentORM.Executor.pas',
  uFluentORM.Executor.FireDAC in '..\..\uFluentORM.Executor.FireDAC.pas',
  uFluentORM.Repository in '..\..\uFluentORM.Repository.pas',
  uSample06.Model in 'uSample06.Model.pas',
  uFraBase in 'uFraBase.pas' {fraBase: TFrame},
  uFrmPrincipal in 'uFrmPrincipal.pas' {frmPrincipal};

begin
  ReportMemoryLeaksOnShutdown := True;
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.Title := 'FluentORM - Duas bases';
  Application.CreateForm(TfrmPrincipal, frmPrincipal);
  Application.Run;
end.
