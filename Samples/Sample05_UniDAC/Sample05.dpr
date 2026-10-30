program Sample05;

{ ---------------------------------------------------------------------------
  FluentORM - Sample05: usando o UniDAC (Devart) como camada de acesso.

  REQUER o UniDAC instalado. Por isso este projeto NAO faz parte do build.bat.

  Uso:
    Sample05.exe --db=mysql    --server=localhost --database=fluentorm_demo --user=root --password=...
    Sample05.exe --db=mssql    --server=localhost --database=fluentorm_demo --user=sa   --password=...
    Sample05.exe --db=postgres --server=localhost --database=fluentorm_demo --user=postgres --password=...

  Opcionais:
    --port=N            porta (padrao do banco)
    --mode=component    usa uma TUniConnection criada pela aplicacao
                        (padrao: --mode=executor, o executor cria a conexao)
    --keep              nao apaga os registros criados
    --pause             espera ENTER no final

  As tabelas sao as mesmas do Sample03:
    ..\Sample03_MultiBanco\scripts\mysql.sql | mssql.sql | postgresql.sql
  --------------------------------------------------------------------------- }

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  // ---- UniDAC: nucleo + um provider por banco usado -----------------------
  // Sem o provider correspondente o UniDAC gera "Provider is not defined".
  // Remova os que nao for usar (cada provider aumenta o executavel).
  Uni,
  MySQLUniProvider,
  SQLServerUniProvider,
  PostgreSQLUniProvider,
  // ---- FluentORM ------------------------------------------------------------
  uFluentORM.Types in '..\..\uFluentORM.Types.pas',
  uFluentORM in '..\..\uFluentORM.pas',
  uFluentORM.Attributes in '..\..\uFluentORM.Attributes.pas',
  uFluentORM.Metadata in '..\..\uFluentORM.Metadata.pas',
  uFluentORM.Executor in '..\..\uFluentORM.Executor.pas',
  uFluentORM.Executor.UniDAC in '..\..\uFluentORM.Executor.UniDAC.pas',
  uFluentORM.Repository in '..\..\uFluentORM.Repository.pas',
  // ---- Exemplo -------------------------------------------------------------
  uSample03.Entities in '..\Sample03_MultiBanco\uSample03.Entities.pas',
  uSample05.Demo in 'uSample05.Demo.pas';

begin
  ReportMemoryLeaksOnShutdown := True;
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
  if FindCmdLineSwitch('pause') then
  begin
    Write('Pressione ENTER para sair...');
    Readln;
  end;
end.
