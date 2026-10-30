program Sample02;

uses
  Vcl.Forms,
  unMain in 'unMain.pas' {frmMain},
  uFluentORM in '..\..\uFluentORM.pas',
  uFluentORM.Types in '..\..\uFluentORM.Types.pas',
  uFluentORM.Attributes in '..\..\uFluentORM.Attributes.pas',
  uFluentORM.Metadata in '..\..\uFluentORM.Metadata.pas',
  uFluentORM.Executor in '..\..\uFluentORM.Executor.pas',
  uFluentORM.Executor.FireDAC in '..\..\uFluentORM.Executor.FireDAC.pas',
  uFluentORM.Repository in '..\..\uFluentORM.Repository.pas',
  uFluentORM.ConnectionPool.FireDAC in '..\..\uFluentORM.ConnectionPool.FireDAC.pas';

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TfrmMain, frmMain);
  Application.Run;
end.
