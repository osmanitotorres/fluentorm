program FluentORMDtoGenerator;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  uGenerator.Main in 'uGenerator.Main.pas';

begin
  ReportMemoryLeaksOnShutdown := True;
  try
    RunGenerator;
  except
    on E: Exception do
    begin
      Writeln('Error: ' + E.Message);
      ExitCode := 1;
    end;
  end;
end.

