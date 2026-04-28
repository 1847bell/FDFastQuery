# FDFastQuery

**中文文档**: [README_CN](https://github.com/1847bell/FDFastQuery/blob/main/README_CN.md)

FDFastQuery is a lightweight and efficient FireDAC query wrapper library for Delphi that provides a fluent, chainable API for database operations.

## Features

- **Fluent Chainable API**: Build queries with intuitive method chaining
- **Type-Safe**: Compile-time safety with interface-based design
- **Automatic SQL Logging**: Built-in SQL execution logging with trace IDs
- **Performance Tracking**: Automatically records execution time and row counts
- **Connection Management**: Centralized database connection registry
- **Zero Configuration**: Ready to use with minimal setup

## Core Components

### IFD.FastQuery.pas
The core interface unit that provides:

- `IFastQuery` - Main query interface with chainable methods
- `ISqlLogger` - SQL logging interface
- Connection registration and management utilities
- Built-in file-based SQL logger

### ProjectFastQueryBridge.pas
Project-specific bridge layer that wraps the core library:

- `TProjectDbConnKey` - Project-specific connection keys (cnnMain, cnnChild)
- `RegisterProjectDbConnection` - Helper for registering project connections
- `NewQuery` - Factory method for creating queries

## Installation

1. Add `IFD.FastQuery.pas` and `ProjectFastQueryBridge.pas` to your project
2. Add references to required units:
   - `System.SysUtils`
   - `System.Classes`
   - `System.Variants`
   - `Data.DB`
   - `FireDAC.Comp.Client`
   - `FireDAC.Stan.Option`
   - `FireDAC.Stan.Param`

## Quick Start

### 1. Register Database Connection

```delphi
uses
  IFD.FastQuery, ProjectFastQueryBridge;

procedure TForm1.FormCreate(Sender: TObject);
begin
  // Register main connection
  RegisterProjectDbConnection(cnnMain, FDConnection1);

  // Register additional connections if needed
  RegisterProjectDbConnection(cnnChild, FDConnection2);
end;
```

### 2. Query with Parameters

```delphi
// Simple query with parameters
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

### 3. Execute Non-Query SQL

```delphi
// Execute INSERT/UPDATE/DELETE
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

### 4. Chain Multiple Operations

```delphi
// Reuse query object
var
  Q: IFastQuery;
begin
  Q := NewQuery(cnnMain);

  // First query
  Q.SQL('SELECT * FROM courses WHERE course_code=:code')
   .Param('code', 'C101')
   .Open;

  // Process results...

  // Clear and reuse
  Q.Clear
   .SQL('SELECT * FROM students WHERE class_id=:cid')
   .Param('cid', 101)
   .Open;
end;
```

## API Reference

### IFastQuery Interface

| Method | Description |
|--------|-------------|
| `SQL(const ASQL: string)` | Set SQL statement and clear previous state |
| `Add(const ASQL: string)` | Add SQL text to existing SQL |
| `Param(const AName: string; const AValue: Variant)` | Set parameter value |
| `Clear` | Clear SQL and parameters |
| `Close` | Close query if open |
| `Open` | Execute SELECT query and open dataset |
| `Exec: Integer` | Execute non-query SQL, returns rows affected |
| `DataSet: TFDQuery` | Get underlying TFDQuery object |

### Connection Management

| Function | Description |
|----------|-------------|
| `RegisterDbConnection(const AConnKey: TFastQueryConnKey; AConnection: TFDConnection)` | Register connection by key |
| `UnregisterDbConnection(const AConnKey: TFastQueryConnKey)` | Unregister connection |
| `ClearDbConnections` | Clear all registered connections |
| `DbConnKeyToString(const AConnKey: TFastQueryConnKey)` | Get connection name |

### SQL Logging

| Function | Description |
|----------|-------------|
| `SetSqlLogger(const ALogger: ISqlLogger)` | Set custom SQL logger |
| `GetSqlLogger: ISqlLogger` | Get current SQL logger (creates default if not set) |

## SQL Logging

The library includes automatic SQL logging that records:

- SQL statement and parameters
- Execution time in milliseconds
- Number of rows affected
- Trace ID for request correlation
- Error messages if execution fails

Log files are saved to: `logs\sql\{YYYYMMDD}.log`

Example log entry:
```
[2026-04-28 16:30:45.123] [START] [TraceId=20260428163045123_0001] [conMain] [OPEN] SQL=SELECT * FROM students WHERE id=:id PARAMS=id=123
[2026-04-28 16:30:45.156] [END] [TraceId=20260428163045123_0001] [conMain] [OPEN] ROWS=1 ELAPSED=33ms SQL=SELECT * FROM students WHERE id=:id PARAMS=id=123
```

### Custom Logger

Implement `ISqlLogger` interface for custom logging:

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

// Set custom logger
SetSqlLogger(TMySqlLogger.Create);
```

## Demo Project

The included demo (`FastQuery.pas`) demonstrates:

- Registering database connections
- Querying with parameters
- Loading data into memory tables
- Iterating through query results

## Requirements

- Delphi XE2 or later
- FireDAC components
- Windows platform

## License

MIT License
