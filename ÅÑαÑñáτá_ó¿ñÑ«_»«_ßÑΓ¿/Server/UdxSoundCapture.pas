UNIT UdxSoundCapture;

{******************************************************************************}
{**  Захват звука                                                            **}
{**  Автор: Есенин Сергей Анатольевич                                        **}
{******************************************************************************}

{**} INTERFACE {***************************************************************}

{**} USES {********************************************************************}
  Windows, Classes, SysUtils, MMSystem, DirectSound, Dialogs;

{**} TYPE {********************************************************************}
  TdxSoundCapture = class
  PRIVATE
    FDirectSoundCapture: IDirectSoundCapture8;
    FHandle: THandle;
    
  PUBLIC
    constructor Create(AHandle: THandle);
    destructor Destroy; override;

    function Initialize: HRESULT;

    function StartCapture(WAVFile: string; CaptureTime: DWORD; Channels: WORD = 2;
      SamplesPerSec: DWORD = 11025; BitsPerSample: WORD = 16): HRESULT;
  END;

{**} IMPLEMENTATION {**********************************************************}

{** TdxSoundCapture ***********************************************************}

{******************************************************************************}
{**  Конструктор класса                                                      **}
{******************************************************************************}
constructor TdxSoundCapture.Create(AHandle: THandle);
begin
  // Запоминаем указатель на главную форму
  FHandle := AHandle;

  // Обнуляем ссылку на объект DirectSoundCapture
  FDirectSoundCapture := NIL;
end;

{******************************************************************************}
{**  Деструктор класса                                                       **}
{******************************************************************************}
destructor TdxSoundCapture.Destroy;
begin
  // Обнуляем ссылку на объект DirectSoundCapture
  FDirectSoundCapture := NIL;
end;

{******************************************************************************}
{**  Инициализация                                                           **}
{******************************************************************************}
function TdxSoundCapture.Initialize: HRESULT;
begin
  // Инициализируем подсистему захвата звука
  result := DirectSoundCaptureCreate8(NIL, FDirectSoundCapture, NIL);
end;

{******************************************************************************}
{**  Захват аудио                                                            **}
{******************************************************************************}
function TdxSoundCapture.StartCapture(WAVFile: string; CaptureTime: DWORD;
  Channels: WORD; SamplesPerSec: DWORD; BitsPerSample: WORD): HRESULT;
type
  // Структура, описывающая заголовок WAV-файла
  TWAVHeader = packed record
    wav_riff_id:   array[0..3] of char;
    wav_riff_len:  DWORD;

    wav_chuck_id:  array[0..3] of char;
    wav_fmt:       array[0..3] of char;
    wav_chuck_len: DWORD;

    wav_type:      WORD;
    wav_channels:  WORD;
    wav_freq:      DWORD;
    wav_bytes:     DWORD;
    wav_align:     WORD;
    wav_bits:      WORD;
     
    wav_data_id:   array[0..3] of char;
    wav_data_len:  DWORD;
  end;

var
  FCaptureBuffer: IDirectSoundCaptureBuffer;
  FCaptureNotify: IDirectSoundNotify8;
  dsbd:           TDSCBufferDesc;
  wfx:            TWaveFormatEx;
  wh:             TWAVHeader;
  pn:             TDSBPositionNotify;
  AudioPtr:       Pointer;
  AudioBytes:     DWORD;
  Data:           PByte;
  WAVReader:      TFileStream;

begin
  // Заполняем структуру, описывающую WAV-формат
  ZeroMemory(@wfx, sizeof(wfx));
  wfx.wFormatTag      := WAVE_FORMAT_PCM;
  wfx.nChannels       := Channels;
  wfx.nSamplesPerSec  := SamplesPerSec;
  wfx.wBitsPerSample  := BitsPerSample;
  wfx.nBlockAlign     := wfx.wBitsPerSample div 8 * wfx.nChannels;
  wfx.nAvgBytesPerSec := wfx.nSamplesPerSec * wfx.nBlockAlign;

  // Заполняем структуру, описывающую буфер захвата
  ZeroMemory(@dsbd, sizeof(dsbd));
  dsbd.dwSize        := sizeof(dsbd);
  dsbd.lpwfxFormat   := @wfx;
  dsbd.dwBufferBytes := dsbd.lpwfxFormat.nAvgBytesPerSec * CaptureTime;

  // Создаем буфер захвата
  result := FDirectSoundCapture.CreateCaptureBuffer(dsbd, FCaptureBuffer, NIL);
  if FAILED(result) then EXIT;

  // Получаем интерфейс уведомлений для буфера захвата
  result := FCaptureBuffer.QueryInterface(IID_IDirectSoundNotify8, FCaptureNotify);
  if FAILED(result) then EXIT;

  // Создаем событие для ожидания окончания записи
  pn.dwOffset := DSBPN_OFFSETSTOP;
  pn.hEventNotify := CreateEvent(NIL, FALSE, FALSE, NIL);

  // Устанавливаем позицию уведомления (как только будет достигнута данная
  // позиция, сразу сработает связанное с ним событие)
  FCaptureNotify.SetNotificationPositions(1, @pn);
  FCaptureNotify := NIL;

  // Начинаем захват аудио
  FCaptureBuffer.Start(0);

  // Дожидаемся окончания захвата
  WaitForSingleObject(pn.hEventNotify, INFINITE);

  // Удаляем событие
  CloseHandle(pn.hEventNotify);

  // Блокируем буфер и получаем указатель на заблокированный блок данных
  FCaptureBuffer.Lock(0, 0, @AudioPtr, @AudioBytes, NIL, NIL, DSCBLOCK_ENTIREBUFFER);

  // Заполняем заголовок WAV-файла
  wh.wav_align     := wfx.nBlockAlign;
  wh.wav_bits      := wfx.wBitsPerSample;
  wh.wav_bytes     := wfx.nAvgBytesPerSec;
  wh.wav_channels  := wfx.nChannels;
  wh.wav_chuck_id  := 'WAVE';
  wh.wav_chuck_len := 16;
  wh.wav_data_id   := 'data';
  wh.wav_data_len  := AudioBytes;
  wh.wav_fmt       := 'fmt ';
  wh.wav_freq      := wfx.nSamplesPerSec;
  wh.wav_riff_id   := 'RIFF';
  wh.wav_riff_len  := wh.wav_data_len + sizeof(wh);
  wh.wav_type      := wfx.wFormatTag;

  // Выделяем память под аудио-данные
  Data := GetMemory(AudioBytes);
  try
    // Копируем данные из буфера захвата
    CopyMemory(Data, AudioPtr, AudioBytes);
    
    // Разблокировка буфера
    FCaptureBuffer.Unlock(AudioPtr, AudioBytes, NIL, 0);

    // Создаем WAV-файл
    WAVReader := TFileStream.Create(WAVFile, fmCreate);
    try
      // Записываем в файл заголовок
      WAVReader.WriteBuffer(wh, sizeof(wh));

      // Записываем в файл аудио-данные
      WAVReader.WriteBuffer(Data^, AudioBytes);
    finally

      // Завершаем работу с WAV-файлом
      FreeAndNil(WAVReader);
    end;
  finally
    // Обнуляем буфер захвата
    FCaptureBuffer := NIL;

    // Освобождаем память, выделенную под аудио-данные
    FreeMemory(Data)
  end;

  result := S_OK;
end;

END.
