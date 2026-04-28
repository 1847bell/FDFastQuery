object Form2: TForm2
  Left = 0
  Top = 0
  Caption = 'Form2'
  ClientHeight = 409
  ClientWidth = 621
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  OldCreateOrder = False
  OnCreate = FormCreate
  PixelsPerInch = 96
  TextHeight = 13
  object btn1: TButton
    Left = 2
    Top = 4
    Width = 75
    Height = 25
    Caption = 'Grid1'
    TabOrder = 0
    OnClick = btn1Click
  end
  object mmo1: TMemo
    Left = 0
    Top = 98
    Width = 220
    Height = 312
    TabOrder = 1
  end
  object btn2: TButton
    Left = 82
    Top = 5
    Width = 75
    Height = 25
    Caption = 'Grid2'
    TabOrder = 2
    OnClick = btn2Click
  end
  object btn3: TButton
    Left = 1
    Top = 33
    Width = 75
    Height = 25
    Caption = 'Memo'
    TabOrder = 3
    OnClick = btn3Click
  end
  object grd1: TDBGridEh
    Left = 221
    Top = 1
    Width = 399
    Height = 196
    DataSource = ds1
    DrawMemoText = True
    DynProps = <>
    IndicatorOptions = [gioShowRowIndicatorEh]
    TabOrder = 4
    object RowDetailData: TRowDetailPanelControlEh
    end
  end
  object grd2: TDBGridEh
    Left = 221
    Top = 199
    Width = 399
    Height = 211
    DataSource = ds2
    DrawMemoText = True
    DynProps = <>
    IndicatorOptions = [gioShowRowIndicatorEh]
    TabOrder = 5
    object RowDetailData: TRowDetailPanelControlEh
    end
  end
  object con1: TFDConnection
    Params.Strings = (
      'Database=D:\JQSoft\Code\FDFastQuery\student_demo.db'
      'DriverID=SQLite')
    LoginPrompt = False
    Left = 281
    Top = 81
  end
  object ds1: TDataSource
    Left = 322
    Top = 91
  end
  object ds2: TDataSource
    DataSet = mtb2
    Left = 257
    Top = 291
  end
  object FDGUIxWaitCursor1: TFDGUIxWaitCursor
    Provider = 'Forms'
    Left = 407
    Top = 233
  end
  object mtb2: TFDMemTable
    FetchOptions.AssignedValues = [evMode]
    FetchOptions.Mode = fmAll
    ResourceOptions.AssignedValues = [rvSilentMode]
    ResourceOptions.SilentMode = True
    UpdateOptions.AssignedValues = [uvCheckRequired]
    UpdateOptions.CheckRequired = False
    AutoCommitUpdates = False
    Left = 304
    Top = 210
  end
  object ssbl1: TFDStanStorageBinLink
    Left = 356
    Top = 290
  end
end
