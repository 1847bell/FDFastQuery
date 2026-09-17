# AGENTS.md（中文）

**英文原版**: [AGENTS.md](AGENTS.md)

## 项目简介

FDFastQuery 是一个体量很小的 Delphi（RAD Studio XE7、VCL）库，用接口式的链式 API 封装 FireDAC。
真正对外交付的是两个单元，使用者把它们加进自己的工程；仓库里的应用程序只是这两个单元的演示。

- `IFD.FastQuery.pas` — 库本体：`IFastQuery`（可链式调用的查询）、`ISqlLogger`、连接注册表，以及内置的
  文件日志器。必须保持不依赖 VCL，也不依赖任何第三方组件。
- `ProjectFastQueryBridge.pas` — 核心之上的项目级薄封装：`TProjectDbConnKey`（`cnnMain`、`cnnChild`）、
  `RegisterProjectDbConnection`、`NewQuery`。
- `FDFastQuery.dpr` + `FastQuery.pas` / `FastQuery.dfm` — Win32 VCL 演示程序（窗体 `TForm2`）；这是唯一
  允许出现 EhLib / DevExpress / `TFDMemTable` 的地方。
- `student_demo.db` — SQLite 演示数据库（`students` / `courses` / `grades`），由 Git LFS 跟踪。
- `README.md` 与 `README_CN.md` — 英文与中文文档，二者互为镜像，需要同步维护。

## 构建与验证

仓库没有测试套件；能否编译通过库单元是唯一可用的检查手段。

本机安装的是 XE7，路径为 `D:\Program Files (x86)\Embarcadero\Studio\15.0`（编译器版本 28.0）。Win32
编译器 `dcc32.exe` 在这台机器上是个坏掉的壳程序（无法启动 `dcc32compiler.exe`），所以
`msbuild FDFastQuery.dproj` 以及命令行的 Win32 构建都会失败 —— 请在 Delphi IDE 中构建并运行演示程序
（平台 Win32，配置 `Debug`）。产物输出到 `Win32\Debug`（已被 gitignore），SQL 日志输出到
`Win32\Debug\logs\sql\`。

要检查两个库单元能否编译，请使用可正常工作的 Win64 编译器，并把 `.dcu` 输出到仓库之外：

    "D:\Program Files (x86)\Embarcadero\Studio\15.0\bin\dcc64.exe" -Q -M \
      -N0"C:\Users\<你的用户名>\AppData\Local\Temp\dcuchk\\" \
      IFD.FastQuery.pas ProjectFastQueryBridge.pas

`-N0` 必须使用 Windows 原生路径并以 `\` 结尾，否则编译器会以 F2039 报错停止。该编译器是中文语言包的
版本，部分诊断信息正文为空；只有 error 需要关心。dproj 里的包列表（EhLib 7.0、DevExpress RS21、
FastReport、madExcept、Raize、HyControl）来自 IDE 中已安装的组件包 —— 不要改动它。

行为改动要通过运行演示程序的按钮来验证：Grid1 = 带参数的表格查询，Grid2 = `TFDMemTable` 文件往返，
Memo = 逐行遍历。注意 Grid2 会在 exe 同级目录写临时文件 `tmp` / `tmp.fds`。

## 架构约束

- 库只能使用 `System.*`、`Data.DB`、`FireDAC.*` 和 `Winapi.Windows`。它按设计就是 Windows 专用的
  （`GetTickCount`、`InterlockedIncrement`），也不得引入 VCL、EhLib 或其它第三方依赖 —— 那会破坏它作为
  “拷进工程就能用”的单元的价值。
- 库从不拥有连接：`RegisterDbConnection` 只保存 `TFDConnection` 引用，`UnregisterDbConnection` /
  `ClearDbConnections` 只释放注册表条目，绝不释放连接本身。而 `TFDQuery` 是由 `TFastQuery` 拥有的
  （以 `nil` 为 Owner 创建，在析构函数中释放），因此调用方必须让 `IFastQuery` 引用在它的 `DataSet`
  绑定到表格或 `TDataSource` 期间保持存活。
- 全局状态是 `IFD.FastQuery.pas` 的单元级变量（`GConnectionItems`、`GSqlLogger`、`GTraceSeed`），在
  `initialization` 中创建、在 `finalization` 中释放。连接以 `IntToStr(AConnKey)` 为键，而桥接层传的是
  `Ord(TProjectDbConnKey)`，所以该枚举只能**在末尾追加**：调整顺序会静默改变连接绑定，也会改变日志中
  出现的连接名。日志用的名称在注册时一次性确定（`NormalizeConnName`，名称为空则退化为键的文本），读取
  统一走 `ConnectionDisplayName`；`TFastQuery.BindConnection` 通过一次 `TDbConnResolver.ResolveItem`
  同时取出名称和连接，不要改回“同一个键查两遍注册表”的写法。
- 所有日志都走 `TryLog*` 包装函数。日志是尽力而为的：要吞掉日志器自身的异常，绝不能掩盖原始的数据库
  异常，也绝不能因为写日志失败而中断查询。请保持 `[START]` / `[END]` / `[ERROR]` 的行格式稳定（该格式
  记录在 README 中）。
- `Open` 保持惰性取数（`RecordCountMode = cmFetched`），因此 `RecordCount` 以及 OPEN 日志里的 `ROWS`
  表示“当前已取到的行数”，而不是完整结果集。不要加入任何会强制完整取数的东西。

## 编码约定

- Delphi 命名：类型用 `T` / `I`，字段用 `F`，局部变量用 `L`，参数用 `A`，单元级全局变量用 `G`。可链式
  调用的方法通过 `AsInterface` 返回 `IFastQuery`；`Exec: Integer` 返回受影响行数。
- 新增库单元使用 `IFD.` 前缀；注释和标识符一律使用英文。
- 公开 API 或日志格式的改动必须同时更新 `README.md` 和 `README_CN.md`。
- `FastQuery.dfm` 里写死了 `Database=D:\JQSoft\Code\FDFastQuery\student_demo.db`；一旦移动或重命名
  仓库，演示程序就会失效，需要到 IDE 中修改这个路径。
- README 的链式查询示例过滤的是 `students.class_id`，但演示库里只有 `class_name` —— 示例本身是错的，
  应修正它而不是照抄。

## 仓库卫生

`*.exe`、`*.res`、`*.db` 由 Git LFS 跟踪，所以新克隆的仓库必须先安装 `git lfs` 才能得到可用的
`student_demo.db`。`Win32\Debug`、`__history`、`*.identcache`、`*.local`、`*.res`、`*.skincfg` 都是被
gitignore 的生成物；`__history` 里是 IDE 的过期备份副本，不要编辑它们。被跟踪的文件刻意保持很少：
`.dpr` / `.dproj`、三个 `.pas` 单元、演示用的 `.dfm`、文档、许可证和演示数据库。

## 文档

本文件是英文版 [AGENTS.md](AGENTS.md) 的中文镜像，两者内容应保持一致；如有分歧，以英文版为准。
