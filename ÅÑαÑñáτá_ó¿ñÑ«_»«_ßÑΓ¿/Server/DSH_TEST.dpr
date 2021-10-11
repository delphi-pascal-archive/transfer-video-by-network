program DSH_Test;

uses
  Forms,
  FormMain in 'FormMain.pas' {MainForm};

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TMainForm, MainForm);
  Application.Run;
end.
