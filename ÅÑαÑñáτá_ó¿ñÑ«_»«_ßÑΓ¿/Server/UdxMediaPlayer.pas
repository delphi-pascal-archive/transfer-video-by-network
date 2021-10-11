UNIT UdxMediaPlayer;

{******************************************************************************}
{** Воспроизведение мультимедиа потоков посредством DirectShow               **}
{** Автор: Есенин Сергей Анатольевич                                         **}
{******************************************************************************}

{**} INTERFACE {***************************************************************}

{**} USES {********************************************************************}
  Windows, SysUtils, Graphics, ComObj, ActiveX, DirectShow9, Dialogs,
    Messages, Variants, Classes,  Controls, Forms,
 StdCtrls,  ExtCtrls, ComCtrls, ScktComp;
{**} TYPE {********************************************************************}
  TdxMediaPlayer = class
  PRIVATE
    FGraphBuilder:  IGraphBuilder;
    FMediaControl:  IMediaControl;
    FVideoWindow:   IVideoWindow;
    FBaseFilter:    IBaseFilter;
    FSampleGrabber: ISampleGrabber;
    FMediaSeeking:  IMediaSeeking;
    FBasicAudio:    IBasicAudio;
    FMediaEvent:    IMediaEventEx;

    FFileName:      WideString;
    FPlaying:       boolean;
    FHandle:        THandle;
    FFrameCount:    int64;

    FIsTimeFormat:  boolean;

    function CreateGraph: HResult;
    procedure ResetGraph;

  PUBLIC
    property FrameCount: int64 read FFrameCount;

    constructor Create(AHandle: THandle);
    destructor Destroy; override;

    function Initialize(AFileName: WideString): HResult;

    function  Play: HResult;
    procedure Stop;
    procedure Pause;

    function  StepPrev: HResult;
    function  StepNext: HResult;

    function  Faster: HResult;
    function  Slower: HResult;

    function GetVolume(out Value: Longint): HResult;
    function SetVolume(Value: Longint): HResult;

    function GetBalance(out Value: Longint): HResult;
    function SetBalance(Value: Longint): HResult;

    function SetWindowPosition(const R: TRect): HResult;
    
    function GetPlayingPosition(out P: int64): HResult;
    function SetPlayingPosition(P: int64): HResult;

    function CaptureBitmap(out ms:Tmemorystream): HResult;

    function RegisterEventMessage(AHandle: THandle; Msg: Cardinal): HResult;
    function GetEvent(out lEventCode: Longint; out lParam1, lParam2: Longint;
        msTimeout: DWORD): HResult;
  END;

{**} IMPLEMENTATION {**********************************************************}

{**} CONST {*******************************************************************}
  strVideoLoaded    = '!!! Видео загружено !!!';
  strVideoNotLoaded = '!!! Видео не загружено !!!';

  frameDuration     = 500000;

{**} { TdxMediaPlayer } {*****************************************************}

{******************************************************************************}
{** Конструктор класса                                                       **}
{******************************************************************************}
constructor TdxMediaPlayer.Create(AHandle: THandle);
begin
  // Запоминаем указатель на окно вывода видео
  FHandle := AHandle;

  // Очищаем граф
  ResetGraph;
end;

{******************************************************************************}
{** Деструктор класса                                                        **}
{******************************************************************************}
destructor TdxMediaPlayer.Destroy;
begin
  // Очищаем граф
  ResetGraph;
end;

{******************************************************************************}
{** Инициализация                                                            **}
{******************************************************************************}
function TdxMediaPlayer.Initialize(AFileName: WideString): HResult;
begin
  // Очищаем граф
  ResetGraph;

  // Запоминаем путь к файлу
  FFileName := AFileName;

  // Строим граф
  CreateGraph;          

  Result := S_OK;
end;

{******************************************************************************}
{** Построение графа                                                         **}
{******************************************************************************}
function TdxMediaPlayer.CreateGraph: HResult;
var
  MediaType: TAMMediaType;
begin
  // Результат по умолчанию
  Result := E_FAIL;

  // Если не задан путь к файлу, то завершаем работу
  if Trim(FFileName) = '' then EXIT;

  // Создаем объект для построения графа фильтров
  Result := CoCreateInstance(CLSID_FilterGraph, NIL, CLSCTX_INPROC_SERVER,
    IID_IGraphBuilder, FGraphBuilder);
  if FAILED(Result) then EXIT;

  // Создаем фильтр
  Result := CoCreateInstance(CLSID_SampleGrabber, NIL, CLSCTX_INPROC_SERVER,
    IID_IBaseFilter, FBaseFilter);
  if FAILED(Result) then EXIT;

  // Получаем интерфейс фильтра перехвата
  FBaseFilter.QueryInterface(IID_ISampleGrabber, FSampleGrabber);

  // Добавляем фильтр в граф
  Result := FGraphBuilder.AddFilter(FBaseFilter, 'GRABBER');
  if FAILED(Result) then EXIT;

  if FSampleGrabber <> NIL then
  begin
    // Устанавливаем формат данных для фильтра перехвата
    ZeroMemory(@MediaType, sizeof(TAMMediaType));

    with MediaType do
    begin
      majortype  := MEDIATYPE_Video;
      subtype    := MEDIASUBTYPE_RGB24;
      formattype := FORMAT_VideoInfo;
    end;

    Result := FSampleGrabber.SetMediaType(MediaType);
    if FAILED(Result) then EXIT;

    // Данные будут записаны в буфер в том виде, в котором они
    // проходят через фильтр
    FSampleGrabber.SetBufferSamples(TRUE);

    // Граф не будет остановлен для получения кадра
    FSampleGrabber.SetOneShot(FALSE);
  end;

  // Запрашиваем интерфейс управления графом фильтров
  FGraphBuilder.QueryInterface(IID_IMediaControl, FMediaControl);

  // Запрашиваем интерфейс управления окном вывода видео
  FGraphBuilder.QueryInterface(IID_IVideoWindow,  FVideoWindow);

  // Запрашиваем интерфейс управления позиционированием медиа потока
  FGraphBuilder.QueryInterface(IID_IMediaSeeking, FMediaSeeking);

  // Запрашиваем интерфейс управления звуковым потоком
  FGraphBuilder.QueryInterface(IID_IBasicAudio,   FBasicAudio);

  // Строим граф фильтров для нашего файла
  Result := FGraphBuilder.RenderFile(PWideChar(FFileName), nil);
  if FAILED(Result) then EXIT;

  // Проверка поддерживаемых форматов
  if (FMediaSeeking.IsFormatSupported(TIME_FORMAT_FRAME) = S_OK) then
  begin
    // Устанавливаем покадровый формат
    FMediaSeeking.SetTimeFormat(TIME_FORMAT_FRAME);

    // Получаем число кадров
    FMediaSeeking.GetDuration(FFrameCount);

    // Выводим сообщение на окне с видео
    SetWindowText(FHandle, PAnsiChar(strVideoLoaded));
    // Обновляем окно видео
    InvalidateRect(FHandle, NIL, FALSE);

    // Устанавливаем родительское окно для вывода изображения
    FVideoWindow.put_Owner(FHandle);
    // Устанавливаем стиль видео окна
    FVideoWindow.put_WindowStyle(WS_CHILD or WS_CLIPSIBLINGS);

    FIsTimeFormat := FALSE;
  end else if (FMediaSeeking.IsFormatSupported(TIME_FORMAT_MEDIA_TIME) = S_OK) then
  begin
    // Устанавливаем ссылочный временной формат (100 нс)
    FMediaSeeking.SetTimeFormat(TIME_FORMAT_MEDIA_TIME);

    // Получаем число интервалов
    FMediaSeeking.GetDuration(FFrameCount);
    // Сокращаем их количество для более удобной работы
    FFrameCount := FFrameCount div frameDuration;

    FIsTimeFormat := TRUE;
  end;
end;

{******************************************************************************}
{** Чистка графа - освобождаем память и обнуляем свойства                    **}
{******************************************************************************}
procedure TdxMediaPlayer.ResetGraph;
begin
  FBasicAudio    := NIL;
  FMediaEvent    := NIL;

  FPlaying       := FALSE;
  FFileName      := '';

  FMediaSeeking  := NIL;
  FSampleGrabber := NIL;
  FBaseFilter    := NIL;

  if FVideoWindow <> NIL then
  begin
    FVideoWindow.put_Visible(FALSE);
    FVideoWindow.put_Owner(0);
    FVideoWindow := NIL;
  end;

  FMediaControl  := NIL;
  FGraphBuilder  := NIL;

  SetWindowText(FHandle, PAnsiChar(strVideoNotLoaded));
  InvalidateRect(FHandle, NIL, FALSE);
end;

{******************************************************************************}
{** Запуск графа на воспроизведение                                          **}
{******************************************************************************}
function TdxMediaPlayer.Play: HResult;
begin
  // Результат по умолчанию
  Result := E_FAIL;

  // Если  отсутствует интерфейс управления, то завершаем работу
  if FMediaControl = NIL then EXIT;

  // Запускаем граф
  Result := FMediaControl.Run;
  
  FPlaying := SUCCEEDED(Result);
end;

{******************************************************************************}
{** Остановка воспроизведения и установка позиции на начало                  **}
{******************************************************************************}
procedure TdxMediaPlayer.Stop;
begin
  // Проверка наличия интерфейса управления и состояния графа
  if (FMediaControl = NIL) or not (FPlaying) then EXIT;

  // Останавливаем граф
  FMediaControl.Stop;

  // Устанавливаем позицию на начало
  SetPlayingPosition(0);

  FPlaying := FALSE;
end;

{******************************************************************************}
{** Приостанавливаем воспроизведение потока                                  **}
{******************************************************************************}
procedure TdxMediaPlayer.Pause;
begin
  // Если  отсутствует интерфейс управления, то завершаем работу
  if FMediaControl = NIL then EXIT;

  // Переводим граф в состояние "пауза"
  FMediaControl.Pause;
  
  FPlaying := FALSE;
end;

{******************************************************************************}
{** Шаг назад                                                                **}
{******************************************************************************}
function TdxMediaPlayer.StepPrev: HResult;
var
  P, S: int64;
begin
  // Результат по умолчанию
  Result := E_FAIL;

  // Если  отсутствует интерфейс позиционирования, то завершаем работу
  if FMediaSeeking = NIL then EXIT;

  // Устанавливаем позицию на шаг назад
  FMediaSeeking.GetPositions(P, S);
  dec(P);
  FMediaSeeking.SetPositions(P, AM_SEEKING_AbsolutePositioning, S, AM_SEEKING_NoPositioning);
end;

{******************************************************************************}
{** Шаг вперед                                                               **}
{******************************************************************************}
function TdxMediaPlayer.StepNext: HResult;
var
  P, S: int64;
begin
  // Результат по умолчанию
  Result := E_FAIL;

  // Если  отсутствует интерфейс позиционирования, то завершаем работу
  if FMediaSeeking = NIL then EXIT;

  // Устанавливаем позицию на шаг вперед
  FMediaSeeking.GetPositions(P, S);
  inc(P);
  FMediaSeeking.SetPositions(P, AM_SEEKING_AbsolutePositioning, S, AM_SEEKING_NoPositioning);
end;

{******************************************************************************}
{** Увеличиваем скорость воспроизведения                                     **}
{******************************************************************************}
function TdxMediaPlayer.Faster: HResult;
var
  Rate: double;
begin
  // Результат по умолчанию
  Result := E_FAIL;

  // Если  отсутствует интерфейс позиционирования, то завершаем работу
  if FMediaSeeking = NIL then EXIT;

  // Получаем текущую скорость воспроизведения ...
  if SUCCEEDED(FMediaSeeking.GetRate(Rate)) then
  begin
    // ... и увеличиваем ее в два раза
    Result := FMediaSeeking.SetRate(Rate * 2);
  end;
end;

{******************************************************************************}
{** Уменьшаем скорость воспроизведения                                       **}
{******************************************************************************}
function TdxMediaPlayer.Slower: HResult;
var
  Rate: double;
begin
  // Результат по умолчанию
  Result := E_FAIL;

  // Если  отсутствует интерфейс позиционирования, то завершаем работу
  if FMediaSeeking = NIL then EXIT;

  // Получаем текущую скорость воспроизведения ...
  if SUCCEEDED(FMediaSeeking.GetRate(Rate)) then
  begin
    // ... и уменьшаем ее в два раза
    Result := FMediaSeeking.SetRate(Rate / 2);
  end;
end; 

{******************************************************************************}
{** Получаем громкость                                                       **}
{******************************************************************************}
function TdxMediaPlayer.GetVolume(out Value: Integer): HResult;
begin
  // Результат по умолчанию
  Result := E_FAIL;

  // Если  отсутствует интерфейс управления звуком, то завершаем работу
  if FBasicAudio = NIL then EXIT;

  // Получаем громкость
  Result := FBasicAudio.get_Volume(Value);
end;

{******************************************************************************}
{** Устанавливаем громкость                                                  **}
{******************************************************************************}
function TdxMediaPlayer.SetVolume(Value: Integer): HResult;
begin
  // Результат по умолчанию
  Result := E_FAIL;

  // Если  отсутствует интерфейс управления звуком, то завершаем работу
  if FBasicAudio = NIL then EXIT;

  // Устанавливаем громкость
  Result := FBasicAudio.put_Volume(Value);
end;

{******************************************************************************}
{** Получаем уровень баланса аудио                                           **}
{******************************************************************************}
function TdxMediaPlayer.GetBalance(out Value: Integer): HResult;
begin
  // Результат по умолчанию
  Result := E_FAIL;

  // Если  отсутствует интерфейс управления звуком, то завершаем работу
  if FBasicAudio = NIL then EXIT;

  // Получаем уровень баланса аудио
  Result := FBasicAudio.get_Balance(Value);
end;

{******************************************************************************}
{** Устанавливаем уровень баланса аудио                                      **}
{******************************************************************************}
function TdxMediaPlayer.SetBalance(Value: Integer): HResult;
begin
  // Результат по умолчанию
  Result := E_FAIL;

  // Если  отсутствует интерфейс управления звуком, то завершаем работу
  if FBasicAudio = NIL then EXIT;

  // Устанавливаем уровень баланса аудио
  Result := FBasicAudio.put_Balance(Value);
end;

{******************************************************************************}
{** Задаем позицию окна воспроизведения видео                                **}
{******************************************************************************}
function TdxMediaPlayer.SetWindowPosition(const R: TRect): HResult;
begin
  // Результат по умолчанию
  Result := E_FAIL;

  // Если отсутствует интерфейс управления окном видео, то завершаем работу
  if (FVideoWindow = NIL) or (FIsTimeFormat) then EXIT;

  // Задаем позицию окна воспроизведения видео
  Result := FVideoWindow.SetWindowPosition(R.Left, R.Top,
    R.Right - R.Left, R.Bottom - R.Top);
end;

{******************************************************************************}
{** Получаем текущую позицию воспроизведения                                 **}
{******************************************************************************}
function TdxMediaPlayer.GetPlayingPosition(out P: int64): HResult;
begin
  // Результат по умолчанию
  Result := E_FAIL;

  // Если  отсутствует интерфейс позиционирования, то завершаем работу
  if FMediaSeeking = NIL then EXIT;

  // Получаем текущую позицию воспроизведения
  Result := FMediaSeeking.GetCurrentPosition(P);

  // Используем временной формат
  if FIsTimeFormat then P := P div frameDuration;
end;

{******************************************************************************}
{** Устанавливаем позицию воспроизведения                                    **}
{******************************************************************************}
function TdxMediaPlayer.SetPlayingPosition(P: int64): HResult;
var
  PS, S: int64;
begin
  // Результат по умолчанию
  Result := E_FAIL;

  // Если  отсутствует интерфейс позиционирования, то завершаем работу
  if FMediaSeeking = NIL then EXIT;

  // Получаем текущую позицию воспроизведения
  FMediaSeeking.GetPositions(PS, S);

  // Используем временной формат
  if FIsTimeFormat then P := P * frameDuration;

  // Устанавливаем позицию воспроизведения
  Result := FMediaSeeking.SetPositions(P, AM_SEEKING_AbsolutePositioning, S, AM_SEEKING_NoPositioning);
end;

{******************************************************************************}
{** Получаем кадр из видеопотока и сохраняем на диске                        **}
{******************************************************************************}
function TdxMediaPlayer.CaptureBitmap(out ms:Tmemorystream): HResult;
var
  bSize: integer;
  pVideoHeader: TVideoInfoHeader;
  MediaType: TAMMediaType;
  BitmapInfo: TBitmapInfo;
  Bitmap: TBitmap;
  Buffer: Pointer;
  tmp: array of byte;

begin
  // Результат по умолчанию
  Result := E_FAIL;

  // Если  отсутствует интерфейс фильтра перехвата изображения,
  // то завершаем работу
  if FSampleGrabber = NIL then EXIT;

  // Получаем размер кадра
  Result := FSampleGrabber.GetCurrentBuffer(bSize, NIL);
  if (bSize <= 0) or FAILED(Result) then EXIT;

  // Создаем изображение
  bitmap := TBitmap.Create;
  try
    // Получаем тип медиа потока на входе у фильтра перехвата
    ZeroMemory(@MediaType, sizeof(TAMMediaType));
    Result := FSampleGrabber.GetConnectedMediaType(MediaType);
    if FAILED(Result) then EXIT;

    // Копируем заголовок изображения
    pVideoHeader := TVideoInfoHeader(MediaType.pbFormat^);
    ZeroMemory(@BitmapInfo, sizeof(TBitmapInfo));
    CopyMemory(@BitmapInfo.bmiHeader, @pVideoHeader.bmiHeader, sizeof(TBITMAPINFOHEADER));
    
    Buffer := NIL;

    // Создаем побитовое изображение
    bitmap.Handle := CreateDIBSection(0, BitmapInfo, DIB_RGB_COLORS, Buffer, 0, 0);

    // Выделяем память во временном массиве
    SetLength(tmp, bSize);

    try
      // Читаем изображение из медиа потока во временный буфер
      FSampleGrabber.GetCurrentBuffer(bSize, @tmp[0]);
      
      // Копируем данные из временного буфера в наше изображение
      CopyMemory(Buffer, @tmp[0], MediaType.lSampleSize);

      MS := TMemoryStream.Create; // Создаём буфер для файла

      // Сохраняем изображение в файл
      Bitmap.SaveToStream(ms);
       ms.SaveToFile('c:\111.bmp');

    except

      // В случае сбоя возвращаем ошибочный результат
      Result := E_FAIL;
    end;
  finally
  
    // Освобождаем память
    SetLength(tmp, 0);
    FreeAndNil(Bitmap);
  end;
end;

{******************************************************************************}
{** Регистрация окна для обработки сообщения                                 **}
{******************************************************************************}
function TdxMediaPlayer.RegisterEventMessage(AHandle: THandle;
  Msg: Cardinal): HResult;
begin
  // Получение интерфейса управления сообщениями
  Result := FGraphBuilder.QueryInterface(IID_IMediaEventEx, FMediaEvent);

  // Назначаем окно обработки сообщения
  if SUCCEEDED(Result) then
    Result := FMediaEvent.SetNotifyWindow(AHandle, Msg, 0);
end;

{******************************************************************************}
{** Регистрация окна для обработки сообщения                                 **}
{******************************************************************************}
function TdxMediaPlayer.GetEvent(out lEventCode, lParam1,
  lParam2: Integer; msTimeout: DWORD): HResult;
begin
  // Результат по умолчанию
  Result := E_FAIL;
  
  // Если отсутствует интерфейс управления сообщениями, то завершаем работу
  if FMediaEvent = NIL then EXIT;

  // Считываем сообщение из очереди
  if SUCCEEDED(FMediaEvent.GetEvent(lEventCode, lParam1, lParam2, msTimeout)) then
  begin
    // Освобождаем ресурсы, связанные с событием
    Result := FMediaEvent.FreeEventParams(lEventCode, lParam1, lParam2);
  end;
end;

END.
