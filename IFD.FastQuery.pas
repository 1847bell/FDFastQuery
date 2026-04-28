unit IFD.FastQuery;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Variants,
  Data.DB,
  FireDAC.Comp.Client,
  FireDAC.Stan.Option,
  FireDAC.Stan.Param;

type
  TFastQueryConnKey = Integer;

  TSqlAction = (saOpen, saExec);

  ISqlLogger = interface
    ['{7B3A8A25-AF10-4A67-B4AB-B2A7755A5225}']
    procedure LogStart(const ATraceId, AConnName: string;
      const AAction: TSqlAction; const ASQL, AParamsText: string);
    procedure LogEnd(const ATraceId, AConnName: string;
      const AAction: TSqlAction; const ASQL, AParamsText: string;
      const ARows: Integer; const AElapsedMs: Int64);
    procedure LogError(const ATraceId, AConnName: string;
      const AAction: TSqlAction; const ASQL, AParamsText, AErrorText: string;
      const AElapsedMs: Int64);
  end;

  IFastQuery = interface
    ['{9D4F27FA-48E2-4FF6-830E-33271D9EE2B1}']
    function SQL(const ASQL: string): IFastQuery;
    function Add(const ASQL: string): IFastQuery;
    function Param(const AName: string; const AValue: Variant): IFastQuery;
    function Clear: IFastQuery;
    function Close: IFastQuery;
    function Open: IFastQuery;
    function Exec: Integer;
    function DataSet: TFDQuery;
  end;

procedure RegisterDbConnection(const AConnKey: TFastQueryConnKey;
  const AConnName: string; AConnection: TFDConnection); overload;
procedure RegisterDbConnection(const AConnKey: TFastQueryConnKey;
  AConnection: TFDConnection); overload;
procedure UnregisterDbConnection(const AConnKey: TFastQueryConnKey);
procedure ClearDbConnections;
function DbConnKeyToString(const AConnKey: TFastQueryConnKey): string;
procedure SetSqlLogger(const ALogger: ISqlLogger);
function GetSqlLogger: ISqlLogger;
function NewFastQuery(const AConnKey: TFastQueryConnKey): IFastQuery;

implementation

uses
  Winapi.Windows;

type
  TDbConnectionItem = class
  public
    ConnName: string;
    Connection: TFDConnection;
  end;

  TFileSqlLogger = class(TInterfacedObject, ISqlLogger)
  strict private
    function BuildLogFileName: string;
    function BuildPrefix(const AStage, ATraceId, AConnName: string;
      const AAction: TSqlAction): string;
    procedure AppendLine(const ALine: string);
  public
    procedure LogStart(const ATraceId, AConnName: string;
      const AAction: TSqlAction; const ASQL, AParamsText: string);
    procedure LogEnd(const ATraceId, AConnName: string;
      const AAction: TSqlAction; const ASQL, AParamsText: string;
      const ARows: Integer; const AElapsedMs: Int64);
    procedure LogError(const ATraceId, AConnName: string;
      const AAction: TSqlAction; const ASQL, AParamsText, AErrorText: string;
      const AElapsedMs: Int64);
  end;

  TDbConnResolver = class
  public
    class function Resolve(const AConnKey: TFastQueryConnKey): TFDConnection; static;
  end;

  TFastQuery = class(TInterfacedObject, IFastQuery)
  strict private
    FConnKey: TFastQueryConnKey;
    FConnName: string;
    FQuery: TFDQuery;
    function AsInterface: IFastQuery;
    function CountOpenedRows: Integer;
    function BuildParamsText: string;
    function BuildSqlText: string;
    function BuildTraceId: string;
    function GetElapsedMs(const AStartedAt: Cardinal): Int64;
    procedure BindConnection;
    procedure ResetState;
    procedure ValidateSql;
  public
    constructor Create(const AConnKey: TFastQueryConnKey);
    destructor Destroy; override;
    function SQL(const ASQL: string): IFastQuery;
    function Add(const ASQL: string): IFastQuery;
    function Param(const AName: string; const AValue: Variant): IFastQuery;
    function Clear: IFastQuery;
    function Close: IFastQuery;
    function Open: IFastQuery;
    function Exec: Integer;
    function DataSet: TFDQuery;
  end;

var
  GConnectionItems: TStringList;
  GSqlLogger: ISqlLogger;
  GTraceSeed: Integer = 0;

procedure EnsureConnectionRegistry;
begin
  if GConnectionItems = nil then
    GConnectionItems := TStringList.Create;
end;

function ConnKeyAsText(const AConnKey: TFastQueryConnKey): string;
begin
  Result := IntToStr(AConnKey);
end;

function GetConnectionItem(const AConnKey: TFastQueryConnKey): TDbConnectionItem;
var
  LIndex: Integer;
begin
  Result := nil;
  if GConnectionItems = nil then
    Exit;

  LIndex := GConnectionItems.IndexOf(ConnKeyAsText(AConnKey));
  if LIndex >= 0 then
    Result := TDbConnectionItem(GConnectionItems.Objects[LIndex]);
end;

procedure FreeConnectionItem(const AIndex: Integer);
begin
  if (GConnectionItems <> nil) and (AIndex >= 0) and (AIndex < GConnectionItems.Count) then
  begin
    GConnectionItems.Objects[AIndex].Free;
    GConnectionItems.Objects[AIndex] := nil;
  end;
end;

function SqlActionToString(const AAction: TSqlAction): string;
begin
  case AAction of
    saOpen:
      Result := 'OPEN';
    saExec:
      Result := 'EXEC';
  else
    Result := 'UNKNOWN';
  end;
end;

function SanitizeLogText(const AText: string): string;
begin
  Result := StringReplace(AText, #13#10, ' ', [rfReplaceAll]);
  Result := StringReplace(Result, #13, ' ', [rfReplaceAll]);
  Result := StringReplace(Result, #10, ' ', [rfReplaceAll]);
  Result := Trim(Result);
end;

function SafeVariantToString(const AValue: Variant): string;
begin
  if VarIsNull(AValue) or VarIsEmpty(AValue) then
  begin
    Result := 'NULL';
    Exit;
  end;

  if VarIsType(AValue, varDate) then
  begin
    Result := FormatDateTime('yyyy-mm-dd hh:nn:ss.zzz', VarToDateTime(AValue));
    Exit;
  end;

  try
    Result := VarToStr(AValue);
  except
    Result := '<unsupported>';
  end;
end;

function ParamValueToText(const AParam: TFDParam): string;
begin
  if AParam.IsNull then
  begin
    Result := 'NULL';
    Exit;
  end;

  case AParam.DataType of
    ftBlob,
    ftMemo,
    ftFmtMemo,
    ftGraphic,
    ftOraBlob,
    ftOraClob,
    ftWideMemo,
    ftStream:
      Result := '<binary>';
  else
    Result := SafeVariantToString(AParam.Value);
  end;
end;

procedure RegisterDbConnection(const AConnKey: TFastQueryConnKey;
  const AConnName: string; AConnection: TFDConnection);
var
  LIndex: Integer;
  LItem: TDbConnectionItem;
  LKeyText: string;
begin
  if AConnection = nil then
    raise Exception.CreateFmt('Cannot register nil connection for key %s.',
      [DbConnKeyToString(AConnKey)]);

  EnsureConnectionRegistry;
  LKeyText := ConnKeyAsText(AConnKey);
  LIndex := GConnectionItems.IndexOf(LKeyText);

  if LIndex >= 0 then
    LItem := TDbConnectionItem(GConnectionItems.Objects[LIndex])
  else
  begin
    LItem := TDbConnectionItem.Create;
    GConnectionItems.AddObject(LKeyText, LItem);
  end;

  if Trim(AConnName) = '' then
    LItem.ConnName := LKeyText
  else
    LItem.ConnName := AConnName;
  LItem.Connection := AConnection;
end;

procedure RegisterDbConnection(const AConnKey: TFastQueryConnKey;
  AConnection: TFDConnection);
begin
  RegisterDbConnection(AConnKey, ConnKeyAsText(AConnKey), AConnection);
end;

procedure UnregisterDbConnection(const AConnKey: TFastQueryConnKey);
var
  LIndex: Integer;
begin
  if GConnectionItems = nil then
    Exit;

  LIndex := GConnectionItems.IndexOf(ConnKeyAsText(AConnKey));
  if LIndex >= 0 then
  begin
    FreeConnectionItem(LIndex);
    GConnectionItems.Delete(LIndex);
  end;
end;

procedure ClearDbConnections;
var
  I: Integer;
begin
  if GConnectionItems = nil then
    Exit;

  for I := GConnectionItems.Count - 1 downto 0 do
    FreeConnectionItem(I);
  GConnectionItems.Clear;
end;

function DbConnKeyToString(const AConnKey: TFastQueryConnKey): string;
var
  LItem: TDbConnectionItem;
begin
  LItem := GetConnectionItem(AConnKey);
  if (LItem <> nil) and (Trim(LItem.ConnName) <> '') then
    Result := LItem.ConnName
  else
    Result := ConnKeyAsText(AConnKey);
end;

procedure SetSqlLogger(const ALogger: ISqlLogger);
begin
  GSqlLogger := ALogger;
end;

function GetSqlLogger: ISqlLogger;
begin
  if GSqlLogger = nil then
    GSqlLogger := TFileSqlLogger.Create;

  Result := GSqlLogger;
end;

function NewFastQuery(const AConnKey: TFastQueryConnKey): IFastQuery;
begin
  Result := TFastQuery.Create(AConnKey);
end;

{ TFileSqlLogger }

procedure TFileSqlLogger.AppendLine(const ALine: string);
var
  LBytes: TBytes;
  LFileName: string;
  LStream: TFileStream;
begin
  LFileName := BuildLogFileName;
  ForceDirectories(ExtractFilePath(LFileName));

  LBytes := TEncoding.UTF8.GetBytes(ALine + sLineBreak);
  if FileExists(LFileName) then
    LStream := TFileStream.Create(LFileName, fmOpenReadWrite or fmShareDenyNone)
  else
    LStream := TFileStream.Create(LFileName, fmCreate);
  try
    LStream.Position := LStream.Size;
    if Length(LBytes) > 0 then
      LStream.WriteBuffer(LBytes[0], Length(LBytes));
  finally
    LStream.Free;
  end;
end;

function TFileSqlLogger.BuildLogFileName: string;
var
  LBasePath: string;
begin
  LBasePath := IncludeTrailingPathDelimiter(ExtractFilePath(ParamStr(0)));
  Result := LBasePath + 'logs\sql\' + FormatDateTime('yyyymmdd', Now) + '.log';
end;

function TFileSqlLogger.BuildPrefix(const AStage, ATraceId, AConnName: string;
  const AAction: TSqlAction): string;
begin
  Result := Format('[%s] [%s] [TraceId=%s] [%s] [%s]',
    [FormatDateTime('yyyy-mm-dd hh:nn:ss.zzz', Now), AStage, ATraceId,
     AConnName, SqlActionToString(AAction)]);
end;

procedure TFileSqlLogger.LogStart(const ATraceId, AConnName: string;
  const AAction: TSqlAction; const ASQL, AParamsText: string);
begin
  AppendLine(BuildPrefix('START', ATraceId, AConnName, AAction) +
    Format(' SQL=%s PARAMS=%s',
    [SanitizeLogText(ASQL), SanitizeLogText(AParamsText)]));
end;

procedure TFileSqlLogger.LogEnd(const ATraceId, AConnName: string;
  const AAction: TSqlAction; const ASQL, AParamsText: string;
  const ARows: Integer; const AElapsedMs: Int64);
begin
  AppendLine(BuildPrefix('END', ATraceId, AConnName, AAction) +
    Format(' ROWS=%d ELAPSED=%dms SQL=%s PARAMS=%s',
    [ARows, AElapsedMs, SanitizeLogText(ASQL), SanitizeLogText(AParamsText)]));
end;

procedure TFileSqlLogger.LogError(const ATraceId, AConnName: string;
  const AAction: TSqlAction; const ASQL, AParamsText, AErrorText: string;
  const AElapsedMs: Int64);
begin
  AppendLine(BuildPrefix('ERROR', ATraceId, AConnName, AAction) +
    Format(' ERROR=%s ELAPSED=%dms SQL=%s PARAMS=%s',
    [SanitizeLogText(AErrorText), AElapsedMs, SanitizeLogText(ASQL),
     SanitizeLogText(AParamsText)]));
end;

{ TDbConnResolver }

class function TDbConnResolver.Resolve(const AConnKey: TFastQueryConnKey): TFDConnection;
var
  LItem: TDbConnectionItem;
begin
  LItem := GetConnectionItem(AConnKey);
  if LItem = nil then
    raise Exception.CreateFmt('Database connection not registered for key %s.',
      [DbConnKeyToString(AConnKey)]);

  Result := LItem.Connection;
  if Result = nil then
    raise Exception.CreateFmt('Database connection is nil for key %s.',
      [DbConnKeyToString(AConnKey)]);
end;

{ TFastQuery }

function TFastQuery.Add(const ASQL: string): IFastQuery;
begin
  FQuery.SQL.Add(ASQL);
  Result := AsInterface;
end;

function TFastQuery.AsInterface: IFastQuery;
begin
  Result := Self;
end;

function TFastQuery.CountOpenedRows: Integer;
begin
  Result := 0;

  if not FQuery.Active then
    Exit;

  if FQuery.IsEmpty then
    Exit;

  FQuery.DisableControls;
  try
    FQuery.First;
    while not FQuery.Eof do
    begin
      Inc(Result);
      FQuery.Next;
    end;
    FQuery.First;
  finally
    FQuery.EnableControls;
  end;
end;

procedure TFastQuery.BindConnection;
begin
  FConnName := DbConnKeyToString(FConnKey);
  FQuery.Connection := TDbConnResolver.Resolve(FConnKey);
end;

function TFastQuery.BuildParamsText: string;
var
  I: Integer;
  LParam: TFDParam;
begin
  Result := '';
  for I := 0 to FQuery.Params.Count - 1 do
  begin
    LParam := FQuery.Params[I];
    if Result <> '' then
      Result := Result + '; ';
    Result := Result + LParam.Name + '=' + ParamValueToText(LParam);
  end;

  if Result = '' then
    Result := '<none>';
end;

function TFastQuery.BuildSqlText: string;
begin
  Result := Trim(FQuery.SQL.Text);
end;

function TFastQuery.BuildTraceId: string;
begin
  Result := FormatDateTime('yyyymmddhhnnsszzz', Now) + '_' +
    Format('%.4d', [InterlockedIncrement(GTraceSeed)]);
end;

function TFastQuery.Clear: IFastQuery;
begin
  ResetState;
  Result := AsInterface;
end;

function TFastQuery.Close: IFastQuery;
begin
  if FQuery.Active then
    FQuery.Close;
  Result := AsInterface;
end;

constructor TFastQuery.Create(const AConnKey: TFastQueryConnKey);
begin
  inherited Create;
  FConnKey := AConnKey;
  FQuery := TFDQuery.Create(nil);
  FQuery.FetchOptions.RecordCountMode := cmFetched;
  BindConnection;
end;

function TFastQuery.DataSet: TFDQuery;
begin
  Result := FQuery;
end;

destructor TFastQuery.Destroy;
begin
  FQuery.Free;
  inherited Destroy;
end;

function TFastQuery.Exec: Integer;
var
  LAction: TSqlAction;
  LElapsedMs: Int64;
  LParamsText: string;
  LRows: Integer;
  LSqlText: string;
  LStartedAt: Cardinal;
  LTraceId: string;
begin
  ValidateSql;
  LAction := saExec;
  LTraceId := BuildTraceId;
  LSqlText := BuildSqlText;
  LParamsText := BuildParamsText;
  GetSqlLogger.LogStart(LTraceId, FConnName, LAction, LSqlText, LParamsText);

  LStartedAt := GetTickCount;
  try
    if FQuery.Active then
      FQuery.Close;
    FQuery.ExecSQL;
    LRows := FQuery.RowsAffected;
    LElapsedMs := GetElapsedMs(LStartedAt);
    GetSqlLogger.LogEnd(LTraceId, FConnName, LAction, LSqlText, LParamsText,
      LRows, LElapsedMs);
    Result := LRows;
  except
    on E: Exception do
    begin
      LElapsedMs := GetElapsedMs(LStartedAt);
      GetSqlLogger.LogError(LTraceId, FConnName, LAction, LSqlText,
        LParamsText, E.Message, LElapsedMs);
      raise;
    end;
  end;
end;

function TFastQuery.GetElapsedMs(const AStartedAt: Cardinal): Int64;
begin
  Result := Int64(GetTickCount - AStartedAt);
end;

function TFastQuery.Open: IFastQuery;
var
  LAction: TSqlAction;
  LElapsedMs: Int64;
  LParamsText: string;
  LRows: Integer;
  LSqlText: string;
  LStartedAt: Cardinal;
  LTraceId: string;
begin
  ValidateSql;
  LAction := saOpen;
  LTraceId := BuildTraceId;
  LSqlText := BuildSqlText;
  LParamsText := BuildParamsText;
  GetSqlLogger.LogStart(LTraceId, FConnName, LAction, LSqlText, LParamsText);

  LStartedAt := GetTickCount;
  try
    if FQuery.Active then
      FQuery.Close;
    FQuery.Open;
    FQuery.FetchAll;
    LRows := CountOpenedRows;
    LElapsedMs := GetElapsedMs(LStartedAt);
    GetSqlLogger.LogEnd(LTraceId, FConnName, LAction, LSqlText, LParamsText,
      LRows, LElapsedMs);
    Result := AsInterface;
  except
    on E: Exception do
    begin
      LElapsedMs := GetElapsedMs(LStartedAt);
      GetSqlLogger.LogError(LTraceId, FConnName, LAction, LSqlText,
        LParamsText, E.Message, LElapsedMs);
      raise;
    end;
  end;
end;

function TFastQuery.Param(const AName: string; const AValue: Variant): IFastQuery;
begin
  FQuery.ParamByName(AName).Value := AValue;
  Result := AsInterface;
end;

procedure TFastQuery.ResetState;
begin
  if FQuery.Active then
    FQuery.Close;
  FQuery.SQL.Clear;
  FQuery.Params.Clear;
end;

function TFastQuery.SQL(const ASQL: string): IFastQuery;
begin
  ResetState;
  FQuery.SQL.Text := ASQL;
  Result := AsInterface;
end;

procedure TFastQuery.ValidateSql;
begin
  if BuildSqlText = '' then
    raise Exception.Create('SQL is empty.');
end;

initialization
  EnsureConnectionRegistry;

finalization
  GSqlLogger := nil;
  ClearDbConnections;
  GConnectionItems.Free;
  GConnectionItems := nil;

end.
