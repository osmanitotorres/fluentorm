program Sample01;

uses
  Vcl.Forms,
  unMain in 'unMain.pas' {Form1},
  uFluentORM in '..\uFluentORM.pas',
  uFluentORM.Attributes in '..\uFluentORM.Attributes.pas',
  uFluentORM.Executor.FireDAC in '..\uFluentORM.Executor.FireDAC.pas',
  uFluentORM.Executor in '..\uFluentORM.Executor.pas',
  uFluentORM.Metadata in '..\uFluentORM.Metadata.pas',
  uFluentORM.Repository in '..\uFluentORM.Repository.pas',
  uFluentORM.Types in '..\uFluentORM.Types.pas',
  uFluentORM.ConnectionPool.FireDAC in '..\uFluentORM.ConnectionPool.FireDAC.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TForm1, Form1);
  Application.Run;
end.
