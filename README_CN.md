# FDFastQuery

FDFastQuery 是一个轻量级、高效的 FireDAC 查询封装库，为 Delphi 提供了流式、链式调用的数据库操作 API。

## 特性

- **流式链式 API**：通过直观的方法链构建查询
- **类型安全**：基于接口的设计，提供编译时安全检查
- **自动 SQL 日志**：内置 SQL 执行日志记录，带跟踪 ID
- **性能追踪**：自动记录执行时间和受影响的行数
- **连接管理**：集中的数据库连接注册管理
- **零配置**：开箱即用，最小化设置

## 核心组件

### IFD.FastQuery.pas
核心接口单元，提供：

- `IFastQuery` - 主要的查询接口，支持链式方法调用
- `ISqlLogger` - SQL 日志记录接口
- 连接注册和管理工具
- 内置的文件 SQL 日志记录器

### ProjectFastQueryBridge.pas
项目特定的桥接层，封装核心库：

- `TProjectDbConnKey` - 项目特定的连接键（cnnMain, cnnChild）
- `RegisterProjectDbConnection` - 注册项目连接的辅助函数
- `NewQuery` - 创建查询的工厂方法

## 安装

1. 将 `IFD.FastQuery.pas` 和 `ProjectFastQueryBridge.pas` 添加到项目中
2. 添加必要的单元引用：
   - `System.SysUtils`
   - `System.Classes`
   - `System.Variants`
   - `Data.DB`
   - `FireDAC.Comp.Client`
   - `FireDAC.Stan.Option`
   - `FireDAC.Stan.Param`

## 快速开始

### 1. 注册数据库连接

```delphi
uses
  IFD.FastQuery, ProjectFastQueryBridge;

procedure TForm1.FormCreate(Sender: TObject);
begin
  // 注册主连接
  RegisterProjectDbConnection(cnnMain, FDConnection1);

  // 如需要，注册其他连接
  RegisterProjectDbConnection(cnnChild, FDConnection2);
end;
```

### 2. 参数化查询

```delphi
// 带参数的简单查询
var
  Q: IFastQuery;
begin
  Q := NewQuery(cnnMain);
  Q.SQL('SELECT * FROM students WHERE student_no=:stn AND name=:name')
   .Param('stn', '2023001')
   .Param('name', '张三')
   .Open;

  DataSource1.DataSet := Q.DataSet;
end;
```

### 3. 执行非查询 SQL

```delphi
// 执行 INSERT/UPDATE/DELETE
var
  Q: IFastQuery;
  RowsAffected: Integer;
begin
  Q := NewQuery(cnnMain);
  RowsAffected := Q.SQL('UPDATE students SET phone=:ph WHERE id=:id')
                     .Param('ph', '13800000001')
                     .Param('id', 123)
                     .Exec;
end;
```

### 4. 链式多个操作

```delphi
// 复用查询对象
var
  Q: IFastQuery;
begin
  Q := NewQuery(cnnMain);

  // 第一个查询
  Q.SQL('SELECT * FROM courses WHERE course_code=:code')
   .Param('code', 'C101')
   .Open;

  // 处理结果...

  // 清除并重新使用
  Q.Clear
   .SQL('SELECT * FROM students WHERE class_id=:cid')
   .Param('cid', 101)
   .Open;
end;
```

## API 参考

### IFastQuery 接口

| 方法 | 描述 |
|------|------|
| `SQL(const ASQL: string)` | 设置 SQL 语句并清除之前的状态 |
| `Add(const ASQL: string)` | 向现有 SQL 添加文本 |
| `Param(const AName: string; const AValue: Variant)` | 设置参数值 |
| `Clear` | 清除 SQL 和参数 |
| `Close` | 如果已打开则关闭查询 |
| `Open` | 执行 SELECT 查询并打开数据集 |
| `Exec: Integer` | 执行非查询 SQL，返回受影响的行数 |
| `DataSet: TFDQuery` | 获取底层的 TFDQuery 对象 |

### 连接管理

| 函数 | 描述 |
|------|------|
| `RegisterDbConnection(const AConnKey: TFastQueryConnKey; AConnection: TFDConnection)` | 按键注册连接 |
| `UnregisterDbConnection(const AConnKey: TFastQueryConnKey)` | 注销连接 |
| `ClearDbConnections` | 清除所有已注册的连接 |
| `DbConnKeyToString(const AConnKey: TFastQueryConnKey)` | 获取连接名称 |

### SQL 日志

| 函数 | 描述 |
|------|------|
| `SetSqlLogger(const ALogger: ISqlLogger)` | 设置自定义 SQL 日志记录器 |
| `GetSqlLogger: ISqlLogger` | 获取当前 SQL 日志记录器（如未设置则创建默认的） |

## SQL 日志

库包含自动 SQL 日志功能，记录：

- SQL 语句和参数
- 执行时间（毫秒）
- 受影响的行数
- 用于请求关联的跟踪 ID
- 执行失败时的错误信息

日志文件保存在：`logs\sql\{YYYYMMDD}.log`

日志示例：
```
[2026-04-28 16:30:45.123] [START] [TraceId=20260428163045123_0001] [conMain] [OPEN] SQL=SELECT * FROM students WHERE id=:id PARAMS=id=123
[2026-04-28 16:30:45.156] [END] [TraceId=20260428163045123_0001] [conMain] [OPEN] ROWS=1 ELAPSED=33ms SQL=SELECT * FROM students WHERE id=:id PARAMS=id=123
```

### 自定义日志

实现 `ISqlLogger` 接口以自定义日志：

```delphi
type
  TMySqlLogger = class(TInterfacedObject, ISqlLogger)
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

// 设置自定义日志记录器
SetSqlLogger(TMySqlLogger.Create);
```

## 示例项目

包含的示例（`FastQuery.pas`）演示了：

- 注册数据库连接
- 带参数查询
- 将数据加载到内存表中
- 遍历查询结果

## 系统要求

- Delphi XE2 或更高版本
- FireDAC 组件
- Windows 平台

## 许可证

MIT License
