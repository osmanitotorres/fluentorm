program Sample03;

{ ---------------------------------------------------------------------------
  FluentORM - Sample03: CRUD multi-banco (MySQL / SQL Server / PostgreSQL)

  Uso:
    Sample03.exe --db=mysql    --server=localhost --database=fluentorm_demo --user=root     --password=admin
    Sample03.exe --db=mssql    --server=localhost --database=fluentorm_demo --user=sa       --password=senha
    Sample03.exe --db=postgres --server=localhost --database=fluentorm_demo --user=postgres --password=admin

  Opcionais: --port=NNNN  --keep (nao apaga os registros)  --pause
             --provider=MSOLEDBSQL|SQLOLEDB  --encrypt=Yes   (somente SQL Server)

  MySQL e PostgreSQL usam FireDAC; SQL Server usa ADO (TADOSQLExecutor), pois o
  driver FireDAC.Phys.MSSQL so existe nas edicoes Enterprise/Architect.
  Antes de rodar, crie as tabelas com o script da pasta "scripts".
  --------------------------------------------------------------------------- }

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  FireDAC.Stan.Intf,
  FireDAC.Stan.Option,
  FireDAC.Stan.Error,
  FireDAC.UI.Intf,
  FireDAC.Phys.Intf,
  FireDAC.Stan.Def,
  FireDAC.Stan.Pool,
  FireDAC.Stan.Async,
  FireDAC.Phys,
  FireDAC.Phys.MySQL,
  FireDAC.Phys.PG,
  Winapi.ActiveX,
  FireDAC.DApt,
  FireDAC.ConsoleUI.Wait,
  FireDAC.Comp.Client,
  uFluentORM.Types in '..\..\uFluentORM.Types.pas',
  uFluentORM in '..\..\uFluentORM.pas',
  uFluentORM.Attributes in '..\..\uFluentORM.Attributes.pas',
  uFluentORM.Metadata in '..\..\uFluentORM.Metadata.pas',
  uFluentORM.Executor in '..\..\uFluentORM.Executor.pas',
  uFluentORM.Executor.FireDAC in '..\..\uFluentORM.Executor.FireDAC.pas',
  uFluentORM.Executor.ADO in '..\..\uFluentORM.Executor.ADO.pas',
  uFluentORM.ConnectionPool.FireDAC in '..\..\uFluentORM.ConnectionPool.FireDAC.pas',
  uFluentORM.Repository in '..\..\uFluentORM.Repository.pas',
  uSample03.Entities in 'uSample03.Entities.pas',
  uSample03.Demo in 'uSample03.Demo.pas';

begin
  ReportMemoryLeaksOnShutdown := True;
  CoInitialize(nil); // ADO (SQL Server) exige COM inicializado em apps console
  try
    try
      RunDemo;
    except
      on E: Exception do
      begin
        Writeln;
        Writeln('ERRO: ', E.ClassName, ': ', E.Message);
        ExitCode := 1;
      end;
    end;
  finally
    CoUninitialize;
  end;
  if FindCmdLineSwitch('pause') then
  begin
    Write('Pressione ENTER para sair...');
    Readln;
  end;
end.
