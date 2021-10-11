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
    procedure ClientSocket1Read(Sender: TObject; Socket: TCustomWinSocket); // Процедура записи в данных в буфер
  private
  { Private declarations }
Name: string; // Имя файла
Size: integer; // Размер файла
Receive: boolean; // Режим клиента
MS: TMemoryStream; // Буфер для файла
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
ClientSocket1.Open; // Открываем сокет
Receive := false; // Режим клиента - приём команд
end;

procedure TForm1.FormDestroy(Sender: TObject);
begin
ClientSocket1.Close; // Закрываем сокет
end;

procedure TForm1.ClientSocket1Connect(Sender: TObject;
  Socket: TCustomWinSocket);
begin
StatusBar1.SimpleText := 'Соединение установлено';
end;

procedure TForm1.ClientSocket1Disconnect(Sender: TObject;
  Socket: TCustomWinSocket);
begin
StatusBar1.SimpleText := 'Соединение не установлено';
end;


procedure TForm1.Writing(Text: string);
begin
if MS.Size < Size then // Если принято байт меньше размера файла, то...
MS.Write(Text[1], Length(Text)); // Записываем в буфер
// Выводим прогресс закачки файла
ProgressBar1.Position := MS.Size*100 div Size;
StatusBar1.SimpleText := 'Принято '+IntToStr(MS.Size)+' из '+IntToStr(Size);
if MS.Size = Size then // Если файл принят, то...
begin
Receive := false; // Переводим клиента в нормальный режим
MS.Position := 0; // Переводим каретку в начало буфера

image1.Picture.Bitmap.LoadFromStream(ms);
ClientSocket1.Socket.SendText('end'); // Посылаем команду "end", то есть файл принят
MS.Free; // Убиваем буфер
StatusBar1.SimpleText := 'Файл принят';
end;
end;

procedure TForm1.ClientSocket1Read(Sender: TObject;
  Socket: TCustomWinSocket);
  var
Rtext: string; // Принятый текст
begin
Rtext := Socket.ReceiveText;
if Receive then // Если клиент в режиме приёма файла, то...
Writing(RText) // Записываем данные в буфер
else // Если клиент не в режиме приёма файла, то...
if Copy(Rtext, 0, Pos('#', Rtext) -1) = 'file' then // Если это файл, то...
begin MS := TMemoryStream.Create; // Создаём буфер для файла
Delete(Rtext, 1, Pos('#', Rtext)); // Определяем имя файла
Name := Copy(Rtext, 0, Pos('#', Rtext) -1); // Определяем имя файла
Delete(Rtext, 1, Pos('#', Rtext)); // Определяем размер файла
Size := StrToInt(Copy(Rtext, 0, Pos('#', Rtext) -1)); // Определяем размер файла
Delete(Rtext, 1, Pos('#', Rtext)); // Удаляем последний разделитель
Label1.Caption := 'Размер файла: '+IntToStr(Size)+' байт'; // Выводим размер файла
Label2.Caption := 'Имя файла: '+Name; // Выводим имя файла
Receive := true; // Переводим сервер в режим приёма файла
Writing(RText); // Записываем данные в буфер
end;
end;

end.
