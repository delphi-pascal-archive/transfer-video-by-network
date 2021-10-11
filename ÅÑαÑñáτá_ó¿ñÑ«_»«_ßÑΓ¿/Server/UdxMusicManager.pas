UNIT UdxMusicManager;

{******************************************************************************}
{**  Работа с файлами формата MIDI и WAV посредством DirectMusic             **}
{**  Автор: Есенин Сергей Анатольевич                                        **}
{******************************************************************************}

{**} INTERFACE {***************************************************************}

{**} USES {********************************************************************}
  Windows, Classes, SysUtils, MMSystem, DirectMusic, ComObj, ActiveX;

{**} TYPE {********************************************************************}
  TdxMusicSegment = class;

  TdxMusicManager = class
  PRIVATE
    FPerformance: IDirectMusicPerformance8;
    FLoader: IDirectMusicLoader8;

    FSegmentList: TList;

    FHandle: THandle; 

  PUBLIC
    constructor Create(Handle: THandle);
    destructor Destroy; override;

    function Initialize: HResult;

    function CreateSegment(FileName: WideString): TdxMusicSegment;
    function DeleteSegment(Index: integer): HResult; overload;
    function DeleteSegment(Segment: TdxMusicSegment): HResult; overload;
    function GetSegment(Index: integer): TdxMusicSegment;
    function SegmentCount: integer;
  END;

  TdxMusicSegment = class
  PRIVATE
    FPerformance: IDirectMusicPerformance8;
    FLoader: IDirectMusicLoader8;
    FSegment: IDirectMusicSegment8;

  PUBLIC
    constructor Create(APerformance: IDirectMusicPerformance8;
      ALoader: IDirectMusicLoader8; ASegment: IDirectMusicSegment8);
    destructor Destroy; override;

    function SetRepeats(dwRepeats: DWORD = DMUS_SEG_REPEAT_INFINITE): HResult;

    function Play(IsPrimary: boolean = FALSE): HResult;
    function Stop: HResult;

    function IsPlaying: boolean;
  END;

{**} IMPLEMENTATION {**********************************************************}

{**} { TdxMusicManager } {*****************************************************}

{******************************************************************************}
{**  Конструктор класса                                                      **}
{******************************************************************************}
constructor TdxMusicManager.Create(Handle: THandle);
begin
  // Инициализация библиотеки COM
  CoInitializeEx(NIL, COINIT_MULTITHREADED);

  // Обнуление ссылок на менеджер воспроизведения и загрузчик
  FPerformance := NIL;
  FLoader := NIL;

  // Запоминаем указатель на главную форму
  FHandle := Handle;

  // Создаем контейнер сегментов воспроизведения
  FSegmentList := TList.Create;
end;

{******************************************************************************}
{**  Создаем сегмент воспроизведения                                         **}
{******************************************************************************}
function TdxMusicManager.CreateSegment(FileName: WideString): TdxMusicSegment;
var
  FSegment: IDirectMusicSegment8;
begin
  // Обнуляем ссылку на сегмент
  FSegment := NIL;

  // Результат по умолчанию
  Result := NIL;
  
  // Проверка наличия менеджера воспроизведения и загрузчика
  if (FPerformance = NIL) or (FLoader = NIL) then EXIT;

  // Загружаем аудио данные и получаем указатель на сегмент
  if FAILED(FLoader.LoadObjectFromFile(CLSID_DirectMusicSegment,
    IID_IDirectMusicSegment8, PWideChar(FileName),
    FSegment)) then EXIT;

  // Загружаем данные в менеджер
  if FAILED(FSegment.Download(FPerformance)) then EXIT;

  // Создаем объект, инкапсулирующий сегмент воспроизведения
  Result := TdxMusicSegment.Create(FPerformance, FLoader, FSegment);

  // Добавляем объект в контейнер
  if Result <> NIL then
     FSegmentList.Add(Result);
end;

{******************************************************************************}
{**  Удаляем сегмент воспроизведения по индексу                              **}
{******************************************************************************}
function TdxMusicManager.DeleteSegment(Index: integer): HResult;
begin
  // Результат по умолчанию
  Result := E_FAIL;

  // Если индекс неверный, то завершаем работу
  if (Index < 0) or (Index >= FSegmentList.Count) then EXIT;

  // Останавливаем воспроизведение сегмета
  TdxMusicSegment(FSegmentList.Items[Index]).Stop;

  // Освобождаем память, выделенную под сегмент
  TdxMusicSegment(FSegmentList.Items[Index]).Free;
  FSegmentList.Items[Index] := NIL;

  // Удаляем ссылку на сегмент из контейнера
  FSegmentList.Delete(Index);

  Result := S_OK;
end;

{******************************************************************************}
{**  Удаляем сегмент воспроизведения по ссылке                               **}
{******************************************************************************}
function TdxMusicManager.DeleteSegment(Segment: TdxMusicSegment): HResult;
begin
  // Результат по умолчанию 
  Result := E_FAIL;

  // Проверка сегмента
  if (Segment = NIL) or (FSegmentList.IndexOf(Segment) < 0) then EXIT;

  // Останавливаем воспроизведение сегмета
  Segment.Stop;

  // Удаляем ссылку на сегмент из контейнера
  FSegmentList.Remove(Segment);

  // Освобождаем память, выделенную под сегмент
  FreeAndNil(Segment);
end;

{******************************************************************************}
{**  Деструктор класса                                                       **}
{******************************************************************************}
destructor TdxMusicManager.Destroy;
var
  I: integer;
begin
  // Останавливаем работу менеджера воспроизведения
  if FPerformance <> NIL then
     FPerformance.Stop(NIL, NIL, 0, 0);

  // Очищаем контейнер сегментов
  if FSegmentList <> NIL then
  begin
    for I := 0 to FSegmentList.Count - 1 do
    begin
      TdxMusicSegment(FSegmentList.Items[I]).Stop;
      TdxMusicSegment(FSegmentList.Items[I]).Free;
      FSegmentList.Items[I] := NIL;
    end;

    FreeAndNil(FSegmentList);
  end;

  // Обнуление ссылок на загрузчик и менеджер воспроизведения
  FLoader := NIL;
  FPerformance := NIL;

  // Завершение работы с COM
  CoUninitialize;
end;

{******************************************************************************}
{**  Получение сегмента по индексу                                           **}
{******************************************************************************}
function TdxMusicManager.GetSegment(Index: integer): TdxMusicSegment;
begin
  // Результат по умолчанию
  Result := NIL;

  // Если индекс неверный, то завершаем работу
  if (Index < 0) or (Index >= FSegmentList.Count) then EXIT;

  // Получаем сегент по индексу из контейнера
  Result := FSegmentList.Items[Index];
end;

{******************************************************************************}
{**  Инициализация музыкального менеджера                                    **}
{******************************************************************************}
function TdxMusicManager.Initialize: HResult;
begin
  // Создаем загрузчик
  Result := CoCreateInstance(CLSID_DirectMusicLoader, NIL, CLSCTX_INPROC,
    IID_IDirectMusicLoader8, FLoader);
  if FAILED(Result) then EXIT;

  // Создаем менеджер воспроизведения
  Result := CoCreateInstance(CLSID_DirectMusicPerformance, NIL, CLSCTX_INPROC,
    IID_IDirectMusicPerformance8, FPerformance);
  if FAILED(Result) then EXIT;

  // Инициализируем менеджер воспроизведения
  Result := FPerformance.InitAudio(NIL, NIL, FHandle, DMUS_APATH_DYNAMIC_STEREO,
    128, DMUS_AUDIOF_ALL, NIL);
end;

{******************************************************************************}
{**  Получение числа сегментов                                               **}
{******************************************************************************}
function TdxMusicManager.SegmentCount: integer;
begin
  Result := FSegmentList.Count;
end;

{**} { TdxMusicSegment } {*****************************************************}

{******************************************************************************}
{**  Конструктор класса                                                      **}
{******************************************************************************}
constructor TdxMusicSegment.Create(APerformance: IDirectMusicPerformance8;
  ALoader: IDirectMusicLoader8; ASegment: IDirectMusicSegment8);
begin
  // Запоминаем менеджер воспроизведения
  FPerformance := APerformance;

  // Запоминаем загрузчик
  FLoader := ALoader;

  // Запоминаем сегмент воспроизведения 
  FSegment := ASegment;
end;

{******************************************************************************}
{**  Деструктор класса                                                       **}
{******************************************************************************}
destructor TdxMusicSegment.Destroy;
begin
  // Проверяем наличие сегмента
  if FSegment <> NIL then
  begin
    // Выгружаем данные из сегмента
    FSegment.Unload(FPerformance);

    // Обнуляем сегмент воспроизведения
    FSegment := NIL;
  end;
end;

{******************************************************************************}
{**  Состояние воспроизведения сегмента                                      **}
{******************************************************************************}
function TdxMusicSegment.IsPlaying: boolean;
begin
  Result := (FPerformance.IsPlaying(FSegment, NIL) = S_OK);
end;

{******************************************************************************}
{**  Воспроизвести сегмент                                                   **}
{******************************************************************************}
function TdxMusicSegment.Play(IsPrimary: boolean): HResult;
begin
  // Результат по умолчанию
  Result := E_FAIL;
  
  // Проверка наличия менеджера воспроизведения
  if FPerformance = NIL then EXIT;

  if IsPrimary then
    // Воспроизводим основной сегмент
    Result := FPerformance.PlaySegmentEx(FSegment, NIL, NIL, 0,
      0, NIL, NIL, NIL)
  else
    // Воспроизводим вторичный сегмент
    Result := FPerformance.PlaySegmentEx(FSegment, NIL, NIL, DMUS_SEGF_SECONDARY,
      0, NIL, NIL, NIL); 
end;

{******************************************************************************}
{**  Установка числа циклов воспроизведения                                  **}
{******************************************************************************}
function TdxMusicSegment.SetRepeats(dwRepeats: DWORD): HResult;
begin
  // Результат по умолчанию
  Result := E_FAIL;
  
  // Проверка наличия сегмента
  if FSegment = NIL then EXIT;

  // Устанавливаем число циклов воспроизведения
  Result := FSegment.SetRepeats(dwRepeats);
end;

{******************************************************************************}
{**  Остановка воспроизведения сегмента                                      **}
{******************************************************************************}
function TdxMusicSegment.Stop: HResult;
begin
  // Результат по умолчанию
  Result := E_FAIL;
  
  // Проверка наличия менеджера воспроизведения
  if FPerformance = NIL then EXIT;

  // Останавливаем воспроизведение сегмента
  Result := FPerformance.StopEx(FSegment, 0, 0);
end;

END.
