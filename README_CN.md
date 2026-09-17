# FDFastQuery

FDFastQuery 是一个轻量级、高效的 FireDAC 查询封装库，为 Delphi 提供了流式、链式调用的数据库操作 API。

## 特性

- **流式链式 API**：通过直观的方法链构建查询
- **类型安全**：基于接口的设计，提供编译时安全检查
- **自动 SQL 日志**：内置 SQL 执行日志记录，带跟踪 ID
- **性能追踪**：记录执行时间、受影响行数和当前已获取行数
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

每个连接只需在创建第一个查询之前注册一次。库本身不会创建、打开或释放连接：它只记住你交给它的
`TFDConnection`，连接的所有权始终属于窗体（或数据模块）上的那个组件。

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

几条规则能让这套配置始终可预期：

- **必须先注册，再创建查询。** `NewQuery` 会立刻绑定连接，对未注册的键创建查询会抛出
  `Database connection not registered for key N`。在 `FormCreate`（或数据模块的 `OnCreate`）里注册一次
  即可覆盖整个程序。
- **同一个键重复注册是覆盖。** 重连或重启后再注册一次不会有副作用，注册表里也永远不会出现重复项。
- **键用于标识连接，名称只出现在 SQL 日志里。** 桥接层按枚举推导名称，所以 `cnnMain` 在日志里显示为
  `[conMain]`；如果改用核心层不带名称的重载注册，名称会退化为键的文本，这也是日志里出现 `[0]` 的原因。
- **枚举顺序必须保持稳定。** `TProjectDbConnKey` 以 `Ord(AConnKey)` 传给核心层，因此新增键只能追加在
  末尾，插在中间会静默改变已有键所绑定的连接。
- **注销是可选的。** `UnregisterDbConnection(key)` 和 `ClearDbConnections` 只删除注册表条目，不会动你的
  `TFDConnection` 组件。

### 2. 参数化查询

```delphi
// 数据集绑定期间，将查询接口保存为窗体字段。
type
  TForm1 = class(TForm)
  private
    FQuery: IFastQuery;
  end;

procedure TForm1.LoadStudents;
begin
  FQuery := NewQuery(cnnMain);
  FQuery.SQL('SELECT * FROM students WHERE student_no=:stn AND name=:name')
   .Param('stn', '2023001')
   .Param('name', '张晨')
   .Open;

  DataSource1.DataSet := FQuery.DataSet;
end;
```

只要控件或 `TDataSource` 仍在使用该数据集，就必须保持 `FQuery` 存活。
返回的 `TFDQuery` 由 `IFastQuery` 所有，并会随接口一起销毁。

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
   .SQL('SELECT * FROM students WHERE class_name=:cname')
   .Param('cname', '软件工程1班')
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
| `Open` | 执行 SELECT 查询并打开数据集，不强制获取全部记录 |
| `Exec: Integer` | 执行非查询 SQL，返回受影响的行数 |
| `DataSet: TFDQuery` | 获取内部持有的 TFDQuery；使用期间必须保持 IFastQuery 引用存活 |

### 连接管理

| 函数 | 描述 |
|------|------|
| `RegisterDbConnection(const AConnKey: TFastQueryConnKey; const AConnName: string; AConnection: TFDConnection)` | 按键注册连接，并指定日志中显示的名称 |
| `RegisterDbConnection(const AConnKey: TFastQueryConnKey; AConnection: TFDConnection)` | 同上，名称缺省为键的文本（日志中显示为 `[0]`） |
| `UnregisterDbConnection(const AConnKey: TFastQueryConnKey)` | 注销一个注册项（不释放连接） |
| `ClearDbConnections` | 清除所有注册项（不释放连接） |
| `DbConnKeyToString(const AConnKey: TFastQueryConnKey)` | 获取已注册连接的显示名称；未注册时返回键的文本 |

### SQL 日志

| 函数 | 描述 |
|------|------|
| `SetSqlLogger(const ALogger: ISqlLogger)` | 设置自定义 SQL 日志记录器 |
| `GetSqlLogger: ISqlLogger` | 获取当前 SQL 日志记录器（如未设置则创建默认的） |

## SQL 日志

库包含自动 SQL 日志功能，记录：

- SQL 语句和参数
- 执行时间（毫秒）
- `Exec` 的受影响行数，或 `Open` 当前已获取的行数
- 用于请求关联的跟踪 ID
- 执行失败时的错误信息

日志文件保存在：`logs\sql\{YYYYMMDD}.log`

日志采用尽力记录策略。日志记录器失败不会阻止 SQL 执行，也不会覆盖原始的数据库异常。

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

窗体上的三个按钮分别对应这些场景：**Grid1** 执行带参数的查询并显示在第一个表格中，**Grid2** 通过
`TFDMemTable` 做一次文件往返（会在 exe 同级目录写临时文件 `tmp` / `tmp.fds`），**Memo** 逐行遍历
`students` 表。

示例的连接参数写在 `FastQuery.dfm` 里，并且是绝对路径
`D:\JQSoft\Code\FDFastQuery\student_demo.db`。移动或重命名仓库后，需要到 IDE 中修改该路径，否则示例
无法运行。

## 常见问题

- **抛出 `Database connection not registered for key 0`** —— 在 `RegisterProjectDbConnection` 执行之前
  就创建了查询，或者查询使用的键与注册的键不一致。
- **日志里的连接名是 `[0]` 而不是 `[conMain]`** —— 该连接是通过核心层不带名称的重载注册的。想让日志里
  出现可读的连接名，请使用 `RegisterProjectDbConnection`，或带名称的三参数 `RegisterDbConnection`。
- **加载后表格立刻变空** —— 持有数据集的 `IFastQuery` 被释放了（例如它是个局部变量）。数据集在使用期间
  必须把它保存在字段里。

## 系统要求

- Delphi XE2 或更高版本
- FireDAC 组件
- Windows 平台

## 许可证

MIT License
