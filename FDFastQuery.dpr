program FDFastQuery;

uses
  Vcl.Forms,
  FastQuery in 'FastQuery.pas' {Form2},
  IFD.FastQuery in 'IFD.FastQuery.pas',
  ProjectFastQueryBridge in 'ProjectFastQueryBridge.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TForm2, Form2);
  Application.Run;
end.
