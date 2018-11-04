{ ******************************************************* }
{                                                         }
{ XVM                                                     }
{                                                         }
{ ��Ȩ���� (C) 2012 adsj                                  }
{                                                         }
{ �汾0.8                                                 }
{                                                         }
{ bug  ���ú���֮���ջ�仯���²���������ִ�������ָ��   }
{ ******************************************************* }

unit XVMProtoUnit;

interface

uses
  System.SysUtils, System.Classes, Winapi.Windows, XVMHead, codesitelogging;

const
  // ----File I/O--------------------
  EXEX_FILE_EXT = '.XSE';
  XSE_ID_STRING = 'XSE0';
  // ----LoadScript() Error Codes----
  XS_LOAD_OK = 0;
  XS_LOAD_ERROR_FILE_IO = 1;
  XS_LOAD_ERROR_INVALID_XSE = 2;
  XS_LOAD_ERROR_UNSUPPORTED_VERS = 3;
  XS_LOAD_ERROR_OUT_OF_MEMORY = 4; // �ڴ�������
  XS_LOAD_ERROR_OUT_OF_THREADS = 5; // ȱ�ٿ����߳�
  // ----Operand Types-----------------
  OP_TYPE_NULL = -1;
  OP_TYPE_INT = 0;
  OP_TYPE_FLOAT = 1;
  OP_TYPE_STRING = 2;
  OP_TYPE_ABS_STACK_INDEX = 3;
  OP_TYPE_REL_STACK_INDEX = 4;
  OP_TYPE_INSTR_INDEX = 5;
  OP_TYPE_FUNC_INDEX = 6;
  OP_TYPE_HOST_API_CALL_INDEX = 7;
  OP_TYPE_REG = 8;

  OP_TYPE_STACK_BASE_MARKER = 9;
  // ----Instruction Opcodes-----------
  INSTR_MOV = 0;
  INSTR_ADD = 1;
  INSTR_SUB = 2;
  INSTR_MUL = 3;
  INSTR_DIV = 4;
  INSTR_MOD = 5;
  INSTR_EXP = 6;
  INSTR_NEG = 7;
  INSTR_INC = 8;
  INSTR_DEC = 9;

  INSTR_AND = 10;
  INSTR_OR = 11;
  INSTR_XOR = 12;
  INSTR_NOT = 13;
  INSTR_SHL = 14;
  INSTR_SHR = 15;

  INSTR_CONCAT = 16;
  INSTR_GETCHAR = 17;
  INSTR_SETCHAR = 18;

  INSTR_JMP = 19;
  INSTR_JE = 20;
  INSTR_JNE = 21;
  INSTR_JG = 22;
  INSTR_JL = 23;
  INSTR_JGE = 24;
  INSTR_JLE = 25;

  INSTR_PUSH = 26;
  INSTR_POP = 27;

  INSTR_CALL = 28;
  INSTR_RET = 29;
  INSTR_CALLHOST = 30;

  INSTR_PAUSE = 31;
  INSTR_EXIT = 32;
  // ----Stack-----------------
  DEF_STACK_SIZE = 1024;
  // ----Coercion--------------
  MAX_COERCION_STRING_SIZE = 65;
  // ----���߳�֧��------------
  // ����߳�
  MAX_THREAD_COUNT = 1024;
  THREAD_MODE_MULTI = 0;
  THREAD_MODE_SINGLE = 1;

  XS_THREAD_PRIORITY_USER = 0;
  XS_THREAD_PRIORITY_LOW = 1;
  XS_THREAD_PRIORITY_MED = 2;
  XS_THREAD_PRIORITY_HIGH = 3;

  XS_INFINITE_TIMESLICE = -1;

  THREAD_PRIORITY_DUR_LOW = 20;
  THREAD_PRIORITY_DUR_MED = 40;
  THREAD_PRIORITY_DUR_HIGH = 80;
  // ��Ӧ�ó����� c pascal
  MAX_HOST_API_SIZE = 1024;
  // ȫ�ֺ���
  XS_GLOBAL_FUNC = -1;

  // ----Data Structures-------
  // ----����ʱֵ-----
type
  _Value = record
    iType: Integer; // ����
    iOffsetIndex: Integer; // ����ƫ����
    case Integer of // ֵ
      0:
        (iIntLiteral: Integer); // ����������
      1:
        (fFloatLiteral: Single); // ������������
      2:
        (pstrStringLiteral: PAnsiChar); // �ַ���������
      3:
        (iStackIndex: Integer); // ��ջ����
      4:
        (iInstrIndex: Integer); // ָ������
      5:
        (iFuncIndex: Integer); // ��������
      6:
        (iHostAPICallIndex: Integer); // ��Ӧ�ó���API��������
      7:
        (iReg: Integer); // �Ĵ�����
  end;

  Value = _Value;
  pValue = ^Value;
  ValueArray = array of Value;

  // ----Runtime Stack--------------
  // ����ʱ��ջ
type
  _RuntimeStack = record
    pElmnts: ValueArray; // ��ջԪ��
    iSize: Integer; // ��ջ��Ԫ�ظ���
    iTopIndex: Integer; // ջ������
    iFrameIndex: Integer; // ��ǰ��ջ��ܶ�������
  end;

  RuntimeStack = _RuntimeStack;

  // ----Functions-----------------
  // ������
type
  _Func = record
    iEntryPoint: Integer; // ��ڵ�
    iParamCount: Integer; // ��Ҫ�Ĳ�������
    iLocalDataSize: Integer; // ���оֲ������ܴ�С
    iStackFrameSize: Integer; // ��ջ����ܴ�С
    pstrName: PAnsiChar; // The function's name
  end;

  Func = _Func;
  pFunc = ^Func;

type
  FuncArr = array of Func;

  // ----Instructions--------------
  // ָ��
type
  _Instr = record
    iOpcode: Integer; // ������
    iOpCount: Integer; // �������ĸ���
    pOpList: ValueArray; // �������б�
  end;

  Instr = _Instr;
  pInstr = ^Instr;

  // ָ����
  _InstrStream = record
    pInstrs: array of Instr; // ָ��
    iSize: Integer; // ָ�����е�ָ������
    iCurrInstr: Integer; // ��ǰָ��ָ��
  end;

  InstrStream = _InstrStream;

  // ----Function Table-----------
type
  _FuncTable = record
    pFuncs: FuncArr; // ��������
    iSize: Integer; // ������Ŀ
  end;

  FuncTable = _FuncTable;

  // ----Host API Call Table------
  // ��Ӧ�ó���API���ñ�
type
  _HostAPICallTable = record
    ppstrCalls: PPAnsiChar; // ָ����������ָ��
    iSize: Integer; // �����е��ø���
  end;

  HostAPICallTable = _HostAPICallTable;

  // ----��Ӧ�ó���API����
  // typedef void ( * a ) ( int b );
type
  HostAPIFuncPntr = procedure(iThreadIndex: Integer);

type
  _HostAPIFunc = record
    iIsActive: Integer; // �ú����Ƿ�ʹ��
    iThreadIndex: Integer; // �����Ǹ��̺߳�������
    pstrName: PAnsiChar; // ������
    fnFunc: HostAPIFuncPntr; // ָ���������ָ��
  end;

  HostAPIFunc = _HostAPIFunc;

  // ----Scripts-------------------
type
  _Script = record
    iIsActive: Integer; // �Ƿ���ʹ������ű�
    // Head data
    iGlobalDataSize: Integer; // �ű�ȫ�����ݴ�С
    iIsMainFuncPresent: Integer; // _Main �����Ƿ����
    iMainFuncIndex: Integer; // _Main����
    // Runtime tracking
    iIsRunning: Integer; // �Ƿ�������
    iIsPaused: Integer; // ��ǰ�ű��Ƿ���ͣ
    iPauseEndTime: Integer; // �������ͣ,ʲôʱ�����
    iTimesliceDur: Integer; // The thread's timeslice duration
    // Register file
    _RetVal: Value; // _RetVal�Ĵ���
    // Script data
    InstrStream: InstrStream; // ָ����
    Stack: RuntimeStack; // ����ʱ��ջ
    FuncTable: FuncTable; // ������
    HostAPICallTable: HostAPICallTable; // ��Ӧ�ó���API���ñ�
  end;

  Script = _Script;

  // ----Globals----------------------
  // ----Scripts----------------------
var
  // g_Script: Script;
  // ���߳�֧��
  g_Scripts: array [0 .. MAX_THREAD_COUNT - 1] of Script;
  g_iCurrThread: Integer;
  g_iCurrThreadActiveTime: Integer;
  g_iCurrThreadMode: Integer; // �߳�ģʽ
  // ��Ӧ�ó���API
  g_HostAPI: array [0 .. MAX_HOST_API_SIZE - 1] of HostAPIFunc;
  // ----Instruction
  ppstrMnemonics: array [0 .. 32] of AnsiString = (
    'Mov',
    'Add',
    'Sub',
    'Mul',
    'Div',
    'Mod',
    'Exp',
    'Neg',
    'Inc',
    'Dec',
    'And',
    'Or',
    'XOr',
    'Not',
    'ShL',
    'ShR',
    'Concat',
    'GetChar',
    'SetChar',
    'Jmp',
    'JE',
    'JNE',
    'JG',
    'JL',
    'JGE',
    'JLE',
    'Push',
    'Pop',
    'Call',
    'Ret',
    'CallHost',
    'Pause',
    'Exit'
  );
  // ----Function Prototypes-----------
procedure PrintLogo();
// ----Main--------------------------
procedure XS_Init();
procedure XS_ShutDown();
// ----Script Interface--------------
function XS_LoadScript(pstrFilename: PAnsiChar; var iThreadIndex: Integer;
  var iThreadTimeslice: Integer): Integer;
procedure XS_UnloadScript(iThreadIndex: Integer);
procedure XS_ResetScript(iThreadIndex: Integer);
procedure XS_RunScripts(iTimesliceDur: Integer);
/// / ----Operand Interface-------------
function CoerceValueToInt(val: Value): Integer;
function CoerceValueToFloat(val: Value): Single;
function CoerceValueToString(val: Value): PAnsiChar;

procedure CopyValue(pDest: pValue; Source: Value);

function GetOpType(iOpIndex: Integer): Integer;
//
function ResolveOpStackIndex(iOpIndex: Integer): Integer;
function ResolveStackIndex(iIndex: Integer): Integer; // ��
function ResolveOpValue(iOpIndex: Integer): Value;
function ResolveOpType(iOpIndex: Integer): Integer;
function ResolveOpAsInt(iOpIndex: Integer): Integer;
function ResolveOpAsFloat(iOpIndex: Integer): Single;
function ResolveOpAsString(iOpIndex: Integer): PAnsiChar;
function ResolveOpAsInstrIndex(iOpIndex: Integer): Integer;
function ResolveOpAsFuncIndex(iOpIndex: Integer): Integer;
function ResolveOpAsHostAPICall(iOpIndex: Integer): PAnsiChar;
function ResolveOpPntr(iOpIndex: Integer): pValue;
/// / ----Runtime Stack Interface----------
function GetStackValue(iThreadIndex: Integer; iIndex: Integer): Value;
procedure SetStackValue(iThreadIndex: Integer; iIndex: Integer; val: Value);
procedure Push(iThreadIndex: Integer; val: Value);
function Pop(iThreadIndex: Integer): Value;
procedure PushFrame(iThreadIndex: Integer; iSize: Integer);
procedure PopFrame(iSize: Integer);
/// / ----Function Table Interface---------
function GetFunc(iThreadIndex: Integer; iIndex: Integer): Func;
function GetFuncIndexByName(iThreadIndex: Integer; pstrName: PAnsiChar): Integer;
/// / ----Host API Call Table Interface----
function GetHostAPICall(iIndex: Integer): PAnsiChar;
/// / ----Printing Helper Functions--------
procedure PrintOpIndir(iOpIndex: Integer);
procedure PrintOpValue(iOpIndex: Integer);
/// / ----Time Abstraction-----------------
function GetCurrTime(): Integer;
procedure CallFunc(iThreadIndex: Integer; iIndex: Integer);
// interface
procedure XS_StartScript(iThreadIndex: Integer);
procedure XS_StopScript(iThreadIndex: Integer);
procedure XS_PauseScript(iThreadIndex: Integer; iDur: Integer);
procedure XS_UppauseScript(iThreadIndex: Integer);

procedure XS_PassIntParam(iThreadIndex: Integer; iInt: Integer);
procedure XS_PassFloatParam(iThreadIndex: Integer; fFloat: Single);
procedure XS_PassStringParam(iThreadIndex: Integer; pstrString: PAnsiChar);
procedure XS_CallScriptFunc(iThreadIndex: Integer; pstrName: PAnsiChar);
procedure XS_InvokeScriptFunc(iThreadIndex: Integer; pstrName: PAnsiChar);
function XS_GetReturnValueAsInt(iThreadIndex: Integer): Integer;
function XS_GetReturnValueAsFloat(iThreadIndex: Integer): Single;
function XS_GetReturnAsString(iThreadIndex: Integer): PAnsiChar;
// ----��Ӧ�ó���API�ӿ�
procedure XS_RegisterHostAPIFunc(iThreadIndex: Integer; pstrName: PAnsiChar;
  fnFunc: HostAPIFuncPntr);
// ��������
function XS_GetParamAsInt(iThreadIndex: Integer; iParamIndex: Integer): Integer;
function XS_GetParamAsFloat(iThreadIndex: Integer; iParamIndex: Integer): Single;
function XS_GetParamAsString(iThreadIndex: Integer; iParamIndex: Integer): PAnsiChar;
// ----����ֵ
procedure XS_ReturnFromHost(iThreadIndex: Integer; iParamCount: Integer);
procedure XS_ReturnIntFromHost(iThreadIndex: Integer; iParamCount: Integer; iInt: Integer);
procedure XS_ReturnFloatFromHost(iThreadIndex: Integer; iParamCount: Integer; iFloat: Single);
procedure XS_ReturnStringFromHost(iThreadIndex: Integer; iParamCount: Integer;
  pstrString: PAnsiChar);

implementation

// ----Functions------------------------
// ----Misc--------------------------
procedure PrintLogo();
begin
  Writeln('XVM Prototype');
  Writeln('XtremeScript Virtual Machine Core Demo');
  Writeln('Written by Alex Varanese');
end;

// ----Main--------------------------
procedure XS_Init();
var
  iCurrScriptIndex: Integer;
  iCurrHostAPIFunc: Integer;
begin
  // initialize the script array
  for iCurrScriptIndex := 0 to MAX_THREAD_COUNT - 1 do
  begin
    g_Scripts[iCurrScriptIndex].iIsActive := 0;
    g_Scripts[iCurrScriptIndex].iIsRunning := 0;
    g_Scripts[iCurrScriptIndex].iIsMainFuncPresent := 0;
    g_Scripts[iCurrScriptIndex].iIsPaused := 0;

    g_Scripts[iCurrScriptIndex].InstrStream.pInstrs := nil;
    g_Scripts[iCurrScriptIndex].Stack.pElmnts := nil;
    g_Scripts[iCurrScriptIndex].FuncTable.pFuncs := nil;
    g_Scripts[iCurrScriptIndex].HostAPICallTable.ppstrCalls := nil;
  end;
  // initialize the host API
  for iCurrHostAPIFunc := 0 to MAX_HOST_API_SIZE - 1 do
  begin
    g_HostAPI[iCurrHostAPIFunc].iIsActive := 0;
    g_HostAPI[iCurrHostAPIFunc].pstrName := nil;
  end;

  // set up the threads
  g_iCurrThreadMode := THREAD_MODE_MULTI;
  g_iCurrThread := 0;
end;

procedure XS_ShutDown();
var
  iCurrScriptIndex: Integer;
  iCurrHostAPIFunc: Integer;
begin
  // unload any scripts that may still be in memory
  for iCurrScriptIndex := 0 to MAX_THREAD_COUNT - 1 do
  begin
    XS_UnloadScript(iCurrScriptIndex);
  end;

  // free the host api's function name
  for iCurrHostAPIFunc := 0 to MAX_HOST_API_SIZE - 1 do
  begin
    if Assigned(g_HostAPI[iCurrHostAPIFunc].pstrName) then
    begin
      if StrLen(g_HostAPI[iCurrHostAPIFunc].pstrName) > 0 then
        FreeMem(g_HostAPI[iCurrHostAPIFunc].pstrName);
    end;
  end;
end;

// ----Script Interface--------------
function XS_LoadScript(pstrFilename: PAnsiChar; var iThreadIndex: Integer;
  var iThreadTimeslice: Integer): Integer;
var
  scf: THandle;
  pstrIDString: PAnsiChar;
  iMajorVersion: Integer;
  iMinorVersion: Integer;
  iCurrInstrIndex: Integer;
  iOpCount: Integer;
  pOpList: ValueArray;
  iCurrOpIndex: Integer;
  // string table
  iStringTableSize: Integer;
  iCurrStringIndex: Integer;
  iStringSize: Integer;
  pstrCurrString: PAnsiChar;
  iStringIndex: Integer;
  pstrStringCopy: PAnsiChar;
  ppstrStringTable: PPAnsiChar;
  // func table
  iFuncTableSize: Integer;
  iCurrFuncIndex: Integer;
  iEntryPoint: Integer;
  iParamCount: Integer;
  iLocalDataSize: Integer;
  iStackFrameSize: Integer;
  // Host API
  iCurrCallIndex: Integer;
  pstrCurrCall: PAnsiChar;
  iCallLength: Integer;
  // New
  iFreeThreadFound: Integer;
  iCurrThreadIndex: Integer;
  iPriortyType: Integer;
  iFuncNameLength: Integer;
  //
  testStr: AnsiString;

begin
  for iCurrThreadIndex := 0 to MAX_THREAD_COUNT - 1 do
  begin
    if g_Scripts[iCurrThreadIndex].iIsActive = 0 then
    begin
      iThreadIndex := iCurrThreadIndex;
      iFreeThreadFound := 1;
      Break;
    end;
  end;

  if iFreeThreadFound = 0 then
  begin
    Result := XS_LOAD_ERROR_OUT_OF_THREADS;
    Exit;
  end;
  // Open input file
  scf := FileOpen(pstrFilename, fmOpenRead);
  FileSeek(scf, 0, 0);
  // id 4
  GetMem(pstrIDString, 5 * sizeof(AnsiChar));
  FileRead(scf, pstrIDString^, 4);
  pstrIDString[Length(XSE_ID_STRING)] := #0;
  if StrComp(pstrIDString, PAnsiChar(AnsiString(XSE_ID_STRING))) <> 0 then
  begin
    Result := XS_LOAD_ERROR_INVALID_XSE;
    Exit;
  end;
  FreeMem(pstrIDString);
  // version 2
  iMajorVersion := 0;
  iMinorVersion := 0;
  FileRead(scf, iMajorVersion, 1);
  FileRead(scf, iMinorVersion, 1);
  if (iMajorVersion <> 0) or (iMinorVersion <> 8) then
  begin
    Result := XS_LOAD_ERROR_UNSUPPORTED_VERS;
    Exit;
  end;
  // stacks size 4
  FileRead(scf, g_Scripts[iThreadIndex].Stack.iSize, 4);
  if g_Scripts[iThreadIndex].Stack.iSize = 0 then
    g_Scripts[iThreadIndex].Stack.iSize := DEF_STACK_SIZE;
  // ��������ʱ��ջ
  try
    setLength(g_Scripts[iThreadIndex].Stack.pElmnts, g_Scripts[iThreadIndex].Stack.iSize);
  except
    Result := XS_LOAD_ERROR_OUT_OF_MEMORY;
    Exit;
  end;
  // ��ȡȫ�����ݴ�С 4
  FileRead(scf, g_Scripts[iThreadIndex].iGlobalDataSize, 4);
  // ���Main����    1
  FileRead(scf, g_Scripts[iThreadIndex].iIsMainFuncPresent, 1);
  // ��ȡMain��������  4
  FileRead(scf, g_Scripts[iThreadIndex].iMainFuncIndex, 4);
  // Read the priority 1
  iPriortyType := 0;
  FileRead(scf, iPriortyType, 1);
  // read the user-defined priority 4
  FileRead(scf, g_Scripts[iThreadIndex].iTimesliceDur, 4);
  // override the script-specified priorty if necessary
  if iThreadTimeslice <> XS_THREAD_PRIORITY_USER then
    iPriortyType := iThreadTimeslice;
  case iPriortyType of
    XS_THREAD_PRIORITY_LOW:
      begin
        g_Scripts[iThreadIndex].iTimesliceDur := THREAD_PRIORITY_DUR_LOW;
      end;
    XS_THREAD_PRIORITY_MED:
      begin
        g_Scripts[iThreadIndex].iTimesliceDur := THREAD_PRIORITY_DUR_MED;
      end;
    XS_THREAD_PRIORITY_HIGH:
      begin
        g_Scripts[iThreadIndex].iTimesliceDur := THREAD_PRIORITY_DUR_HIGH;
      end;
  end;
  //
  // ��ȡָ����
  // ��ȡָ�����
  FileRead(scf, g_Scripts[iThreadIndex].InstrStream.iSize, 4);
  // ����ָ����
  try
    setLength(g_Scripts[iThreadIndex].InstrStream.pInstrs,
      g_Scripts[iThreadIndex].InstrStream.iSize);
  except
    Result := XS_LOAD_ERROR_OUT_OF_MEMORY;
    Exit;
  end;

  for iCurrInstrIndex := 0 to g_Scripts[iThreadIndex].InstrStream.iSize - 1 do
  begin
    // ��ȡ������  2
    g_Scripts[iThreadIndex].InstrStream.pInstrs[iCurrInstrIndex].iOpcode := 0;
    FileRead(scf, g_Scripts[iThreadIndex].InstrStream.pInstrs[iCurrInstrIndex].iOpcode, 2);
    // ��ȡ���������� 1
    g_Scripts[iThreadIndex].InstrStream.pInstrs[iCurrInstrIndex].iOpCount := 0;
    FileRead(scf, g_Scripts[iThreadIndex].InstrStream.pInstrs[iCurrInstrIndex].iOpCount, 1);
    iOpCount := g_Scripts[iThreadIndex].InstrStream.pInstrs[iCurrInstrIndex].iOpCount;
    // Ϊ�������б����ռ�
    try
      setLength(pOpList, iOpCount);
    except
      Result := XS_LOAD_ERROR_OUT_OF_MEMORY;
      Exit;
    end;
    // ����������б�
    for iCurrOpIndex := 0 to iOpCount - 1 do
    begin
      // �������������
      pOpList[iCurrOpIndex].iType := 0;
      FileRead(scf, pOpList[iCurrOpIndex].iType, 1);
      // ���ݲ��������ͣ��������������
      case pOpList[iCurrOpIndex].iType of
        OP_TYPE_INT:
          begin
            FileRead(scf, pOpList[iCurrOpIndex].iIntLiteral, sizeof(Integer));
          end;
        OP_TYPE_FLOAT:
          begin
            FileRead(scf, pOpList[iCurrOpIndex].fFloatLiteral, sizeof(Single))
          end;
        // �ַ�������
        OP_TYPE_STRING:
          begin
            // Value�ṹ��û���ʺ����ַ����������Ľṹ����ô�Ͱ�����
            // ���������������ֶΣ�����������������Ϊ�ַ�������
            FileRead(scf, pOpList[iCurrOpIndex].iIntLiteral, sizeof(Integer));
            pOpList[iCurrOpIndex].iType := OP_TYPE_STRING;
          end;
        // ָ������
        OP_TYPE_INSTR_INDEX:
          begin
            FileRead(scf, pOpList[iCurrOpIndex].iInstrIndex, sizeof(Integer));
          end;
        // ���Զ�ջ����
        OP_TYPE_ABS_STACK_INDEX:
          begin
            FileRead(scf, pOpList[iCurrOpIndex].iStackIndex, sizeof(Integer));
          end;
        // ��Զ�ջ����
        OP_TYPE_REL_STACK_INDEX:
          begin
            FileRead(scf, pOpList[iCurrOpIndex].iStackIndex, sizeof(Integer));
            FileRead(scf, pOpList[iCurrOpIndex].iOffsetIndex, sizeof(Integer));
          end;
        // ��������
        OP_TYPE_FUNC_INDEX:
          begin
            FileRead(scf, pOpList[iCurrOpIndex].iFuncIndex, sizeof(Integer));
          end;
        // ��Ӧ�ó���API��������
        OP_TYPE_HOST_API_CALL_INDEX:
          begin
            FileRead(scf, pOpList[iCurrOpIndex].iHostAPICallIndex, sizeof(Integer));
          end;
        // �Ĵ���
        OP_TYPE_REG:
          begin
            FileRead(scf, pOpList[iCurrOpIndex].iReg, sizeof(Integer));
          end;
      end;
    end;
    g_Scripts[iThreadIndex].InstrStream.pInstrs[iCurrInstrIndex].pOpList := pOpList;
  end;
  // �����ַ�����
  FileRead(scf, iStringTableSize, 4);
  if iStringTableSize > 0 then
  begin
    // Ϊ�ַ���������ڴ�
    try
      GetMem(ppstrStringTable, iStringTableSize * sizeof(PAnsiChar));
    except
      Result := XS_LOAD_ERROR_OUT_OF_MEMORY;
      Exit;
    end;
    // ��ȡ�����ַ���
    for iCurrStringIndex := 0 to iStringTableSize - 1 do
    begin
      inc(ppstrStringTable, iCurrStringIndex);
      FileRead(scf, iStringSize, 4);
      // Ϊ�ַ�������ռ�
      try
        GetMem(pstrCurrString, iStringSize * sizeof(AnsiChar) + 1);
      except
        Result := XS_LOAD_ERROR_OUT_OF_MEMORY;
        Exit;
      end;
      FileRead(scf, pstrCurrString^, iStringSize);
      pstrCurrString[iStringSize] := #0;
      // ���뵽�ַ�����
      ppstrStringTable^ := pstrCurrString;
      Dec(ppstrStringTable, iCurrStringIndex);
    end;
    // �����ַ�������
    for iCurrInstrIndex := 0 to g_Scripts[iThreadIndex].InstrStream.iSize - 1 do
    begin
      iOpCount := g_Scripts[iThreadIndex].InstrStream.pInstrs[iCurrInstrIndex].iOpCount;
      pOpList := g_Scripts[iThreadIndex].InstrStream.pInstrs[iCurrInstrIndex].pOpList;
      // ��ÿ��������ѭ��
      for iCurrOpIndex := 0 to iOpCount - 1 do
      begin
        // ��������������һ���ַ���������������ڱ�����Ӧ���ַ�����һ���ֲ�����
        if pOpList[iCurrOpIndex].iType = OP_TYPE_STRING then
        begin
          iStringIndex := pOpList[iCurrOpIndex].iIntLiteral;
          // ����һ���µ��ַ������ڴ�ű��е��Ǹ��ַ�������
          inc(ppstrStringTable, iStringIndex);
          try
            GetMem(pstrStringCopy, StrLen(ppstrStringTable^) + 1);
          except
            Result := XS_LOAD_ERROR_OUT_OF_MEMORY;
            Exit;
          end;
          StrCopy(pstrStringCopy, ppstrStringTable^);
          Dec(ppstrStringTable, iStringIndex);
          pOpList[iCurrOpIndex].pstrStringLiteral := pstrStringCopy;
        end;
      end;
    end;
    // �ͷ��ַ�����
    for iCurrStringIndex := 0 to iStringTableSize - 1 do
    begin
      inc(ppstrStringTable, iCurrStringIndex);
      FreeMem(ppstrStringTable^);
      Dec(ppstrStringTable, iCurrStringIndex);
    end;
    FreeMem(ppstrStringTable);
  end;

  // ��ȡ������
  FileRead(scf, iFuncTableSize, 4);
  // get memory
  g_Scripts[iThreadIndex].FuncTable.iSize := iFuncTableSize;
  try
    setLength(g_Scripts[iThreadIndex].FuncTable.pFuncs, iFuncTableSize);
  except
    Result := XS_LOAD_ERROR_OUT_OF_MEMORY;
    Exit;
  end;
  // ��ȡ����
  for iCurrFuncIndex := 0 to iFuncTableSize - 1 do
  begin
    FileRead(scf, iEntryPoint, 4);
    FileRead(scf, iParamCount, 1);
    FileRead(scf, iLocalDataSize, 4);

    iStackFrameSize := iParamCount + 1 + iLocalDataSize;
    FileRead(scf, iFuncNameLength, 1);

    GetMem(g_Scripts[iThreadIndex].FuncTable.pFuncs[iCurrFuncIndex].pstrName,
      iFuncNameLength * sizeof(AnsiChar) + 1);

    FileRead(scf, g_Scripts[iThreadIndex].FuncTable.pFuncs[iCurrFuncIndex].pstrName^,
      iFuncNameLength * sizeof(AnsiChar));
    g_Scripts[iThreadIndex].FuncTable.pFuncs[iCurrFuncIndex].pstrName[iFuncNameLength] := #0;
    // ���������뺯����
    g_Scripts[iThreadIndex].FuncTable.pFuncs[iCurrFuncIndex].iEntryPoint := iEntryPoint;
    g_Scripts[iThreadIndex].FuncTable.pFuncs[iCurrFuncIndex].iParamCount := iParamCount;
    g_Scripts[iThreadIndex].FuncTable.pFuncs[iCurrFuncIndex].iLocalDataSize := iLocalDataSize;
    g_Scripts[iThreadIndex].FuncTable.pFuncs[iCurrFuncIndex].iStackFrameSize := iStackFrameSize;
  end;

  // ��ȡHost API ��
  FileRead(scf, g_Scripts[iThreadIndex].HostAPICallTable.iSize, 4);
  // get memory
  try
    GetMem(g_Scripts[iThreadIndex].HostAPICallTable.ppstrCalls,
      g_Scripts[iThreadIndex].HostAPICallTable.iSize * sizeof(PAnsiChar));
  except
    Result := XS_LOAD_ERROR_OUT_OF_MEMORY;
    Exit;
  end;
  // ��ȡ
  for iCurrCallIndex := 0 to g_Scripts[iThreadIndex].HostAPICallTable.iSize - 1 do
  begin
    iCallLength := 0;
    FileRead(scf, iCallLength, 1);
    try
      GetMem(pstrCurrCall, (iCallLength + 1) * sizeof(AnsiChar));
    except
      Result := XS_LOAD_ERROR_OUT_OF_MEMORY;
      Exit;
    end;

    FileRead(scf, pstrCurrCall^, iCallLength);
    pstrCurrCall[iCallLength] := #0;
    inc(g_Scripts[iThreadIndex].HostAPICallTable.ppstrCalls, iCurrCallIndex);
    g_Scripts[iThreadIndex].HostAPICallTable.ppstrCalls^ := pstrCurrCall;
    Dec(g_Scripts[iThreadIndex].HostAPICallTable.ppstrCalls, iCurrCallIndex);
  end;
  // �ر��ļ�
  FileClose(scf);

  g_Scripts[iThreadIndex].iIsActive := 1;
  XS_ResetScript(iThreadIndex);
  Result := XS_LOAD_OK;
  // ��ӡ��Ϣ
  Writeln(Format('%s loaded successfully!', [pstrFilename]));
  Writeln;
  Writeln(Format('       Thread ID: %d', [iThreadIndex]));
  Writeln(Format('  Format Version: %d.%d', [iMajorVersion, iMinorVersion]));
  Writeln(Format('      Stack Size: %d', [g_Scripts[iThreadIndex].Stack.iSize]));
  Writeln(Format('Global Data Size: %d', [g_Scripts[iThreadIndex].iGlobalDataSize]));
  Writeln(Format('       Functions: %d', [iFuncTableSize]));

  Write('_Main () Present:');
  if g_Scripts[iThreadIndex].iIsMainFuncPresent <> 0 then
    Writeln(Format(' Yes (Index %d)', [g_Scripts[iThreadIndex].iMainFuncIndex]))
  else
    Writeln(' No');
  Writeln(Format('  Host API Calls: %d', [g_Scripts[iThreadIndex].HostAPICallTable.iSize]));
  Writeln(Format('    Instructions: %d', [g_Scripts[iThreadIndex].InstrStream.iSize]));
  Writeln(Format(' String Literals: %d', [iStringTableSize]));
end;

// function KeyPressed(aHandle: THandle): boolean;
// var
// Msg: TMsg;
// begin
// if PeekMessage(Msg, aHandle, WM_KEYFIRST,WM_KEYLAST,
// PM_REMOVE) then
// begin
// TranslateMessage(Msg);
// DispatchMessage(Msg);
// Result := true;
// end
// else Result := false;
// end;

procedure XS_UnloadScript(iThreadIndex: Integer);
var
  iCurrInstrIndex: Integer;
  iOpCount: Integer;
  iCurrOpIndex: Integer;
  iCurrElmntnIndex: Integer;
  iCurrCallIndex: Integer;
  iCurrFuncIndex: Integer;
begin
  if g_Scripts[iThreadIndex].iIsActive = 0 then
    Exit;

  // �ͷżĴ������ַ���
  if g_Scripts[iThreadIndex]._RetVal.iType = OP_TYPE_STRING then
    FreeMem(g_Scripts[iThreadIndex]._RetVal.pstrStringLiteral);

  // ----Free Thr instruction stream
  for iCurrInstrIndex := 0 to g_Scripts[iThreadIndex].InstrStream.iSize - 1 do
  begin
    iOpCount := g_Scripts[iThreadIndex].InstrStream.pInstrs[iCurrInstrIndex].iOpCount;

    for iCurrOpIndex := 0 to iOpCount - 1 do
    begin
      with g_Scripts[iThreadIndex].InstrStream.pInstrs[iCurrInstrIndex] do
        if pOpList[iCurrOpIndex].iType = OP_TYPE_STRING then
          if Assigned(pOpList[iCurrOpIndex].pstrStringLiteral) then
          begin
            if StrLen(pOpList[iCurrOpIndex].pstrStringLiteral) > 0 then
              FreeMem(pOpList[iCurrOpIndex].pstrStringLiteral);
          end;
    end;
    //
  end;

  if Assigned(g_Scripts[iThreadIndex].InstrStream.pInstrs) then
    Finalize(g_Scripts[iThreadIndex].InstrStream.pInstrs);
  // // ----free the runtime stack
  // for iCurrElmntnIndex := 0 to g_Scripts[iThreadIndex].Stack.iSize - 1 do
  // begin
  // with g_Scripts[iThreadIndex].Stack do
  // begin
  // if pElmnts[iCurrElmntnIndex].iType = OP_TYPE_STRING then
  // if Assigned(pElmnts[iCurrElmntnIndex].pstrStringLiteral) then
  // if StrLen(pElmnts[iCurrElmntnIndex].pstrStringLiteral) > 0 then
  // begin
  // FreeMem(pElmnts[iCurrElmntnIndex].pstrStringLiteral);
  // end;
  // end;
  // end;

  if Assigned(g_Scripts[iThreadIndex].Stack.pElmnts) then
    Finalize(g_Scripts[iThreadIndex].Stack.pElmnts);
  // ----free the function table
  for iCurrFuncIndex := 0 to g_Scripts[iThreadIndex].FuncTable.iSize - 1 do
  begin
    if Assigned(g_Scripts[iThreadIndex].FuncTable.pFuncs[iCurrFuncIndex].pstrName) then
      FreeMem(g_Scripts[iThreadIndex].FuncTable.pFuncs[iCurrFuncIndex].pstrName);
  end;
  if Assigned(g_Scripts[iThreadIndex].FuncTable.pFuncs) then
  begin
    Finalize(g_Scripts[iThreadIndex].FuncTable.pFuncs);
  end;
  // ----free the host api call table
  for iCurrCallIndex := 0 to g_Scripts[iThreadIndex].HostAPICallTable.iSize - 1 do
  begin
    inc(g_Scripts[iThreadIndex].HostAPICallTable.ppstrCalls, iCurrCallIndex);
    if g_Scripts[iThreadIndex].HostAPICallTable.ppstrCalls <> nil then
      FreeMem(g_Scripts[iThreadIndex].HostAPICallTable.ppstrCalls^);
    Dec(g_Scripts[iThreadIndex].HostAPICallTable.ppstrCalls, iCurrCallIndex);
  end;
  if g_Scripts[iThreadIndex].HostAPICallTable.ppstrCalls <> nil then
    FreeMem(g_Scripts[iThreadIndex].HostAPICallTable.ppstrCalls);

end;

procedure XS_ResetScript(iThreadIndex: Integer);
var
  iMainFuncIndex: Integer;
  iCurrElmentIndex: Integer;
begin
  iMainFuncIndex := g_Scripts[iThreadIndex].iMainFuncIndex;
  if g_Scripts[iThreadIndex].FuncTable.pFuncs <> nil then
  begin
    if g_Scripts[iThreadIndex].iIsMainFuncPresent <> 0 then
    begin
      g_Scripts[iThreadIndex].InstrStream.iCurrInstr := g_Scripts[iThreadIndex].FuncTable.pFuncs
        [iMainFuncIndex].iEntryPoint;
    end;
  end;
  // clear the stack
  g_Scripts[iThreadIndex].Stack.iTopIndex := 0;
  g_Scripts[iThreadIndex].Stack.iFrameIndex := 0;
  // set the entire stack to null
  for iCurrElmentIndex := 0 to g_Scripts[iThreadIndex].Stack.iSize - 1 do
  begin
    g_Scripts[iThreadIndex].Stack.pElmnts[iCurrElmentIndex].iType := OP_TYPE_NULL;
  end;
  // Unpause the script
  g_Scripts[iThreadIndex].iIsPaused := 0;
  // allocate space for the globals
  PushFrame(iThreadIndex, g_Scripts[iThreadIndex].iGlobalDataSize);
  PushFrame(iThreadIndex, g_Scripts[iThreadIndex].FuncTable.pFuncs[iMainFuncIndex]
    .iLocalDataSize + 1);
end;

procedure XS_RunScripts(iTimesliceDur: Integer);
const
  THREAD_TIMESLICE_DUR = 20;
var
  iExitExecLoop: Boolean;
  iMainTimesliceStartTime: Integer;
  iCurrInstr: Integer;
  iOpcode: Integer;
  //
  Dest: Value;
  Source: Value;
  //
  iDestStoreType: Integer;
  //
  pstrSourceString: PAnsiChar;
  pstrNewString: PAnsiChar;
  iNewStringLength: Integer;
  //
  iSourceIndex: Integer;
  //
  iDestIndex: Integer;
  //
  iTargetIndex: Integer;
  //
  Op0: Value;
  Op1: Value;
  iJump: Boolean;
  // stack
  iFuncIndex: Integer;
  FDest: Func;
  ReturnAddr: Value;
  FuncIndex: Value;
  CurrFunc: Func;
  iFrameIndex: Integer;
  // misc
  iPauseDuration: Integer;
  ExitCode: Value;
  iExitCode: Integer;
  //
  iCurrTime: Integer;
  iCurrThreadIndex: Integer;
  iIsStillActive: Boolean;
  //
  HostAPICall: Value;
  iHostAPICallIndex: Integer;
  iHostAPIFuncIndex: Integer;
  pstrFuncName: PAnsiChar;
  iMatchFound: Boolean;
  pstrCurrHostAPIFunc: PAnsiChar;
  iThreadIndex: Integer;
begin
  iExitExecLoop := False;
  iMainTimesliceStartTime := GetCurrentTime();

  while True do
  begin
    Sleep(1);
    //
    iIsStillActive := False;
    for iCurrThreadIndex := 0 to MAX_THREAD_COUNT - 1 do
    begin
      if (g_Scripts[iCurrThreadIndex].iIsActive <> 0) and
        (g_Scripts[iCurrThreadIndex].iIsRunning <> 0) then
      begin
        iIsStillActive := True;
      end;
    end;
    if not iIsStillActive then
      Break;
    // update the current time
    iCurrTime := GetCurrTime();
    // check the thread mode
    if g_iCurrThreadMode = THREAD_MODE_MULTI then
    begin
      if (iCurrTime > g_iCurrThreadActiveTime + g_Scripts[g_iCurrThread].iTimesliceDur) or
        (g_Scripts[g_iCurrThread].iIsRunning = 0) then
      begin
        while True do
        begin
          // �ƶ����鵽��һ�߳�
          inc(g_iCurrThread);
          if g_iCurrThread >= MAX_THREAD_COUNT then
            g_iCurrThread := 0;

          if (g_Scripts[g_iCurrThread].iIsActive <> 0) and (g_Scripts[g_iCurrThread].iIsRunning <> 0)
          then
          begin
            Break;
          end;
        end;
        g_iCurrThreadActiveTime := iCurrTime;
      end;
    end;

    if g_Scripts[g_iCurrThread].iIsPaused <> 0 then
    begin
      if GetCurrTime >= g_Scripts[g_iCurrThread].iPauseEndTime then
      begin
        g_Scripts[g_iCurrThread].iIsPaused := 0;
      end
      else
      begin
        Continue;
      end;
    end;
    // Make a copy of the instruction pointer to compare later
    // get current opcode
    iCurrInstr := g_Scripts[g_iCurrThread].InstrStream.iCurrInstr;
    iOpcode := g_Scripts[g_iCurrThread].InstrStream.pInstrs[iCurrInstr].iOpcode;

    // Execute the current instruction based on its opcode,as long as we arn't
    // currently paused
    case iOpcode of
      INSTR_MOV,
      // Arithmetic Operations
      INSTR_ADD, INSTR_SUB, INSTR_MUL, INSTR_DIV, INSTR_MOD, INSTR_EXP,
      // Bitwise Operations
      INSTR_AND, INSTR_OR, INSTR_XOR, INSTR_SHL, INSTR_SHR:
        begin
          Dest := ResolveOpValue(0);
          Source := ResolveOpValue(1);
          case iOpcode of
            INSTR_MOV:
              begin
                if ResolveOpPntr(0) = ResolveOpPntr(1) then
                  Break;
                CopyValue(@Dest, Source);
              end;
            INSTR_ADD:
              begin
                if Dest.iType = OP_TYPE_INT then
                  inc(Dest.iIntLiteral, ResolveOpAsInt(1))
                else
                  Dest.fFloatLiteral := Dest.fFloatLiteral + ResolveOpAsFloat(1);
              end;
            INSTR_SUB:
              begin
                if Dest.iType = OP_TYPE_INT then
                  Dec(Dest.iIntLiteral, ResolveOpAsInt(1))
                else
                  Dest.fFloatLiteral := Dest.fFloatLiteral - ResolveOpAsInt(1)
              end;
            INSTR_MUL:
              begin
                if (Dest.iType = OP_TYPE_INT) then
                  Dest.iIntLiteral := Dest.iIntLiteral * ResolveOpAsInt(1)
                else
                  Dest.fFloatLiteral := Dest.fFloatLiteral * ResolveOpAsFloat(1)
              end;
            INSTR_DIV:
              begin
                if Dest.iType = OP_TYPE_INT then
                  Dest.iIntLiteral := Trunc(Dest.iIntLiteral / ResolveOpAsInt(1))
                else
                  Dest.fFloatLiteral := Dest.fFloatLiteral / ResolveOpAsInt(1)
              end;
            INSTR_MOD:
              begin
                if Dest.iType = OP_TYPE_INT then
                  Dest.iIntLiteral := Dest.iIntLiteral mod ResolveOpAsInt(1);
              end;
            INSTR_EXP:
              begin
                if Dest.iType = OP_TYPE_INT then
                  Dest.iIntLiteral := Trunc(Exp(Ln(Dest.iIntLiteral) * ResolveOpAsInt(1)))
                else
                  Dest.fFloatLiteral := Exp(Ln(Dest.fFloatLiteral) * ResolveOpAsInt(1));
              end;
            INSTR_AND:
              begin
                if Dest.iType = OP_TYPE_INT then
                  Dest.iIntLiteral := Dest.iIntLiteral and ResolveOpAsInt(1);
              end;
            INSTR_OR:
              begin
                if Dest.iType = OP_TYPE_INT then
                  Dest.iIntLiteral := Dest.iIntLiteral or ResolveOpAsInt(1);
              end;
            INSTR_XOR:
              begin
                if Dest.iType = OP_TYPE_INT then
                  Dest.iIntLiteral := Dest.iIntLiteral xor ResolveOpAsInt(1);
              end;
            INSTR_SHL:
              begin
                if Dest.iType = OP_TYPE_INT then
                  Dest.iIntLiteral := Dest.iIntLiteral shl ResolveOpAsInt(1);
              end;
            INSTR_SHR:
              begin
                if Dest.iType = OP_TYPE_INT then
                  Dest.iIntLiteral := Dest.iIntLiteral shr ResolveOpAsInt(1);
              end;
          end;
          //
          ResolveOpPntr(0)^ := Dest;
        end;
      INSTR_NEG, INSTR_NOT, INSTR_INC, INSTR_DEC:
        begin
          iDestStoreType := GetOpType(0);
          Dest := ResolveOpValue(0);
          case iOpcode of
            INSTR_NEG:
              begin
                if Dest.iType = OP_TYPE_INT then
                  Dest.iIntLiteral := -Dest.iIntLiteral
                else
                  Dest.fFloatLiteral := -Dest.fFloatLiteral;
              end;
            INSTR_NOT:
              begin
                if Dest.iType = OP_TYPE_INT then
                  Dest.iIntLiteral := not Dest.iIntLiteral;
              end;
            INSTR_INC:
              begin
                if Dest.iType = OP_TYPE_INT then
                  inc(Dest.iIntLiteral)
                else
                  Dest.fFloatLiteral := Dest.fFloatLiteral + 1;
              end;
            INSTR_DEC:
              begin
                if Dest.iType = OP_TYPE_INT then
                  Dec(Dest.iIntLiteral)
                else
                  Dest.fFloatLiteral := Dest.fFloatLiteral - 1;
              end;
          end;
          ResolveOpPntr(0)^ := Dest;
        end;
      INSTR_CONCAT:
        begin
          Dest := ResolveOpValue(0);
          pstrSourceString := ResolveOpAsString(1);
          if Dest.iType <> OP_TYPE_STRING then
            Break;
          iNewStringLength := StrLen(Dest.pstrStringLiteral) + StrLen(pstrSourceString);
          GetMem(pstrNewString, iNewStringLength + 1);

          StrCopy(pstrNewString, Dest.pstrStringLiteral);
          StrCat(pstrNewString, pstrSourceString);
          FreeMem(Dest.pstrStringLiteral);
          Dest.pstrStringLiteral := pstrNewString;
          ResolveOpPntr(0)^ := Dest;
        end;
      INSTR_GETCHAR:
        begin
          Dest := ResolveOpValue(0);
          pstrSourceString := ResolveOpAsString(1);
          if Dest.iType = OP_TYPE_STRING then
          begin
            if StrLen(Dest.pstrStringLiteral) >= 1 then
              pstrNewString := Dest.pstrStringLiteral
            else
            begin
              FreeMem(Dest.pstrStringLiteral);
              GetMem(pstrNewString, 2);
            end;
          end
          else
          begin
            GetMem(pstrNewString, 2);
            Dest.iType := OP_TYPE_STRING;
          end;
          iSourceIndex := ResolveOpAsInt(2);
          pstrNewString[0] := pstrSourceString[iSourceIndex];
          pstrNewString[1] := #0;

          Dest.pstrStringLiteral := pstrNewString;
          ResolveOpPntr(0)^ := Dest;
        end;
      INSTR_SETCHAR:
        begin
          iDestIndex := ResolveOpAsInt(0);
          if ResolveOpType(0) <> OP_TYPE_STRING then
            Break;

          pstrSourceString := ResolveOpAsString(2);
          ResolveOpPntr(0)^.pstrStringLiteral[iDestIndex] := pstrSourceString[0];
        end;

      INSTR_JMP:
        begin
          iTargetIndex := ResolveOpAsInstrIndex(0);
          g_Scripts[g_iCurrThread].InstrStream.iCurrInstr := iTargetIndex;
        end;
      INSTR_JE, INSTR_JNE, INSTR_JG, INSTR_JL, INSTR_JGE, INSTR_JLE:
        begin
          Op0 := ResolveOpValue(0);
          Op1 := ResolveOpValue(1);
          iTargetIndex := ResolveOpAsInstrIndex(2);
          iJump := False;
          case iOpcode of
            INSTR_JE:
              begin
                case Op0.iType of
                  OP_TYPE_INT:
                    begin
                      if Op0.iIntLiteral = Op1.iIntLiteral then
                        iJump := True;
                    end;
                  OP_TYPE_FLOAT:
                    begin
                      if Op0.fFloatLiteral = Op1.fFloatLiteral then
                        iJump := True;
                    end;
                  OP_TYPE_STRING:
                    begin
                      if StrComp(Op0.pstrStringLiteral, Op1.pstrStringLiteral) = 0 then
                        iJump := True;
                    end;
                end;
              end;
            INSTR_JNE:
              begin
                case Op0.iType of
                  OP_TYPE_INT:
                    begin
                      if Op0.iIntLiteral <> Op1.iIntLiteral then
                        iJump := True;
                    end;
                  OP_TYPE_FLOAT:
                    begin
                      if Op0.fFloatLiteral <> Op1.fFloatLiteral then
                        iJump := True;
                    end;
                  OP_TYPE_STRING:
                    begin
                      if StrComp(Op0.pstrStringLiteral, Op1.pstrStringLiteral) = 0 then
                        iJump := True;
                    end;
                end;
              end;
            INSTR_JG:
              begin
                if Op0.iType = OP_TYPE_INT then
                begin
                  if Op0.iType > Op1.iIntLiteral then
                    iJump := True;
                end
                else
                begin
                  if Op0.fFloatLiteral > Op1.fFloatLiteral then
                    iJump := True;
                end;
              end;
            INSTR_JL:
              begin
                if Op0.iType = OP_TYPE_INT then
                begin
                  if Op0.iIntLiteral < Op1.iIntLiteral then
                    iJump := True;
                end
                else
                begin
                  if Op0.fFloatLiteral < Op1.fFloatLiteral then
                    iJump := True;
                end;
              end;
            INSTR_JGE:
              begin
                if Op0.iType = OP_TYPE_INT then
                begin
                  if Op0.iIntLiteral >= Op1.iIntLiteral then
                    iJump := True;
                end
                else
                begin
                  if Op0.fFloatLiteral >= Op1.fFloatLiteral then
                    iJump := True;
                end;
              end;
            INSTR_JLE:
              begin
                if Op0.iType = OP_TYPE_INT then
                begin
                  if Op0.iIntLiteral <= Op1.iIntLiteral then
                    iJump := True;
                end
                else
                begin
                  if Op0.fFloatLiteral <= Op1.fFloatLiteral then
                    iJump := True;
                end;
              end;
          end;

          if iJump then
          begin
            g_Scripts[g_iCurrThread].InstrStream.iCurrInstr := iTargetIndex;
          end;
        end;
      // ��ջ�ӿ�
      INSTR_PUSH:
        begin
          Source := ResolveOpValue(0);
          Push(g_iCurrThread, Source);
        end;
      INSTR_POP:
        begin
          ResolveOpPntr(0)^ := Pop(g_iCurrThread);
        end;
      INSTR_CALL:
        begin
          iFuncIndex := ResolveOpAsFuncIndex(0);
          inc(g_Scripts[g_iCurrThread].InstrStream.iCurrInstr);
          CallFunc(g_iCurrThread, iFuncIndex);
        end;
      INSTR_RET:
        begin
          iFrameIndex := 0;
          FuncIndex := Pop(g_iCurrThread);
          if FuncIndex.iType = OP_TYPE_STACK_BASE_MARKER then
            iExitExecLoop := True;

          CurrFunc := GetFunc(g_iCurrThread, FuncIndex.iFuncIndex);
          iFrameIndex := FuncIndex.iOffsetIndex;
          // ע�ⷵ��ʱ��������
          ReturnAddr := GetStackValue(g_iCurrThread, g_Scripts[g_iCurrThread].Stack.iTopIndex -
            (CurrFunc.iLocalDataSize + 1));

          PopFrame(CurrFunc.iStackFrameSize);

          g_Scripts[g_iCurrThread].Stack.iFrameIndex := iFrameIndex;
          // make the jump to the return address
          g_Scripts[g_iCurrThread].InstrStream.iCurrInstr := ReturnAddr.iInstrIndex;
        end;
      INSTR_CALLHOST:
        begin
          HostAPICall := ResolveOpValue(0);
          iHostAPICallIndex := HostAPICall.iHostAPICallIndex;
          // ȡ����Ӧ�ó���API������
          pstrFuncName := GetHostAPICall(iHostAPICallIndex);
          // ������Ӧ�ó���APIֱ���ҵ�ƥ�亯��
          iMatchFound := False;
          for iHostAPIFuncIndex := 0 to MAX_HOST_API_SIZE - 1 do
          begin
            pstrCurrHostAPIFunc := g_HostAPI[iHostAPIFuncIndex].pstrName;
            if StrComp(pstrFuncName, pstrCurrHostAPIFunc) = 0 then
            begin
              iThreadIndex := g_HostAPI[iHostAPIFuncIndex].iThreadIndex;
              if (iThreadIndex = g_iCurrThread) or (iThreadIndex = XS_GLOBAL_FUNC) then
              begin
                iMatchFound := True;
                Break;
              end;
            end;
          end;
          // ���ƥ�䣬�͵���API���������ݵ�ǰ�߳�����
          if iMatchFound then
            g_HostAPI[iHostAPIFuncIndex].fnFunc(g_iCurrThread);
        end;
      // ---Misc
      INSTR_PAUSE:
        begin
          iPauseDuration := ResolveOpAsInt(0);

          g_Scripts[g_iCurrThread].iPauseEndTime := iCurrTime + iPauseDuration;

          g_Scripts[g_iCurrThread].iIsPaused := 1;
        end;
      INSTR_EXIT:
        begin
          ExitCode := ResolveOpValue(0);
          iExitCode := ExitCode.iIntLiteral;
          // ����XVMִֹͣ�иýű�
          g_Scripts[g_iCurrThread].iIsRunning := 0;
        end;
    end;

    if iCurrInstr = g_Scripts[g_iCurrThread].InstrStream.iCurrInstr then
      inc(g_Scripts[g_iCurrThread].InstrStream.iCurrInstr);

    if iTimesliceDur <> XS_INFINITE_TIMESLICE then
      if iCurrTime > iMainTimesliceStartTime + iTimesliceDur then
        Break;

    if iExitExecLoop then
      Break;
  end;
end;

// ----Operand Interface-------------
function CoerceValueToInt(val: Value): Integer;
begin
  case val.iType of
    OP_TYPE_INT:
      begin
        Result := val.iIntLiteral;
        Exit;
      end;
    OP_TYPE_FLOAT:
      begin
        Result := Trunc(val.fFloatLiteral);
        Exit;
      end;
    OP_TYPE_STRING:
      begin
        Result := StrToInt(AnsiString(val.pstrStringLiteral));
        Exit;
      end;
  else
    Result := 0;
  end;
end;

function CoerceValueToFloat(val: Value): Single;
begin
  case val.iType of
    OP_TYPE_INT:
      begin
        Result := val.iIntLiteral;
        Exit;
      end;
    OP_TYPE_FLOAT:
      begin
        Result := val.fFloatLiteral;
        Exit;
      end;
    OP_TYPE_STRING:
      begin
        Result := StrToFloat(AnsiString(val.pstrStringLiteral));
        Exit;
      end;
  else
    Result := 0;
  end;
end;

function CoerceValueToString(val: Value): PAnsiChar;
var
  pstrCoercion: PAnsiChar;
begin
  if val.iType <> OP_TYPE_STRING then
    GetMem(pstrCoercion, MAX_COERCION_STRING_SIZE + 1);

  case val.iType of
    OP_TYPE_INT:
      begin
        StrCopy(pstrCoercion, PAnsiChar(AnsiString(IntToStr(val.iIntLiteral))));
        Result := pstrCoercion;
        Exit;
      end;
    OP_TYPE_FLOAT:
      begin
        StrCopy(pstrCoercion, PAnsiChar(AnsiString(FloatToStr(val.fFloatLiteral))));
        Result := pstrCoercion;
        Exit;
      end;
    OP_TYPE_STRING:
      begin
        Result := val.pstrStringLiteral;
      end;
  else
    Result := nil;
  end;
end;

procedure CopyValue(pDest: pValue; Source: Value);
begin
  if pDest.iType = OP_TYPE_STRING then
    FreeMem(pDest.pstrStringLiteral);
  pDest^ := Source;

  if Source.iType = OP_TYPE_STRING then
  begin
    GetMem(pDest.pstrStringLiteral, StrLen(Source.pstrStringLiteral) + 1);
    StrCopy(pDest.pstrStringLiteral, Source.pstrStringLiteral);
  end;
end;

function GetOpType(iOpIndex: Integer): Integer;
var
  iCurrInstr: Integer;
begin
  iCurrInstr := g_Scripts[g_iCurrThread].InstrStream.iCurrInstr;
  Result := g_Scripts[g_iCurrThread].InstrStream.pInstrs[iCurrInstr].pOpList[iOpIndex].iType;
end;

function ResolveOpStackIndex(iOpIndex: Integer): Integer;
var
  OpValue: Value;
  //
  iBaseIndex: Integer;
  iOffsetIndex: Integer;
  StackValue: Value;
begin
  OpValue := g_Scripts[g_iCurrThread].InstrStream.pInstrs
    [g_Scripts[g_iCurrThread].InstrStream.iCurrInstr].pOpList[iOpIndex];
  case OpValue.iType of
    OP_TYPE_ABS_STACK_INDEX:
      begin
        Result := OpValue.iStackIndex;
        Exit;
      end;
    OP_TYPE_REL_STACK_INDEX:
      begin
        iBaseIndex := OpValue.iStackIndex;
        iOffsetIndex := OpValue.iOffsetIndex;
        StackValue := GetStackValue(g_iCurrThread, iOffsetIndex);
        Result := iBaseIndex + StackValue.iIntLiteral;
        Exit;
      end;
  else
    Result := 0;
  end;
end;

function ResolveStackIndex(iIndex: Integer): Integer;
begin
  if iIndex < 0 then
  begin
    Result := iIndex + g_Scripts[g_iCurrThread].Stack.iFrameIndex;
  end
  else
    Result := iIndex;
end;

function ResolveOpValue(iOpIndex: Integer): Value;
var
  iCurrInstr: Integer;
  OpValue: Value;
  iAbsIndex: Integer;
begin
  iAbsIndex := 0;

  iCurrInstr := g_Scripts[g_iCurrThread].InstrStream.iCurrInstr;

  OpValue := g_Scripts[g_iCurrThread].InstrStream.pInstrs[iCurrInstr].pOpList[iOpIndex];

  case OpValue.iType of
    OP_TYPE_ABS_STACK_INDEX, OP_TYPE_REL_STACK_INDEX:
      begin
        iAbsIndex := ResolveOpStackIndex(iOpIndex);
        Result := GetStackValue(g_iCurrThread, iAbsIndex);
        Exit;
      end;
    OP_TYPE_REG:
      begin
        Result := g_Scripts[g_iCurrThread]._RetVal;
        Exit;
      end;
  else
    Result := OpValue;
  end;
end;

function ResolveOpType(iOpIndex: Integer): Integer;
var
  OpValue: Value;
begin
  OpValue := ResolveOpValue(iOpIndex);
  Result := OpValue.iType;
end;

function ResolveOpAsInt(iOpIndex: Integer): Integer;
var
  OpValue: Value;
begin
  OpValue := ResolveOpValue(iOpIndex);
  Result := CoerceValueToInt(OpValue);
end;

function ResolveOpAsFloat(iOpIndex: Integer): Single;
var
  OpValue: Value;
  fFloat: Single;
begin
  OpValue := ResolveOpValue(iOpIndex);
  fFloat := CoerceValueToFloat(OpValue);
  Result := fFloat;
end;

function ResolveOpAsString(iOpIndex: Integer): PAnsiChar;
var
  OpValue: Value;
  pstrString: PAnsiChar;
begin
  OpValue := ResolveOpValue(iOpIndex);
  pstrString := CoerceValueToString(OpValue);
  Result := pstrString;
end;

function ResolveOpAsInstrIndex(iOpIndex: Integer): Integer;
var
  OpValue: Value;
begin
  OpValue := ResolveOpValue(iOpIndex);
  Result := OpValue.iInstrIndex;
end;

function ResolveOpAsFuncIndex(iOpIndex: Integer): Integer;
var
  OpValue: Value;
begin
  OpValue := ResolveOpValue(iOpIndex);
  Result := OpValue.iFuncIndex;
end;

function ResolveOpAsHostAPICall(iOpIndex: Integer): PAnsiChar;
var
  OpValue: Value;
  iHostAPICallIndex: Integer;
begin
  OpValue := ResolveOpValue(iOpIndex);
  iHostAPICallIndex := OpValue.iHostAPICallIndex;
  Result := GetHostAPICall(iHostAPICallIndex);
end;

function ResolveOpPntr(iOpIndex: Integer): pValue;
var
  iIndirMethod: Integer;
  iStackIndex: Integer;
  iCurrElmntIndex: Integer;
begin
  iIndirMethod := GetOpType(iOpIndex);
  case iIndirMethod of
    OP_TYPE_REG:
      begin
        Result := @(g_Scripts[g_iCurrThread]._RetVal);
        Exit;
      end;
    OP_TYPE_ABS_STACK_INDEX, OP_TYPE_REL_STACK_INDEX:
      begin
        iStackIndex := ResolveOpStackIndex(iOpIndex);
        iCurrElmntIndex := ResolveStackIndex(iStackIndex);
        Result := @g_Scripts[g_iCurrThread].Stack.pElmnts[iCurrElmntIndex];
        Exit;
      end;
  end;
  Result := nil;
end;

// ----Runtime Stack Interface----------
/// Returns the specified stack value
function GetStackValue(iThreadIndex: Integer; iIndex: Integer): Value;
var
  iCurrElmntIndex: Integer;
begin
  iCurrElmntIndex := 0;
  iCurrElmntIndex := ResolveStackIndex(iIndex);
  Result := g_Scripts[iThreadIndex].Stack.pElmnts[iCurrElmntIndex];
end;

/// Set the specified stack value
procedure SetStackValue(iThreadIndex: Integer; iIndex: Integer; val: Value);
var
  iCurrElmntIndex: Integer;
begin
  iCurrElmntIndex := ResolveStackIndex(iIndex);
  g_Scripts[iThreadIndex].Stack.pElmnts[iCurrElmntIndex] := val;
end;

/// Push an element onto the stack
procedure Push(iThreadIndex: Integer; val: Value);
var
  iTopIndex: Integer;
begin
  iTopIndex := g_Scripts[iThreadIndex].Stack.iTopIndex;
  g_Scripts[iThreadIndex].Stack.pElmnts[iTopIndex] := val;
  inc(g_Scripts[iThreadIndex].Stack.iTopIndex);
end;

/// Pops the element off the top of the stack
function Pop(iThreadIndex: Integer): Value;
var
  val: Value;
  iTopIndex: Integer;
begin
  Dec(g_Scripts[iThreadIndex].Stack.iTopIndex);
  iTopIndex := g_Scripts[iThreadIndex].Stack.iTopIndex;
  CopyValue(@val, g_Scripts[iThreadIndex].Stack.pElmnts[iTopIndex]);
  Result := val;
end;

/// Pushes a stack frame
procedure PushFrame(iThreadIndex: Integer; iSize: Integer);
begin
  inc(g_Scripts[iThreadIndex].Stack.iTopIndex, iSize);
  g_Scripts[iThreadIndex].Stack.iFrameIndex := g_Scripts[iThreadIndex].Stack.iTopIndex;
end;

/// Pops a stack frame
procedure PopFrame(iSize: Integer);
begin
  Dec(g_Scripts[g_iCurrThread].Stack.iTopIndex, iSize);
end;

/// / ----Function Table Interface---------
function GetFunc(iThreadIndex: Integer; iIndex: Integer): Func;
begin
  Result := g_Scripts[g_iCurrThread].FuncTable.pFuncs[iIndex];
end;

function GetFuncIndexByName(iThreadIndex: Integer; pstrName: PAnsiChar): Integer;
var
  iFuncIndex: Integer;
begin
  // loop through each function and look for a matching name
  for iFuncIndex := 0 to g_Scripts[iThreadIndex].FuncTable.iSize - 1 do
  begin
    // if the names match,return the index
    if (StrIComp(pstrName, g_Scripts[iThreadIndex].FuncTable.pFuncs[iFuncIndex].pstrName) = 0) then
    begin
      Result := iFuncIndex;
      Exit;
    end;

  end;
  Result := -1;
end;

/// / ----Host API Call Table Interface----
function GetHostAPICall(iIndex: Integer): PAnsiChar;
begin
  inc(g_Scripts[g_iCurrThread].HostAPICallTable.ppstrCalls, iIndex);
  Result := g_Scripts[g_iCurrThread].HostAPICallTable.ppstrCalls^;
  Dec(g_Scripts[g_iCurrThread].HostAPICallTable.ppstrCalls, iIndex);
end;

/// / ----Printing Helper Functions--------
procedure PrintOpIndir(iOpIndex: Integer);
var
  iIndirMethod: Integer;
  iStackIndex: Integer;
begin
  iIndirMethod := GetOpType(iOpIndex);
  case iIndirMethod of
    OP_TYPE_REG:
      begin
        write('_RetVal');
      end;
    OP_TYPE_ABS_STACK_INDEX, OP_TYPE_REL_STACK_INDEX:
      begin
        iStackIndex := ResolveOpStackIndex(iOpIndex);
        write(Format('[ %d ]', [iStackIndex]));
      end;
  end;
end;

procedure PrintOpValue(iOpIndex: Integer);
var
  Op: Value;
  pstrHostAPICall: PAnsiChar;
begin
  Op := ResolveOpValue(iOpIndex);
  case Op.iType of
    OP_TYPE_NULL:
      write('Null');
    OP_TYPE_INT:
      write(Op.iIntLiteral);
    OP_TYPE_FLOAT:
      write(Op.fFloatLiteral);
    OP_TYPE_STRING:
      write('\', Op.pstrStringLiteral, '\');
    OP_TYPE_INSTR_INDEX:
      write(Op.iInstrIndex);
    OP_TYPE_HOST_API_CALL_INDEX:
      begin
        pstrHostAPICall := ResolveOpAsHostAPICall(iOpIndex);
        write(pstrHostAPICall);
      end;
  end;
end;

// ----Time Abstraction-----------------
function GetCurrTime(): Integer;
begin
  // This function is currently implemented with the WinAPI function GetTickCount ().
  // Change this line to make it compatible with other systems.
  Result := GetTickCount;
end;

procedure CallFunc(iThreadIndex: Integer; iIndex: Integer);
var
  DestFunc: Func;
  iFrameIndex: Integer;
  ReturnAddr: Value;
  FuncIndex: Value;
begin
  DestFunc := GetFunc(iThreadIndex, iIndex);
  // Save the current stack frame index
  iFrameIndex := g_Scripts[iThreadIndex].Stack.iFrameIndex;
  // push the return address ,which is the current instruction
  ReturnAddr.iInstrIndex := g_Scripts[iThreadIndex].InstrStream.iCurrInstr;
  Push(iThreadIndex, ReturnAddr);
  //
  PushFrame(iThreadIndex, DestFunc.iLocalDataSize + 1);
  FuncIndex.iFuncIndex := iIndex;
  FuncIndex.iOffsetIndex := iFrameIndex;
  SetStackValue(iThreadIndex, g_Scripts[iThreadIndex].Stack.iTopIndex - 1, FuncIndex);
  g_Scripts[iThreadIndex].InstrStream.iCurrInstr := DestFunc.iEntryPoint;
end;

// ----interface-------------------------
function IsValidThreadIndex(iIndex: Integer): Boolean;
begin
  Result := not((iIndex < 0) or (iIndex > MAX_THREAD_COUNT));
end;

function IsThreadActive(iIndex: Integer): Boolean;
begin
  Result := IsValidThreadIndex(iIndex) and (g_Scripts[g_iCurrThread].iIsActive <> 0);
end;

procedure XS_StartScript(iThreadIndex: Integer);
begin
  // �߳������Ƿ�Ϸ���Ч
  if not IsThreadActive(iThreadIndex) then
    Exit;
  // �����߳�ִ�б�־
  g_Scripts[iThreadIndex].iIsRunning := 1;
  // ���߳����ø��ű�
  g_iCurrThread := iThreadIndex;
  // Ϊ��ǰ�߳����û�Ծʱ��
  g_iCurrThreadActiveTime := GetCurrTime();
end;

procedure XS_StopScript(iThreadIndex: Integer);
begin
  if not IsThreadActive(iThreadIndex) then
    Exit;
  // ����߳�ִ�б�־
  g_Scripts[iThreadIndex].iIsRunning := 0;
end;

procedure XS_PauseScript(iThreadIndex: Integer; iDur: Integer);
begin
  if not IsThreadActive(iThreadIndex) then
    Exit;
  // ������ͣ��־
  g_Scripts[iThreadIndex].iIsPaused := 1;
  // ������ͣ����ʱ��
  g_Scripts[iThreadIndex].iPauseEndTime := GetCurrTime() + iDur;
end;

procedure XS_UppauseScript(iThreadIndex: Integer);
begin
  if not IsThreadActive(iThreadIndex) then
    Exit;
  // �����ͣ��־
  g_Scripts[iThreadIndex].iIsPaused := 0;
end;

procedure XS_PassIntParam(iThreadIndex: Integer; iInt: Integer);
var
  Param: Value;
begin
  Param.iType := OP_TYPE_INT;
  Param.iIntLiteral := iInt;
  // push the parameter onto the stack
  Push(iThreadIndex, Param);
end;

procedure XS_PassFloatParam(iThreadIndex: Integer; fFloat: Single);
var
  Param: Value;
begin
  Param.iType := OP_TYPE_FLOAT;
  Param.fFloatLiteral := fFloat;
  // push the parameter onto the stack
  Push(iThreadIndex, Param);
end;

procedure XS_PassStringParam(iThreadIndex: Integer; pstrString: PAnsiChar);
var
  Param: Value;
begin
  Param.iType := OP_TYPE_STRING;
  GetMem(Param.pstrStringLiteral, StrLen(pstrString) + 1);
  StrCopy(Param.pstrStringLiteral, pstrString);
  Push(iThreadIndex, Param);
end;

(* call a script function from host application *)
procedure XS_CallScriptFunc(iThreadIndex: Integer; pstrName: PAnsiChar);
var
  iPrevThreadMode: Integer;
  iPrevThread: Integer;
  iFuncIndex: Integer;
  StackBase: Value;
begin
  if not IsThreadActive(iThreadIndex) then
    Exit;
  // ----calling the function---------------
  // preserve the current state of the VM
  iPrevThreadMode := g_iCurrThreadMode;
  iPrevThread := g_iCurrThread;
  // set the threading mode for single-threaded excetion
  g_iCurrThreadMode := THREAD_MODE_SINGLE;
  // set the active thread to the one specified
  g_iCurrThread := iThreadIndex;
  // Get the functions's index based on it's name
  iFuncIndex := GetFuncIndexByName(iThreadIndex, pstrName);
  if iFuncIndex = -1 then
    Exit;
  // call the function
  CallFunc(iThreadIndex, iFuncIndex);
  // set the stack base
  StackBase := GetStackValue(g_iCurrThread, g_Scripts[g_iCurrThread].Stack.iTopIndex - 1);
  StackBase.iType := OP_TYPE_STACK_BASE_MARKER;
  SetStackValue(g_iCurrThread, g_Scripts[g_iCurrThread].Stack.iTopIndex - 1, StackBase);
  // allow the script code to excute uninterrupted until the function returns
  XS_RunScripts(XS_INFINITE_TIMESLICE);
  // ----handing the function return
  // restore the VM state
  g_iCurrThreadMode := iPrevThreadMode;
  g_iCurrThread := iPrevThread;
end;

(* ******************************************************************************
  * Invokes a script function from the host application, meaning the call
 *executes in sync with the script
*)
procedure XS_InvokeScriptFunc(iThreadIndex: Integer; pstrName: PAnsiChar);
var
  iFuncIndex: Integer;
begin
  if not IsThreadActive(iThreadIndex) then
    Exit;
  // get the functions's index based on its name
  iFuncIndex := GetFuncIndexByName(iThreadIndex, pstrName);
  // make sure the function name was vaild
  if iFuncIndex = -1 then
    Exit;
  // call the function
  CallFunc(iThreadIndex, iFuncIndex);
end;

(* Returns the lase returned value as an intege *)
function XS_GetReturnValueAsInt(iThreadIndex: Integer): Integer;
begin
  if not IsThreadActive(iThreadIndex) then
  begin
    Result := 0;
    Exit;
  end;
  // return _RetVal's integer field
  Result := g_Scripts[iThreadIndex]._RetVal.iIntLiteral;
end;

(* Returns the lase returned value as an float *)
function XS_GetReturnValueAsFloat(iThreadIndex: Integer): Single;
begin
  if not IsThreadActive(iThreadIndex) then
  begin
    Result := 0;
    Exit;
  end;
  // return _RetVal's floating-point field
  Result := g_Scripts[iThreadIndex]._RetVal.fFloatLiteral;
end;

(* Returns the lase returned value as an float *)
function XS_GetReturnAsString(iThreadIndex: Integer): PAnsiChar;
begin
  if not IsThreadActive(iThreadIndex) then
  begin
    Result := nil;
    Exit;
  end;
  // return _RetVal's string field
  Result := g_Scripts[iThreadIndex]._RetVal.pstrStringLiteral;
end;

procedure XS_RegisterHostAPIFunc(iThreadIndex: Integer; pstrName: PAnsiChar;
  fnFunc: HostAPIFuncPntr);
var
  iCurrHostAPIFunc: Integer;
begin
  for iCurrHostAPIFunc := 0 to MAX_HOST_API_SIZE - 1 do
  begin
    // �����ǰ�������о�ʹ�õ�ǰ����
    if g_HostAPI[iCurrHostAPIFunc].iIsActive = 0 then
    begin
      g_HostAPI[iCurrHostAPIFunc].iThreadIndex := iThreadIndex;
      GetMem(g_HostAPI[iCurrHostAPIFunc].pstrName, StrLen(pstrName) + 1);
      StrCopy(g_HostAPI[iCurrHostAPIFunc].pstrName, pstrName);
      StrUpper(g_HostAPI[iCurrHostAPIFunc].pstrName);
      g_HostAPI[iCurrHostAPIFunc].fnFunc := fnFunc;
      // �Ѻ�������Ϊ��Ծ
      g_HostAPI[iCurrHostAPIFunc].iIsActive := 1;
      Exit;
    end;
  end;
end;

// ----��ȡ����
function XS_GetParamAsInt(iThreadIndex: Integer; iParamIndex: Integer): Integer;
var
  iTopIndex: Integer;
  Param: Value;
begin
  // ȡջ��Ԫ��
  iTopIndex := g_Scripts[g_iCurrThread].Stack.iTopIndex;
  Param := g_Scripts[g_iCurrThread].Stack.pElmnts[iTopIndex - (iParamIndex + 1)];
  // ��ջ��Ԫ��ǿ��ת��������
  Result := CoerceValueToInt(Param);
end;

function XS_GetParamAsFloat(iThreadIndex: Integer; iParamIndex: Integer): Single;
var
  iTopIndex: Integer;
  Param: Value;
begin
  // ȡջ��Ԫ��
  iTopIndex := g_Scripts[g_iCurrThread].Stack.iTopIndex;
  Param := g_Scripts[g_iCurrThread].Stack.pElmnts[iTopIndex - (iParamIndex + 1)];
  // ��ջ��Ԫ��ǿ��ת���ɸ���
  Result := CoerceValueToFloat(Param);
end;

function XS_GetParamAsString(iThreadIndex: Integer; iParamIndex: Integer): PAnsiChar;
var
  iTopIndex: Integer;
  Param: Value;
begin
  // ȡջ��Ԫ��
  iTopIndex := g_Scripts[g_iCurrThread].Stack.iTopIndex;
  Param := g_Scripts[g_iCurrThread].Stack.pElmnts[iTopIndex - (iParamIndex + 1)];
  // ��ջ��Ԫ��ǿ��ת�����ַ���ָ��
  Result := CoerceValueToString(Param);
end;

// ----����ֵ
procedure XS_ReturnFromHost(iThreadIndex: Integer; iParamCount: Integer);
begin
  Dec(g_Scripts[iThreadIndex].Stack.iTopIndex, iParamCount);
end;

procedure XS_ReturnIntFromHost(iThreadIndex: Integer; iParamCount: Integer; iInt: Integer);
begin
  // �Ӷ�ջ���������
  Dec(g_Scripts[iThreadIndex].Stack.iTopIndex, iParamCount);
  // �ѷ���ֵ�����ͷŵ�_RetVal�Ĵ���
  g_Scripts[iThreadIndex]._RetVal.iType := OP_TYPE_INT;
  g_Scripts[iThreadIndex]._RetVal.iIntLiteral := iInt;
end;

procedure XS_ReturnFloatFromHost(iThreadIndex: Integer; iParamCount: Integer; iFloat: Single);
begin
  // �Ӷ�ջ���������
  Dec(g_Scripts[iThreadIndex].Stack.iTopIndex, iParamCount);
  // �ѷ���ֵ�����ʹ洢��_Retval��
  g_Scripts[iThreadIndex]._RetVal.iType := OP_TYPE_FLOAT;
  g_Scripts[iThreadIndex]._RetVal.fFloatLiteral := iFloat;
end;

procedure XS_ReturnStringFromHost(iThreadIndex: Integer; iParamCount: Integer;
  pstrString: PAnsiChar);
var
  ReturnValue: Value;
begin
  Dec(g_Scripts[iThreadIndex].Stack.iTopIndex, iParamCount);
  // �ѷ���ֵ�����ʹ洢��_Retval��
  ReturnValue.iType := OP_TYPE_STRING;
  ReturnValue.pstrStringLiteral := pstrString;
  CopyValue(@(g_Scripts[iThreadIndex]._RetVal), ReturnValue);
end;

end.
