program Sample02;

uses
  Vcl.Forms,
  unMain in 'unMain.pas' {frmMain},
  uFluentORM in '..\..\uFluentORM.pas';

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TfrmMain, frmMain);
  Application.Run;
end.
