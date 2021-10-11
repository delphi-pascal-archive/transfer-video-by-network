UNIT UdxSoundManager;

{******************************************************************************}
{**  Работа с файлами формата WAV - загрузка и воспроизведение               **}
{**  Автор: Есенин Сергей Анатольевич                                        **}
{******************************************************************************}

{**} INTERFACE {***************************************************************}

{**} USES {********************************************************************}
  Windows, Classes, SysUtils, MMSystem, DirectSound, Dialogs, ComObj,
  Math, ActiveX;

{**} CONST {*******************************************************************}
  SFX_COUNT = 8;

  SFX_STANDARD_CHORUS           = $000000001;
  SFX_STANDARD_COMPRESSOR       = $000000002;
  SFX_STANDARD_DISTORTION       = $000000004;
  SFX_STANDARD_ECHO             = $000000008;
  SFX_STANDARD_FLANGER          = $000000010;
  SFX_STANDARD_GARGLE           = $000000020;
  SFX_STANDARD_PARAMEQ          = $000000040;
  SFX_WAVES_REVERB              = $000000080;

{**} TYPE {********************************************************************}
  TdxSound = class
  PRIVATE
    FdsBuffer8:   IDirectSoundBuffer8;
    FData:        PByte;
    FWAVFileName: string;
    FDataSize:    integer;

    FdsChorus8:     IDirectSoundFXChorus8;
    FdsCompressor8: IDirectSoundFXCompressor8;
    FdsDistortion8: IDirectSoundFXDistortion8;
    FdsEcho8:       IDirectSoundFXEcho8;
    FdsFlanger8:    IDirectSoundFXFlanger8;
    FdsGargle8:     IDirectSoundFXGargle8;
    FdsParamEq8:    IDirectSoundFXParamEq8;
    FdsReverb8:     IDirectSoundFXWavesReverb8;

    FParamsChorus:     TDSFXChorus;
    FParamsCompressor: TDSFXCompressor;
    FParamsDistortion: TDSFXDistortion;
    FParamsEcho:       TDSFXEcho;
    FParamsFlanger:    TDSFXFlanger;
    FParamsGargle:     TDSFXGargle;
    FParamsParamEq:    TDSFXParamEq;
    FParamsReverb:     TDSFXWavesReverb;

    dwResults:    array[0..SFX_COUNT - 1] of DWORD;
    dsEffect:     array[0..SFX_COUNT - 1] of TDSEffectDesc;

    function LoadWAVFile(wfx: PWaveFormatEx; dwSize: PDWORD): PByte;
    function FillBuffer: HResult;

    function RestoreBuffer(WasRestored: PBOOL): HResult;

    function GetEffectGuid(Effect: WORD): TGUID;

  PUBLIC
    constructor Create(DirectSound8: IDirectSound8; WAVFileName: string);
    destructor Destroy; override;

    function PlaySound(Looping: boolean = false): HResult;
    function StopSound(): HResult;

    function SetFrequency(Frequency: Cardinal): HResult;
    function SetPan(Pan: integer): HResult;
    function SetVolume(Volume: integer): HResult;

    function GetFrequency(var Frequency: Cardinal): HResult;
    function GetPan(var Pan: integer): HResult;
    function GetVolume(var Volume: integer): HResult;

    function SetEffects(EffectsMask: DWORD): HResult;
    function GetEffects(var EffectsMask: DWORD): HResult;

    function SetEffectParams(Effect: DWORD; const Params: pointer): HResult;
    function GetEffectParams(Effect: DWORD; Params: pointer): HResult;
  END;

  TdxSoundManager = class
  PRIVATE
    FDirectSound: IDirectSound8;

    FHandle: THandle;
    FSounds: TList;

  PUBLIC
    constructor Create(AHandle: THandle);
    destructor Destroy; override;

    function Initialize: HResult;

    function SoundCount: integer;

    function CreateSound(WAVFileName: string): HResult;
    function DeleteSound(Index: integer): HResult;

    function GetSound(Index: integer): TdxSound;
  END;

{**} IMPLEMENTATION

{** TdxSoundManager ***********************************************************}

{******************************************************************************}
{**  Конструктор класса                                                      **}
{******************************************************************************}
constructor TdxSoundManager.Create(AHandle: THandle);
begin
  // Инициализация подсистемы COM
  CoInitializeEx(NIL, COINIT_MULTITHREADED);

  // Запоминаем указатель на главную форму
  FHandle := AHandle;

  // Создаем контейнер вторичных буферов
  FSounds := TList.Create;

  // Обнуляем ссылку на объект DirectSound
  FDirectSound := NIL;
end;

{******************************************************************************}
{**  Деструктор класса                                                       **}
{******************************************************************************}
destructor TdxSoundManager.Destroy;
var
  I: integer;
begin
  if FSounds <> NIL then
  begin
    // Обнуляем все ссылки на вторичные буферы
    for I := 0 to FSounds.Count - 1 do
    begin
      if FSounds[I] <> NIL then
      begin
        TdxSound(FSounds[I]).Free;
        FSounds[I] := NIL;
      end;
    end;

    // Чистим и уничтожаем контейнер вторичных буферов
    FSounds.Clear;
    FreeAndNil(FSounds);
  end;

  // Обнуляем ссылку на объект DirectSound
  FDirectSound := NIL;

  // Завершаем работу с COM
  CoUninitialize;
end;

{******************************************************************************}
{**  Инициализация подсистемы                                                **}
{******************************************************************************}
function TdxSoundManager.Initialize: HResult;
begin
  // Инициализируем подсистему DirectSound
  result := DirectSoundCreate8(NIL, FDirectSound, NIL);
  if FAILED(result) then EXIT;

  // Устанавливаем уровень взаиможействия
  result := FDirectSound.SetCooperativeLevel(FHandle, DSSCL_NORMAL);
  if FAILED(result) then EXIT;

  result := S_OK;
end;

{******************************************************************************}
{**  Создаем источник звука                                                  **}
{******************************************************************************}
function TdxSoundManager.CreateSound(WAVFileName: string): HResult;
var
  Sound: TdxSound;
begin
  result := E_FAIL;

  Sound := TdxSound.Create(FDirectSound, WAVFileName);
  if Sound <> NIL then
  begin
    FSounds.Add(Sound);
    result := S_OK;
  end;
end;

{******************************************************************************}
{**  Удаляем источник звука                                                  **}
{******************************************************************************}
function TdxSoundManager.DeleteSound(Index: integer): HResult;
var
  Sound: TdxSound;
begin
  result := E_FAIL;
  if (Index < 0) or (Index >= FSounds.Count) then EXIT;

  Sound := FSounds.Items[Index];
  if Sound = NIL then EXIT;

  FSounds.Remove(Sound);
  FreeAndNil(Sound);

  result := S_OK;
end;

{******************************************************************************}
{**  Получаем источник звука по индексу                                      **}
{******************************************************************************}
function TdxSoundManager.GetSound(Index: integer): TdxSound;
begin
  result := NIL;
  if (Index < 0) or (Index >= FSounds.Count) then EXIT;

  result := FSounds.Items[Index];
end;

{******************************************************************************}
{**  Получаем число источников звука                                         **}
{******************************************************************************}
function TdxSoundManager.SoundCount: integer;
begin
  result := FSounds.Count;
end;

{ TdxSound }

{******************************************************************************}
{**  Конструктор класса                                                      **}
{******************************************************************************}
constructor TdxSound.Create(DirectSound8: IDirectSound8; WAVFileName: string);
var
  FDSTmpBuf:  IDirectSoundBuffer;
  bdsc:       TDSBufferDesc;
  wfx:        TWaveFormatEx;
begin
  FdsChorus8     := NIL;
  FdsCompressor8 := NIL;
  FdsDistortion8 := NIL;
  FdsEcho8       := NIL;
  FdsFlanger8    := NIL;
  FdsGargle8     := NIL;
  FdsParamEq8    := NIL;
  FdsReverb8     := NIL;

  if DirectSound8 = NIL then EXIT;

  // Проверям существует ли файл
  if not FileExists(WAVFileName) then EXIT;

  FWAVFileName := WAVFileName;
  FdsBuffer8 := NIL;

  // Загружаем аудио-данные
  FData := LoadWAVFile(@wfx, @FDataSize);
  if FData = NIL then EXIT;

  // Заполняем структуру, описывающую вторичный буфер
  ZeroMemory(@bdsc, sizeof(bdsc));
  bdsc.dwSize         := sizeof(bdsc);
  bdsc.dwFlags        := DSBCAPS_CTRLFX or
                         DSBCAPS_CTRLPAN or
                         DSBCAPS_CTRLVOLUME or
                         DSBCAPS_CTRLFREQUENCY or
                         DSBCAPS_GLOBALFOCUS;
  bdsc.dwBufferBytes  := Max(FDataSize,
                             wfx.nSamplesPerSec *
                             DSBSIZE_FX_MIN div 1000 * 2);
  bdsc.lpwfxFormat    := @wfx;

  // Создаем временный буфер
  if FAILED(DirectSound8.CreateSoundBuffer(bdsc, FDSTmpBuf, NIL)) then EXIT;

  // Получаем интерфейс IDirectSoundBuffer8 для вторичного буфера
  if FAILED(FDSTmpBuf.QueryInterface(IID_IDirectSoundBuffer8, FdsBuffer8)) then EXIT;

  // Обнуляем временный буфер
  FDSTmpBuf := NIL;

  // Заполняем буфер данными
  FillBuffer;
end;

{******************************************************************************}
{**  Деструктор класса                                                       **}
{******************************************************************************}
destructor TdxSound.Destroy;
begin
  FdsChorus8     := NIL;
  FdsCompressor8 := NIL;
  FdsDistortion8 := NIL;
  FdsEcho8       := NIL;
  FdsFlanger8    := NIL;
  FdsGargle8     := NIL;
  FdsParamEq8    := NIL;
  FdsReverb8     := NIL;
  
  // Освобождаем память, выделенную под аудио-данные
  if Fdata <> NIL then FreeMemory(FData);
  
  FdsBuffer8 := NIL;
end;

{******************************************************************************}
{** Получаем частоту дискретизации                                           **}
{******************************************************************************}
function TdxSound.GetFrequency(var Frequency: Cardinal): HResult;
begin
  result := FdsBuffer8.GetFrequency(Frequency);
end;

{******************************************************************************}
{** Получаем положение на панораме                                           **}
{******************************************************************************}
function TdxSound.GetPan(var Pan: integer): HResult;
begin
  result := FdsBuffer8.GetPan(Pan);
end;

{******************************************************************************}
{** Получаем громкость звучания                                              **}
{******************************************************************************}
function TdxSound.GetVolume(var Volume: integer): HResult;
begin
  result := FdsBuffer8.GetVolume(Volume);
end;

{******************************************************************************}
{** Загрузка аудио-данных из WAV-файла                                       **}
{******************************************************************************}
function TdxSound.LoadWAVFile(wfx: PWaveFormatEx; dwSize: PDWORD): PByte;
var
  hwav: THandle;
  Child, Parent: TMMCKInfo;
begin
  result := NIL;
  
  // Открываем WAV-файл
  hwav := mmioOpen(PChar(FWAVFileName), NIL, MMIO_READ or MMIO_ALLOCBUF);
  try
    try
      if hwav = 0 then ABORT;

      ZeroMemory(@parent, sizeof(parent));
      parent.fccType :=  mmioStringToFOURCC('wave', MMIO_TOUPPER);
      Child := Parent;

      // Ищем блок 'RIFF'
      if (mmioDescend(hwav, @parent, NIL, MMIO_FINDRIFF) <> 0) then ABORT;

      // Рассматриваем блок 'fmt '
      child.ckid := mmioStringToFOURCC('fmt ', 0);
      if (mmioDescend(hwav, @child, @parent, 0) <> 0) then ABORT;

      // Получаем формат аудио-данных
      if (mmioRead(hwav, @wfx^, sizeof(wfx^)) <> sizeof(wfx^)) then ABORT;

      // Проверяем формат 
      if (wfx.wFormatTag <> WAVE_FORMAT_PCM) then ABORT;

      // Пднимаемся на уровень вверх, чтобы получить доступ к аудио-данным
      if (mmioAscend(hwav, @child, 0) <> 0) then ABORT;

      // Ищем блок 'data'
      child.ckid := mmioStringToFOURCC('data', 0);
      if (mmioDescend(hwav, @child, @parent, MMIO_FINDCHUNK) <> 0) then ABORT;

      // Выделяем память под аудио-данные
      result := GetMemory(child.cksize);

      // Читаем аудио-данные
      mmioRead(hwav, PChar(result), child.cksize);

      dwSize^ := child.cksize;
    except
    
      if result <> NIL then
      begin
        FreeMemory(result);
        result := NIL;
      end;
    end;

  finally
  
    // Закрываем файл
    mmioClose(hwav, 0);
  end;
end;

{******************************************************************************}
{** Воспроизводим буфер                                                      **}
{******************************************************************************}
function TdxSound.PlaySound(Looping: boolean): HResult;
begin
  FdsBuffer8.SetCurrentPosition(0);
  result := FdsBuffer8.Play(0, 0, integer(Looping));
end;

{******************************************************************************}
{** Устанавливаем эффекты воспроизведения для буфера                         **}
{******************************************************************************}
function TdxSound.SetEffects(EffectsMask: DWORD): HResult;
const
  Effects: array[0..SFX_COUNT - 1] of WORD =
  ( SFX_STANDARD_CHORUS,
    SFX_STANDARD_COMPRESSOR,
    SFX_STANDARD_DISTORTION,
    SFX_STANDARD_ECHO,
    SFX_STANDARD_FLANGER,
    SFX_STANDARD_GARGLE,
    SFX_STANDARD_PARAMEQ,
    SFX_WAVES_REVERB );
var
  I: integer;
  Count: integer;
  dwStatus: DWORD;
begin
  ZeroMemory(@dsEffect, sizeof(dsEffect));
  Count := 0;

  // Заполняем структуру, описывающую эффекты
  for I := 0 to SFX_COUNT - 1 do
  begin
    if (EffectsMask and Effects[I] =  Effects[I]) then
    begin
      dsEffect[Count].dwSize := sizeof(dsEffect[Count]);
      dsEffect[Count].dwFlags := 0;
      dsEffect[Count].guidDSFXClass := GetEffectGuid(Effects[I]);

      inc(Count);
    end;
  end;

  // Получаем текущий статус буфера
  result := FdsBuffer8.GetStatus(dwStatus);
  if FAILED(result) then EXIT;

  // Проверяем не воспроизводится ли буфер
  if (dwStatus and DSBSTATUS_PLAYING <> 0) then
  begin
    result := StopSound;
    if FAILED(result) then EXIT;
  end;

  // Очищаем список эффектов
  result := FdsBuffer8.SetFX(0, NIL, NIL);
  if Count = 0 then EXIT;

  // Устанавливаем новый набор эффектов
  ZeroMemory(@dwResults, sizeof(dwResults));
  result := FdsBuffer8.SetFX(Count, @dsEffect, @dwResults);

  // В случае успеха, получаем интерфейсы эффектов
  if (SUCCEEDED(result)) then
  begin
    FdsBuffer8.GetObjectInPath(GUID_DSFX_STANDARD_CHORUS, 0,
      IID_IDirectSoundFXChorus8, FdsChorus8);
    FdsBuffer8.GetObjectInPath(GUID_DSFX_STANDARD_COMPRESSOR, 0,
      IID_IDirectSoundFXCompressor8, FdsCompressor8);
    FdsBuffer8.GetObjectInPath(GUID_DSFX_STANDARD_DISTORTION, 0,
      IID_IDirectSoundFXDistortion8, FdsDistortion8);
    FdsBuffer8.GetObjectInPath(GUID_DSFX_STANDARD_ECHO, 0,
      IID_IDirectSoundFXEcho8, FdsEcho8);
    FdsBuffer8.GetObjectInPath(GUID_DSFX_STANDARD_FLANGER, 0,
      IID_IDirectSoundFXFlanger8, FdsFlanger8);
    FdsBuffer8.GetObjectInPath(GUID_DSFX_STANDARD_GARGLE, 0,
      IID_IDirectSoundFXGargle8, FdsGargle8);
    FdsBuffer8.GetObjectInPath(GUID_DSFX_STANDARD_PARAMEQ, 0,
      IID_IDirectSoundFXParameq8, FdsParameq8);
    FdsBuffer8.GetObjectInPath(GUID_DSFX_WAVES_REVERB, 0,
      IID_IDirectSoundFXWavesReverb8, FdsReverb8);
    EXIT;
  end;

  // Анализ ошибок
  case result of
    CO_E_NOTINITIALIZED   :   ShowMessage('CO_E_NOTINITIALIZED');
    DSERR_CONTROLUNAVAIL  :   ShowMessage('CDSERR_CONTROLUNAVAIL');
    DSERR_GENERIC         :   ShowMessage('CDSERR_GENERIC');
    DSERR_INVALIDPARAM    :   ShowMessage('CDSERR_INVALIDPARAM');
    DSERR_INVALIDCALL     :   ShowMessage('CDSERR_INVALIDCALL');
    DSERR_NOINTERFACE     :   ShowMessage('CDSERR_NOINTERFACE');
    DSERR_PRIOLEVELNEEDED :   ShowMessage('CDSERR_PRIOLEVELNEEDED');
  end;
end;

{******************************************************************************}
{** Получаем эффекты воспроизведения для буфера                              **}
{******************************************************************************}
function TdxSound.GetEffects(var EffectsMask: DWORD): HResult;
begin
  EffectsMask := 0;
  
  if FdsChorus8 <> NIL then
     EffectsMask := EffectsMask or SFX_STANDARD_CHORUS;
  if FdsCompressor8 <> NIL then
     EffectsMask := EffectsMask or SFX_STANDARD_COMPRESSOR;
  if FdsDistortion8 <> NIL then
     EffectsMask := EffectsMask or SFX_STANDARD_DISTORTION;
  if FdsEcho8 <> NIL then
     EffectsMask := EffectsMask or SFX_STANDARD_ECHO;
  if FdsFlanger8 <> NIL then
     EffectsMask := EffectsMask or SFX_STANDARD_FLANGER;
  if FdsGargle8 <> NIL then
     EffectsMask := EffectsMask or SFX_STANDARD_GARGLE;
  if FdsParamEq8 <> NIL then
     EffectsMask := EffectsMask or SFX_STANDARD_PARAMEQ;
  if FdsReverb8 <> NIL then
     EffectsMask := EffectsMask or SFX_WAVES_REVERB;

  result := S_OK;
end;

{******************************************************************************}
{** Устанавливаем частоту дискретизации                                      **}
{******************************************************************************}
function TdxSound.SetFrequency(Frequency: Cardinal): HResult;
begin
  result := FdsBuffer8.SetFrequency(Frequency);
end;

{******************************************************************************}
{** Устанавливаем положение на панораме                                      **}
{******************************************************************************}
function TdxSound.SetPan(Pan: integer): HResult;
begin
  result := FdsBuffer8.SetPan(Pan);
end;

{******************************************************************************}
{** Устанавливаем громкость звучания                                         **}
{******************************************************************************}
function TdxSound.SetVolume(Volume: integer): HResult;
begin
  result := FdsBuffer8.SetVolume(Volume);
end;

{******************************************************************************}
{** Останавливаем воспроизведение                                            **}
{******************************************************************************}
function TdxSound.StopSound: HResult;
begin
  result := FdsBuffer8.Stop;
end;

{******************************************************************************}
{** Заполняем буфер аудио-данными                                            **}
{******************************************************************************}
function TdxSound.FillBuffer: HResult;
var
  AudioPtr1, AudioPtr2: Pointer;
  AudioBytes1, AudioBytes2: DWORD;
begin
  // Обрабатываем ситуацию потери буфера
  result := RestoreBuffer(NIL);
  if FAILED(Result) then EXIT;

  // Блокируем буфер и получаем указатель на заблокированный блок данных
  result := FdsBuffer8.Lock(0, FDataSize, @AudioPtr1, @AudioBytes1,
    @AudioPtr2, @AudioBytes2, 0);
  if FAILED(result) then EXIT;

  // Копируем данные в буфер
  CopyMemory(AudioPtr1, FData, AudioBytes1);
  if (AudioPtr2 <> NIL) then
    CopyMemory(AudioPtr2, Pointer(DWORD(FData) + AudioBytes1), AudioBytes2);

  // Разблокировка буфера
  FdsBuffer8.Unlock(AudioPtr1, AudioBytes1, AudioPtr2, AudioBytes2);
end;

{******************************************************************************}
{** Восстанавливаем буфер после потери                                       **}
{******************************************************************************}
function TdxSound.RestoreBuffer(WasRestored: PBOOL): HResult;
var
  dwStatus: DWORD;
begin
  if WasRestored <> NIL then WasRestored^ := FALSE;

  // Получаем текущий статус буфера
  result := FdsBuffer8.GetStatus(dwStatus);
  if FAILED(result) then EXIT;

  // Проверяем на потерю
  if (dwStatus and DSBSTATUS_BUFFERLOST <> 0) then
  begin

    // Пытаемся восстановить
    Result := FdsBuffer8.Restore;
    while (Result = DSERR_BUFFERLOST) do
    begin
      Sleep(10);
      Result := FdsBuffer8.Restore;
    end;

    if WasRestored <> NIL then WasRestored^ := TRUE;

    Result:= S_OK;
  end else
  begin
    Result:= S_FALSE;
  end;
end;

{******************************************************************************}
{** Получаем идентификатор эффекта по внутреннему индексу                    **}
{******************************************************************************}
function TdxSound.GetEffectGuid(Effect: WORD): TGUID;
begin
  result := GUID_NULL;

  case Effect of
    SFX_STANDARD_CHORUS:     result := GUID_DSFX_STANDARD_CHORUS;
    SFX_STANDARD_COMPRESSOR: result := GUID_DSFX_STANDARD_COMPRESSOR;
    SFX_STANDARD_DISTORTION: result := GUID_DSFX_STANDARD_DISTORTION;
    SFX_STANDARD_ECHO:       result := GUID_DSFX_STANDARD_ECHO;
    SFX_STANDARD_FLANGER:    result := GUID_DSFX_STANDARD_FLANGER;
    SFX_STANDARD_GARGLE:     result := GUID_DSFX_STANDARD_GARGLE;
    SFX_STANDARD_PARAMEQ:    result := GUID_DSFX_STANDARD_PARAMEQ;
    SFX_WAVES_REVERB:        result := GUID_DSFX_WAVES_REVERB;
  end;
end;

{******************************************************************************}
{** Получаем параметры эффекта                                               **}
{******************************************************************************}
function TdxSound.GetEffectParams(Effect: DWORD; Params: pointer): HResult;
begin
  result := E_FAIL;

  case Effect of
    SFX_STANDARD_CHORUS:
      if FdsChorus8 <> NIL then
      begin                                  
        result := FdsChorus8.GetAllParameters(FParamsChorus);
        CopyMemory(Params, @FParamsChorus, sizeof(FParamsChorus));
      end;

    SFX_STANDARD_COMPRESSOR:
      if FdsCompressor8 <> NIL then
      begin
        result := FdsCompressor8.GetAllParameters(FParamsCompressor);
        CopyMemory(Params, @FParamsCompressor, sizeof(FParamsCompressor));
      end;

    SFX_STANDARD_DISTORTION:
      if FdsDistortion8 <> NIL then
      begin
        result := FdsDistortion8.GetAllParameters(FParamsDistortion);
        CopyMemory(Params, @FParamsDistortion, sizeof(FParamsDistortion));
      end;

    SFX_STANDARD_ECHO:
      if FdsEcho8 <> NIL then
      begin
        result := FdsEcho8.SetAllParameters(FParamsEcho);
        CopyMemory(Params, @FParamsEcho, sizeof(FParamsEcho));
      end;

    SFX_STANDARD_FLANGER:
      if FdsFlanger8 <> NIL then
      begin
        result := FdsFlanger8.GetAllParameters(FParamsFlanger);
        CopyMemory(Params, @FParamsFlanger, sizeof(FParamsFlanger));
      end;

    SFX_STANDARD_GARGLE:
      if FdsGargle8 <> NIL then
      begin
        result := FdsGargle8.GetAllParameters(FParamsGargle);
        CopyMemory(Params, @FParamsGargle, sizeof(FParamsGargle));
      end;

    SFX_STANDARD_PARAMEQ:
      if FdsParamEq8 <> NIL then
      begin
        result := FdsParamEq8.GetAllParameters(FParamsParamEq);
        CopyMemory(Params, @FParamsParamEq, sizeof(FParamsParamEq));
      end;

    SFX_WAVES_REVERB:
      if FdsReverb8 <> NIL then
      begin
        result := FdsReverb8.GetAllParameters(FParamsReverb);
        CopyMemory(Params, @FParamsReverb, sizeof(FParamsReverb));
      end;
  end;
end;

{******************************************************************************}
{** Устанавливаем параметры эффекта                                          **}
{******************************************************************************}
function TdxSound.SetEffectParams(Effect: DWORD;
  const Params: pointer): HResult;
begin
  result := E_FAIL;

  case Effect of
    SFX_STANDARD_CHORUS:
      if FdsChorus8 <> NIL then
      begin
        FParamsChorus := TDSFXChorus(Params^);
        result := FdsChorus8.SetAllParameters(FParamsChorus);
      end;

    SFX_STANDARD_COMPRESSOR:
      if FdsCompressor8 <> NIL then
      begin
        FParamsCompressor := TDSFXCompressor(Params^);
        result := FdsCompressor8.SetAllParameters(FParamsCompressor);
      end;

    SFX_STANDARD_DISTORTION:
      if FdsDistortion8 <> NIL then
      begin
        FParamsDistortion := TDSFXDistortion(Params^);
        result := FdsDistortion8.SetAllParameters(FParamsDistortion);
      end;

    SFX_STANDARD_ECHO:
      if FdsEcho8 <> NIL then
      begin
        FParamsEcho := TDSFXEcho(Params^);
        result := FdsEcho8.SetAllParameters(FParamsEcho);
      end;

    SFX_STANDARD_FLANGER:
      if FdsFlanger8 <> NIL then
      begin
        FParamsFlanger := TDSFXFlanger(Params^);
        result := FdsFlanger8.SetAllParameters(FParamsFlanger);
      end;

    SFX_STANDARD_GARGLE:
      if FdsGargle8 <> NIL then
      begin
        FParamsGargle := TDSFXGargle(Params^);
        result := FdsGargle8.SetAllParameters(FParamsGargle);
      end;

    SFX_STANDARD_PARAMEQ:
      if FdsParamEq8 <> NIL then
      begin
        FParamsParamEq := TDSFXParamEq(Params^);
        result := FdsParamEq8.SetAllParameters(FParamsParamEq);
      end;

    SFX_WAVES_REVERB:
      if FdsReverb8 <> NIL then
      begin
        FParamsReverb:= TDSFXWavesReverb(Params^);
        result := FdsReverb8.SetAllParameters(FParamsReverb);
      end;
  end;
end;

END.
