program Sample04;

{ FluentORM - Sample04: cadastro de clientes (VCL + FireDAC + MySQL).
  Compile em Win64 para usar a libmysql.dll 64 bits do MySQL Server. }

uses
  Vcl.Forms,
  uFluentORM.Types in '..\..\uFluentORM.Types.pas',
  uFluentORM in '..\..\uFluentORM.pas',
  uFluentORM.Attributes in '..\..\uFluentORM.Attributes.pas',
  uFluentORM.Metadata in '..\..\uFluentORM.Metadata.pas',
  uFluentORM.Executor in '..\..\uFluentORM.Executor.pas',
  uFluentORM.Executor.FireDAC in '..\..\uFluentORM.Executor.FireDAC.pas',
  uFluentORM.Repository in '..\..\uFluentORM.Repository.pas',
  uSample04.Model in 'uSample04.Model.pas',
  uFrmClientes in 'uFrmClientes.pas' {frmClientes};

begin
  ReportMemoryLeaksOnShutdown := True;
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.Title := 'FluentORM - Clientes (MySQL)';
  Application.CreateForm(TfrmClientes, frmClientes);
  Application.Run;
end.
