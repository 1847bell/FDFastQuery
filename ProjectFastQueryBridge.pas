unit ProjectFastQueryBridge;

interface

uses
  FireDAC.Comp.Client,
  IFD.FastQuery;

type
  TProjectDbConnKey = (cnnMain, cnnChild);

function ProjectDbConnKeyToString(const AConnKey: TProjectDbConnKey): string;
procedure RegisterProjectDbConnection(const AConnKey: TProjectDbConnKey;const AConnDB: TFDConnection);
function NewQuery(const AConnKey: TProjectDbConnKey): IFastQuery;

implementation

function ProjectDbConnKeyToString(const AConnKey: TProjectDbConnKey): string;
begin
  case AConnKey of
    cnnMain:
      Result := 'conMain';
    cnnChild:
      Result := 'conChild';
  else
    Result := 'unknown';
  end;
end;

procedure RegisterProjectDbConnection(const AConnKey: TProjectDbConnKey;const AConnDB: TFDConnection);
begin
  RegisterDbConnection(Ord(AConnKey), ProjectDbConnKeyToString(AConnKey), AConnDB);
end;

function NewQuery(const AConnKey: TProjectDbConnKey): IFastQuery;
begin
  Result := NewFastQuery(Ord(AConnKey));
end;

end.
