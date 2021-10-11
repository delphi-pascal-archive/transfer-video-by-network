unit Unit1;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, ComCtrls, ScktComp, StdCtrls, ExtCtrls;

type
  TForm1 = class(TForm)
    Label1: TLabel;
    Label2: TLabel;
    ClientSocket1: TClientSocket;
    ProgressBar1: TProgressBar;
    StatusBar1: TStatusBar;
    Image1: TImage;
     procedure Writing(Text: string);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure ClientSocket1Connect(Sender: TObject;
      Socket: TCustomWinSocket);
    procedure ClientSocket1Disconnect(Sender: TObject;
      Socket: TCustomWinSocket);
    procedure ClientSocket1Read(Sender: TObject; Socket: TCustomWinSocket); // ��������� ������ � ������ � �����
  private
  { Private declarations }
Name: string; // ��� �����
Size: integer; // ������ �����
Receive: boolean; // ����� �������
MS: TMemoryStream; // ����� ��� �����
    { Private declarations }
  public
    { Public declarations }
  end;

var
  Form1: TForm1;

implementation

{$R *.dfm}

procedure TForm1.FormCreate(Sender: TObject);
begin
ClientSocket1.Open; // ��������� �����
Receive := false; // ����� ������� - ���� ������
end;

procedure TForm1.FormDestroy(Sender: TObject);
begin
ClientSocket1.Close; // ��������� �����
end;

procedure TForm1.ClientSocket1Connect(Sender: TObject;
  Socket: TCustomWinSocket);
begin
StatusBar1.SimpleText := '���������� �����������';
end;

procedure TForm1.ClientSocket1Disconnect(Sender: TObject;
  Socket: TCustomWinSocket);
begin
StatusBar1.SimpleText := '���������� �� �����������';
end;


procedure TForm1.Writing(Text: string);
begin
if MS.Size < Size then // ���� ������� ���� ������ ������� �����, ��...
MS.Write(Text[1], Length(Text)); // ���������� � �����
// ������� �������� ������� �����
ProgressBar1.Position := MS.Size*100 div Size;
StatusBar1.SimpleText := '������� '+IntToStr(MS.Size)+' �� '+IntToStr(Size);
if MS.Size = Size then // ���� ���� ������, ��...
begin
Receive := false; // ��������� ������� � ���������� �����
MS.Position := 0; // ��������� ������� � ������ ������

image1.Picture.Bitmap.LoadFromStream(ms);
ClientSocket1.Socket.SendText('end'); // �������� ������� "end", �� ���� ���� ������
MS.Free; // ������� �����
StatusBar1.SimpleText := '���� ������';
end;
end;

procedure TForm1.ClientSocket1Read(Sender: TObject;
  Socket: TCustomWinSocket);
  var
Rtext: string; // �������� �����
begin
Rtext := Socket.ReceiveText;
if Receive then // ���� ������ � ������ ����� �����, ��...
Writing(RText) // ���������� ������ � �����
else // ���� ������ �� � ������ ����� �����, ��...
if Copy(Rtext, 0, Pos('#', Rtext) -1) = 'file' then // ���� ��� ����, ��...
begin MS := TMemoryStream.Create; // ������ ����� ��� �����
Delete(Rtext, 1, Pos('#', Rtext)); // ���������� ��� �����
Name := Copy(Rtext, 0, Pos('#', Rtext) -1); // ���������� ��� �����
Delete(Rtext, 1, Pos('#', Rtext)); // ���������� ������ �����
Size := StrToInt(Copy(Rtext, 0, Pos('#', Rtext) -1)); // ���������� ������ �����
Delete(Rtext, 1, Pos('#', Rtext)); // ������� ��������� �����������
Label1.Caption := '������ �����: '+IntToStr(Size)+' ����'; // ������� ������ �����
Label2.Caption := '��� �����: '+Name; // ������� ��� �����
Receive := true; // ��������� ������ � ����� ����� �����
Writing(RText); // ���������� ������ � �����
end;
end;

end.
