unit FastQuery;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.Grids, Vcl.DBGrids,
  FireDAC.Stan.Intf, FireDAC.Stan.Option, FireDAC.Stan.Error, FireDAC.UI.Intf,
  FireDAC.Phys.Intf, FireDAC.Stan.Def, FireDAC.Stan.Pool, FireDAC.Stan.Async,
  FireDAC.Phys, FireDAC.Stan.Param, FireDAC.DatS, FireDAC.DApt.Intf, Data.DB,
  FireDAC.Comp.DataSet, FireDAC.Comp.Client, FireDAC.Stan.ExprFuncs,
  FireDAC.Phys.SQLiteDef, FireDAC.Phys.SQLite, FireDAC.DApt, Vcl.StdCtrls, IFD.FastQuery,
  ProjectFastQueryBridge, FireDAC.VCLUI.Wait, FireDAC.Comp.UI, DBGridEhGrouping,
  ToolCtrlsEh, DBGridEhToolCtrls, DynVarsEh, EhLibVCL, GridsEh, DBAxisGridsEh,
  DBGridEh, MemTableDataEh, MemTableEh, DataDriverEh, FireDAC.Stan.StorageBin;

type
  TForm2 = class(TForm)
    con1: TFDConnection;
    ds1: TDataSource;
    btn1: TButton;
    mmo1: TMemo;
    ds2: TDataSource;
    btn2: TButton;
    btn3: TButton;
    FDGUIxWaitCursor1: TFDGUIxWaitCursor;
    grd1: TDBGridEh;
    grd2: TDBGridEh;
    mtb2: TFDMemTable;
    ssbl1: TFDStanStorageBinLink;
    procedure FormCreate(Sender: TObject);
    procedure btn1Click(Sender: TObject);
    procedure btn2Click(Sender: TObject);
    procedure btn3Click(Sender: TObject);
  private
    { Private declarations }
    Q1: IFastQuery;
  public
    { Public declarations }
  end;

var
  Form2: TForm2;

implementation

{$R *.dfm}

procedure TForm2.btn1Click(Sender: TObject);
begin
  Q1 := NewQuery(cnnMain);
  Q1.SQL('SELECT * FROM courses WHERE course_code=:ccode AND course_name=:cname')
  .Param('ccode', 'C102')
  .Param('cname', 'Python程序设计')
  .Open;
  ds1.DataSet := Q1.DataSet;
end;

procedure TForm2.btn2Click(Sender: TObject);
var
  Q2: IFastQuery;
begin
  Q2 := NewQuery(cnnMain);
  Q2.SQL('SELECT * FROM students WHERE student_no=:stn AND name=:name AND phone=:ph')
  .Param('stn', '2023001')
  .Param('name', '张晨')
  .Param('ph', '13800000001')
  .Open;
  Q2.DataSet.SaveToFile(ExtractFilePath(ParamStr(0)) + 'tmp');
  mtb2.LoadFromFile(ExtractFilePath(ParamStr(0)) + 'tmp');
  DeleteFile(ExtractFilePath(ParamStr(0)) + 'tmp.fds');
end;

procedure TForm2.btn3Click(Sender: TObject);
var
  QTmp: IFastQuery;
begin
  QTmp := NewQuery(cnnMain);
  QTmp.SQL('SELECT * FROM students').Open;
  while not QTmp.DataSet.Eof do
  begin
    mmo1.Lines.Add(QTmp.DataSet.FieldByName('name').AsString + ' ' +
                    QTmp.DataSet.FieldByName('gender').AsString + ' ' +
                    QTmp.DataSet.FieldByName('class_name').AsString);
    QTmp.DataSet.Next;
  end;
end;

procedure TForm2.FormCreate(Sender: TObject);
begin
  //register project db connection
  RegisterProjectDbConnection(cnnMain, con1);
  //register another if you need
  //RegisterProjectDbConnection(cnnChild, con2);
end;

end.
