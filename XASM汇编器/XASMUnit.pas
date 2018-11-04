unit XASMUnit;

interface

uses
  System.SysUtils, System.Classes,
  xvm_lexer, xvm_types, xvm_link_list, xvm_func_table,
  xvm_instr, xvm_label_table, xvm_symbol_table, xvm_errors;

const
  // -------------------------------------�ļ���--------------------------------------------------//
  MAX_FILENAME_SIZE = 2048;

  SOURCE_FILE_EXT = '.XASM';
  EXEC_FILE_EXT = '.XSE';

  // -------------------------------------Դ����--------------------------------------------------//
  MAX_SOURCE_CODE_SIZE = 65536;

  MAX_SOURCE_LINE_SIZE = 4096;

  // -------------------------------------.XSE�ļ�ͷ----------------------------------------------//

  XSE_ID_STRING = 'XSE0';

  VERSION_MAJOR = 0;
  VERSION_MINOR = 8;

  // -----Global Variables------
var
  g_pSourceFile: file;
  // Դ�ļ���
  g_pstrSourceFilename: AnsiString;
  // Ŀ���ļ���
  g_pstrExecFilename: AnsiString;
  // �ű�ͷ
  g_ScriptHeader: ScriptHeader;
  // �Ƿ��Ѿ����ö�ջ��С
  g_bIsSetStackSizeFound: Boolean;
  // �Ƿ��Ѿ��������ȼ�
  g_bIsSetPriorityFound: Boolean;
  // �ַ�����
  g_StringTable: LinkedList;
  // HostAPI ��
  g_HostAPICallTable: LinkedList;
  // ---Misc
procedure PrintLogo();
procedure PrintUsage();

procedure Init();
procedure ShutDown();

procedure LoadSourceFile();
procedure AssmblSourceFile();
procedure PrintAssmblStats();
procedure BuildXSE();

procedure MyExit();
procedure ExitOnCodeError(pstrErrorMssg: PAnsiChar);
procedure ExitOnCharExpectedError(cChar: AnsiChar);

implementation

{$REGION '�ַ�������'}

// ȥ��ע�͵�������Ϣ
procedure StripStrComments(var strSourceLine: AnsiString);
var
  i: integer;
  bInStr: Boolean;
begin
  bInStr := False;
  if Trim(strSourceLine) = '' then
  begin
    strSourceLine := '';
    Exit;
  end;

  for i := 1 to Length(strSourceLine) do
  begin
    if strSourceLine[i] = '"' then
    begin
      bInStr := not bInStr;
    end;

    if strSourceLine[i] = ';' then
    begin
      if not bInStr then
      begin
        strSourceLine := Trim(Copy(strSourceLine, 1, i - 1));
        Exit;
      end;
    end;
  end;
end;

{$ENDREGION}
{$REGION '����'}

// ---------------------MISC
procedure PrintLogo();
begin
  Writeln('XASM');
  Writeln(Format('StremeScript Assembler Version %d.%d', [VERSION_MAJOR, VERSION_MINOR]));
  Writeln('Written by Alex Varanese [C] .adsj [P]');
  Writeln;
end;

procedure PrintUsage();
begin
  Write('Usage:');
  Writeln('XASM Source.XASM [Executable.XSE]');
  Writeln;
  Writeln('      -File extensions are not required.');
  Writeln('      -Executable name is optional; source name is used by default.');
end;
{$ENDREGION}

procedure Init();
begin
  InitInstrTable();
  InitLinkedList(@g_SymbolTable);
  InitLinkedList(@g_LabelTable);
  InitLinkedList(@g_FuncTable);
  InitLinkedList(@g_StringTable);
  InitLinkedList(@g_HostAPICallTable);
end;

procedure ShutDown();
var
  iCurrLineIndex: integer;
  iCurrInstrIndex: integer;
begin
  // free each source line individually
  for iCurrLineIndex := 0 to g_iSourceCodeSize - 1 do
  begin
    inc(g_ppstrSourceCode, iCurrLineIndex);
    FreeMem(g_ppstrSourceCode^);
    Dec(g_ppstrSourceCode, iCurrLineIndex);
  end;

  FreeMem(g_ppstrSourceCode);
  //
  // free the assembled instruction stream
  if g_pInstrStream <> nil then
  begin
    for iCurrInstrIndex := 0 to g_iInstrStreamSize - 1 do
    begin
      inc(g_pInstrStream, iCurrInstrIndex);
      if (g_pInstrStream^.pOpList <> nil) then
        FreeMem(g_pInstrStream^.pOpList);
      Dec(g_pInstrStream, iCurrInstrIndex);
    end;
    FreeMem(g_pInstrStream);
  end;
  // ----Free the tables
  FreeLinkeList(@g_SymbolTable);
  FreeLinkeList(@g_LabelTable);
  FreeLinkeList(@g_FuncTable);
  FreeLinkeList(@g_StringTable);
  FreeLinkeList(@g_HostAPICallTable);
  // free instrTable
  for iCurrInstrIndex := 0 to Length(g_InstrTable) - 1 do
  begin
    if g_InstrTable[iCurrInstrIndex].OpList <> nil then
      FreeMem(g_InstrTable[iCurrInstrIndex].OpList);
  end;
end;

procedure LoadSourceFile();
var
  iIndex: integer;
  g_SourceCode: TStringList;
  tmpstr: AnsiString;
begin
  if not FileExists(g_pstrSourceFilename) then
  begin
    ExitOnError('Could not open source file');
    Exit;
  end;

  g_SourceCode := TStringList.Create;
  try
    g_SourceCode.LoadFromFile(g_pstrSourceFilename);
    g_iSourceLines := g_SourceCode.Count;
    // �����ַ���,ȡ��ע�ͼ��հ��ַ�
    for iIndex := g_SourceCode.Count - 1 downto 0 do
    begin
      tmpstr := Trim(g_SourceCode[iIndex]);
      StripStrComments(tmpstr);
      if tmpstr = '' then
        g_SourceCode.Delete(iIndex)
      else
        g_SourceCode[iIndex] := tmpstr;
    end;

    g_iSourceCodeSize := g_SourceCode.Count;
    GetMem(g_ppstrSourceCode, sizeof(PAnsiChar) * g_iSourceCodeSize);
    for iIndex := 0 to g_iSourceCodeSize - 1 do
    begin
      inc(g_ppstrSourceCode, iIndex);
      GetMem(g_ppstrSourceCode^, Length(g_SourceCode[iIndex] + #10 + #0));
      StrCopy(g_ppstrSourceCode^, PAnsiChar(AnsiString(g_SourceCode[iIndex] + #10 + #0)));
      Dec(g_ppstrSourceCode, iIndex);
    end;
  finally
    g_SourceCode.Free;
  end;
end;

{$REGION '���Դ����'}

procedure AssmblSourceFile();
var
  iIsFuncActive: Boolean;
  pCurrFunc: pFuncNode;
  iCurrFuncIndex: integer;
  pstrCurrFuncName: array [0 .. MAX_IDENT_SIZE - 1] of AnsiChar; //
  iCurrFuncParamCount: integer;
  iCurrFuncLocalDataSize: integer;
  CurrInstr: InstrLookup;
  //
  pstrIdent: array [0 .. MAX_IDENT_SIZE - 1] of AnsiChar; //
  iSize: integer;
  iStackIndex: integer;
  //
  pstrFuncName: PAnsiChar;
  iEntryPoint: integer;
  iFuncIndex: integer;
  //
  iTargetIndex: integer;
  //
  iCurrInstrIndex: integer;

  //
  iCurrOpIndex: integer;
  CurrOpTypes: OpType;
  pOpList: pOP;
  InitOpToken: Token;
  //
  pstrString: PAnsiChar;
  iStringIndex: integer;
  //
  iBaseIndex: integer;
  IndexToken: Token;
  iOffsetIndex: integer;
  pstrIndexIdent: PAnsiChar;
  //
  pstrLabelIdent: PAnsiChar;
  pLabel: pLabelNode;
  //
  pFunc: pFuncNode;
  //
  pstrHostAPICall: PAnsiChar;
  iIndex: integer;
  //
  AToken: Token;
begin
  // initlize the script header
  g_ScriptHeader.iStackSize := 0;
  g_ScriptHeader.iIsMainFuncPresent := 0; // false
  // set some initial variables
  g_iInstrStreamSize := 0;
  g_bIsSetStackSizeFound := False;
  g_bIsSetPriorityFound := False;
  g_ScriptHeader.iGlobalDataSize := 0;
  // set the current function's flags and variables
  iCurrFuncParamCount := 0;
  iCurrFuncLocalDataSize := 0;
  iIsFuncActive := False;
  // create an instruction definition structure to hold instruction infomation when deling with instructions/
  // ---perform first pass over the source
  // rest the lexer
  ResetLexer();

  while True do
  begin
    // get the next token and make sure we aren't at the  end of the stream
    if (GetNextToken = END_OF_TOKEN_STREAM) then
      Break;
    case g_Lexer.CurrToken of
      // setstacksize
      TOKEN_TYPE_SETSTACKSIZE:
        begin
          // ��ջ��Сֻ������ȫ��������һ��
          if iIsFuncActive then
            ExitOnCodeError(ERROR_MSSG_LOCAL_SETSTACKSIZE);
          if (g_bIsSetStackSizeFound) then
            ExitOnCodeError(ERROR_MSSG_INVALID_STACK_SIZE);
          if (GetNextToken <> TOKEN_TYPE_INT) then
            ExitOnCodeError(ERROR_MSSG_INVALID_STACK_SIZE);

          g_ScriptHeader.iStackSize := StrToInt(GetCurrLexeme);

          g_bIsSetStackSizeFound := True;
        end;
      TOKEN_TYPE_SETPRIORITY:
        begin
          // ֻ����ȫ�����������ȼ�
          if (iIsFuncActive) then
            ExitOnCodeError(ERROR_MSSG_LOCAL_SETPRIORITY);
          // ֻ������һ�����ȼ�
          if g_bIsSetPriorityFound then
            ExitOnCodeError(ERROR_MSSG_MULTIPLE_SETPRIORITY);
          // �жϲ�������
          GetNextToken();
          case (g_Lexer.CurrToken) of
            TOKEN_TYPE_INT:
              begin
                g_ScriptHeader.iUserPriorty := StrToInt(GetCurrLexeme);
                g_ScriptHeader.iPriorityType := PRIORITY_USER;
              end;
            TOKEN_TYPE_IDENT:
              begin
                if StrIComp(PAnsiChar(@g_Lexer.pstrCurrLexeme[0]), PRIORITY_LOW_KEYWORD) = 0 then
                begin
                  g_ScriptHeader.iPriorityType := PRIORITY_LOW;
                end
                else if StrIComp(PAnsiChar(@g_Lexer.pstrCurrLexeme[0]), PRIORITY_MED_KEYWORD) = 0
                then
                begin
                  g_ScriptHeader.iPriorityType := PRIORITY_MED;
                end
                else if StrIComp(PAnsiChar(@g_Lexer.pstrCurrLexeme[0]), PRIORITY_HIGH_KEYWORD) = 0
                then
                begin
                  g_ScriptHeader.iPriorityType := PRIORITY_HIGH;
                end
                else
                begin
                  ExitOnCodeError(ERROR_MSSG_INVALID_PRIORITY);
                end;
              end;
          else
            ExitOnCodeError(ERROR_MSSG_INVALID_PRIORITY);
          end;
          g_bIsSetPriorityFound := True;
        end;
      // VAR VAR[]
      TOKEN_TYPE_VAR:
        begin
          // ��ȡ������ʶ��
          if (GetNextToken <> TOKEN_TYPE_IDENT) then
            ExitOnCodeError(ERROR_MSSG_IDENT_EXPECTED);

          StrCopy(PAnsiChar(@pstrIdent), GetCurrLexeme);
          // ����ͨ��������Ƿ�������Ӷ��ж����Ĵ�С������Ĭ��Ϊ1
          iSize := 1;
          // ���ǰ���Ƿ�����������
          if (GetLookAheadChar = '[') then
          begin
            // ȷ����������
            if (GetNextToken <> TOKEN_TYPE_OPEN_BRACKET) then
              ExitOnCharExpectedError('[');
            // ��Ϊ�����ڷ������飬����һ���������������С������
            if (GetNextToken <> TOKEN_TYPE_INT) then
              ExitOnCodeError(ERROR_MSSG_INVALID_ARRAY_SIZE);
            // ת��Ϊ����ֵ
            iSize := StrToInt(GetCurrLexeme);
            // ȷ����С�Ϸ�,����0
            if iSize <= 0 then
              ExitOnCodeError(ERROR_MSSG_INVALID_ARRAY_SIZE);
            // ȷ���������ŵĺϷ�
            if (GetNextToken <> TOKEN_TYPE_CLOSE_BRACKET) then
              ExitOnCharExpectedError(']');
          end;
          // ���������ڶ�ջ�е�����
          // ����Ǿֲ���������ô���Ķ�ջ����ͨ����
          // ��0��ȥ�ֲ��������ݴ�С+2
          if iIsFuncActive then
          begin
            iStackIndex := -(iCurrFuncLocalDataSize + 2);
          end
          // �����ȫ�ֱ������������൱��Ŀǰȫ�����ݵĸ���
          else
          begin
            iStackIndex := g_ScriptHeader.iGlobalDataSize;
          end;
          // ���԰���������ű�
          if (AddSymbol(PAnsiChar(@pstrIdent), iSize, iStackIndex, iCurrFuncIndex) = -1) then
          begin
            ExitOnCodeError(ERROR_MSSG_IDENT_REDEFINITION);
          end;
          // ����������ͨ��������С����ȫ�ֱ�����ֲ������Ĵ�С
          if iIsFuncActive then
            inc(iCurrFuncLocalDataSize, iSize)
          else
            inc(g_ScriptHeader.iGlobalDataSize, iSize);
        end;
      // func
      TOKEN_TYPE_FUNC:
        begin
          // ����ȷ�ϲ��ں����ڲ�����ΪǶ�׵ĺ����������Ϸ�
          if iIsFuncActive then
          begin
            ExitOnCodeError(ERROR_MSSG_NESTED_FUNC);
          end;
          // ��ȡ��һ�����ʣ�����������
          if (GetNextToken <> TOKEN_TYPE_IDENT) then
            ExitOnCodeError(ERROR_MSSG_IDENT_EXPECTED);

          pstrFuncName := GetCurrLexeme();
          // ���㺯����ڵ㣬��ֱ�Ӹ��ڵ�ǰָ������ָ��
          // Ҳ���൱��ָ������С
          iEntryPoint := g_iInstrStreamSize;
          // ���Ű�����ӵ��������У�����Ѿ����������ӡ����
          iFuncIndex := AddFunc(pstrFuncName, iEntryPoint);
          if (iFuncIndex = -1) then
            ExitOnCodeError(ERROR_MSSG_FUNC_REDEFINITION);
          // �ǲ���������_Main
          if StrIComp(pstrFuncName, MAIN_FUNC_NAME) = 0 then
          begin
            g_ScriptHeader.iIsMainFuncPresent := 1;
            g_ScriptHeader.iMainFuncIndex := iFuncIndex;
          end;
          // �Ѻ������ΪTrue�������ú������ٱ���
          iIsFuncActive := True;
          StrCopy(PAnsiChar(@pstrCurrFuncName), pstrFuncName);
          iCurrFuncIndex := iFuncIndex;
          iCurrFuncParamCount := 0;
          // ��ȡ�������з�ֱ�������������
          while (GetNextToken = TOKEN_TYPE_NEWLINE) do;
          // ȷ�ϵ������������
          if (g_Lexer.CurrToken <> TOKEN_TYPE_OPEN_BRACE) then
            ExitOnCharExpectedError('{');
          // ���к������Զ�׷��Ret�Ĵ�������������ָ���������С
          inc(g_iInstrStreamSize);
        end;
      // close bracket
      TOKEN_TYPE_CLOSE_BRACE:
        begin
          // ����Ӧ���Ǻ����Ľ�β�����Ա�֤���ں����ڲ�
          if not iIsFuncActive then
            ExitOnCharExpectedError('}');
          // ���������ռ�������Ϣ
          SetFuncInfo(@pstrCurrFuncName, iCurrFuncParamCount, iCurrFuncLocalDataSize);
          // �رպ���
          iIsFuncActive := False;
        end;
      // param
      TOKEN_TYPE_PARAM:
        begin
          // if we aren't currently in a function , print an error
          if not iIsFuncActive then
            ExitOnCodeError(ERROR_MSSG_GLOBAL_PARAM);
          // _Main() can't accept parameters,so make sure we aren't in it
          if StrIComp(PAnsiChar(@pstrCurrFuncName), MAIN_FUNC_NAME) = 0 then
            ExitOnCodeError(ERROR_MSSG_MAIN_PARAM);

          // the parameter's identifier should follow
          if (GetNextToken <> TOKEN_TYPE_IDENT) then
            ExitOnCodeError(ERROR_MSSG_IDENT_EXPECTED);
          // increment the current function's local data size
          inc(iCurrFuncParamCount);
        end;
      // ---instruction
      TOKEN_TYPE_INSTR:
        begin
          // make sure we aren't in the global scope,since instructions
          // can onlu appear in functions
          if not iIsFuncActive then
            ExitOnCodeError(ERROR_MSSG_GLOBAL_INSTR);
          // increment the instruction stream size
          inc(g_iInstrStreamSize);
        end;
      TOKEN_TYPE_IDENT:
        begin
          // make sure it's a line label
          if GetLookAheadChar <> ':' then
            ExitOnCodeError(ERROR_MSSG_INVALID_INSTR);
          // make sure we're in a fucntion,since labels can only appear there
          if not iIsFuncActive then
            ExitOnCodeError(ERROR_MSSG_GLOBAL_LINE_LABEL);
          // the current lexeme is the labek's identifier
          StrCopy(PAnsiChar(@pstrIdent), GetCurrLexeme);
          // the target instruction is always the value of the current
          // instruction count,which is the current size -1
          iTargetIndex := g_iInstrStreamSize - 1;
          // save the label's function index as well
          iFuncIndex := iCurrFuncIndex;
          // try adding the label to the label table,and print an error if it already exists
          if (AddLabel(@pstrIdent, iTargetIndex, iFuncIndex) = -1) then
            ExitOnCodeError(ERROR_MSSG_LINE_LABEL_REDEFINITION);
        end;
    else
      // anything else should cause an error, minus line breaks
      if g_Lexer.CurrToken <> TOKEN_TYPE_NEWLINE then
        ExitOnCodeError(ERROR_MSSG_INVALID_INPUT);
    end;
    // skip to the next line,since the initial tokens are all we're really worrid
    // about in this phase
    if (not SkipToNextLine()) then
      Break;
  end;
  // the second loop

  // we counted the instructions,so allocate the assembled instruction stream array
  // so the next phase can begin
  GetMem(g_pInstrStream, g_iInstrStreamSize * sizeof(InStr));
  // initialize every operand list pointer to null
  for iCurrInstrIndex := 0 to g_iInstrStreamSize - 1 do
  begin
    inc(g_pInstrStream, iCurrInstrIndex);
    g_pInstrStream^.pOpList := nil;
    Dec(g_pInstrStream, iCurrInstrIndex);
  end;
  // set current instruction index to zero
  g_iCurrInstrCount := 0;
  // perform the second pass over the source
  // reset the lexer so we begin at the top of the source again
  ResetLexer();
  // loop through each line of code
  while True do
  begin
    if (GetNextToken = END_OF_TOKEN_STREAM) then
      Break;

    case g_Lexer.CurrToken of
      // func
      TOKEN_TYPE_FUNC:
        begin
          GetNextToken();
          pCurrFunc := GetFuncByName(GetCurrLexeme);
          iIsFuncActive := True;
          iCurrFuncParamCount := 0;
          iCurrFuncIndex := pCurrFunc.iIndex;
          // read any number of line breaks until the opening is found
          while (GetNextToken = TOKEN_TYPE_NEWLINE) do;
        end;
      TOKEN_TYPE_CLOSE_BRACE:
        begin
          iIsFuncActive := False;
          if (StrIComp(PAnsiChar(@pCurrFunc.pstrName), MAIN_FUNC_NAME) = 0) then
          begin
            inc(g_pInstrStream, g_iCurrInstrIndex);
            g_pInstrStream.iOpcode := INSTR_EXIT;
            g_pInstrStream.iOpcount := 1;
            GetMem(g_pInstrStream.pOpList, sizeof(OP));
            g_pInstrStream.pOpList.iType := OP_TYPE_INT;
            g_pInstrStream.pOpList.iIntLiteral := 0;
            Dec(g_pInstrStream, g_iCurrInstrIndex);
          end
          else
          begin
            inc(g_pInstrStream, g_iCurrInstrIndex);
            g_pInstrStream.iOpcode := INSTR_RET;
            g_pInstrStream.iOpcount := 0;
            g_pInstrStream.pOpList := nil;
            Dec(g_pInstrStream, g_iCurrInstrIndex);
          end;
          inc(g_iCurrInstrIndex);
        end;
      // param
      TOKEN_TYPE_PARAM:
        begin
          if (GetNextToken <> TOKEN_TYPE_IDENT) then
            ExitOnCodeError(ERROR_MSSG_IDENT_EXPECTED);
          StrCopy(PAnsiChar(@pstrIdent), GetCurrLexeme);

          iStackIndex := -(pCurrFunc.iLocalDataSize + 2 + (iCurrFuncParamCount + 1));
          // add the parameter to the symbol table
          if AddSymbol(@pstrIdent, 1, iStackIndex, iCurrFuncIndex) = -1 then
          begin
            ExitOnCodeError(ERROR_MSSG_IDENT_REDEFINITION);
          end;
          inc(iCurrFuncParamCount);
        end;
      TOKEN_TYPE_INSTR:
        begin
          GetInstrByMnemonic(GetCurrLexeme, @CurrInstr);
          inc(g_pInstrStream, g_iCurrInstrIndex);
          g_pInstrStream.iOpcode := CurrInstr.iOpcode;
          g_pInstrStream.iOpcount := CurrInstr.iOpcount;
          Dec(g_pInstrStream, g_iCurrInstrIndex);
          // allocate space to hold the oprand list
          GetMem(pOpList, CurrInstr.iOpcount * sizeof(OP));
          for iCurrOpIndex := 0 to CurrInstr.iOpcount - 1 do
          begin
            // point to the des data
            inc(pOpList, iCurrOpIndex);
            CurrOpTypes := GetCurrOpType(CurrInstr.OpList, iCurrOpIndex);
            InitOpToken := GetNextToken;
            case InitOpToken of
              TOKEN_TYPE_INT:
                begin
                  if (CurrOpTypes and OP_FLAG_TYPE_INT) <> 0 then
                  begin
                    pOpList.iType := OP_TYPE_INT;
                    pOpList.iInstrIndex := StrToInt(GetCurrLexeme);
                  end
                  else
                  begin
                    ExitOnCodeError(ERROR_MSSG_INVALID_OP);
                  end;
                end;
              TOKEN_TYPE_FLOAT:
                begin
                  if (CurrOpTypes and OP_FLAG_TYPE_FLOAT) <> 0 then
                  begin
                    pOpList.iType := OP_TYPE_FLOAT;
                    pOpList.fFloatLiteral := StrToFloat(GetCurrLexeme);
                  end
                  else
                  begin
                    ExitOnCodeError(ERROR_MSSG_INVALID_OP);
                  end;
                end;
              TOKEN_TYPE_QUOTE:
                begin
                  if (CurrOpTypes and OP_FLAG_TYPE_STRING) <> 0 then
                  begin
                    GetNextToken;
                    case g_Lexer.CurrToken of
                      TOKEN_TYPE_QUOTE:
                        begin
                          pOpList.iType := OP_TYPE_INT;
                          pOpList.iIntLiteral := 0;
                        end;
                      TOKEN_TYPE_STRING:
                        begin
                          pstrString := GetCurrLexeme;
                          iStringIndex := Addstring(@g_StringTable, pstrString);
                          if (GetNextToken <> TOKEN_TYPE_QUOTE) then
                            ExitOnCharExpectedError('\');

                          pOpList.iType := OP_TYPE_STRING_INDEX;
                          pOpList.iStringTableIndex := iStringIndex;
                        end;
                    else
                      ExitOnCodeError(ERROR_MSSG_INVALID_OP);
                    end;
                  end
                  else
                    ExitOnCodeError(ERROR_MSSG_INVALID_OP);
                end;
              TOKEN_TYPE_REG_RETVAL:
                begin
                  if (CurrOpTypes and OP_FLAG_TYPE_REG) <> 0 then
                  begin
                    pOpList.iType := OP_TYPE_REG;
                    pOpList.iReg := 0;
                  end
                  else
                  begin
                    ExitOnCodeError(ERROR_MSSG_INVALID_OP);
                  end;
                end;
              TOKEN_TYPE_IDENT:
                begin
                  if (CurrOpTypes and OP_FLAG_TYPE_MEM_REF) <> 0 then
                  begin
                    StrCopy(PAnsiChar(@pstrIdent), GetCurrLexeme);
                    if (GetSymbolByIdent(@pstrIdent, iCurrFuncIndex) = nil) then
                    begin
                      ExitOnCodeError(ERROR_MSSG_UNDEFINED_IDENT);
                    end;
                    //
                    iBaseIndex := GetStackIndexByIdent(@pstrIdent, iCurrFuncIndex);
                    if GetLookAheadChar() <> '[' then
                    begin
                      if (GetSizeByIdent(@pstrIdent, iCurrFuncIndex) > 1) then
                      begin
                        ExitOnCodeError(ERROR_MSSG_INVALID_ARRAY_NOT_INDEXED);
                      end;
                      pOpList.iType := OP_TYPE_ABS_STACK_INDEX;
                      pOpList.iIntLiteral := iBaseIndex;
                    end
                    else
                    begin
                      if (GetSizeByIdent(@pstrIdent, iCurrFuncIndex) = 1) then
                      begin
                        ExitOnCodeError(ERROR_MSSG_INVALID_ARRAY);
                      end;
                      if (GetNextToken <> TOKEN_TYPE_OPEN_BRACKET) then
                      begin
                        ExitOnCharExpectedError('[');
                      end;
                      IndexToken := GetNextToken;
                      if IndexToken = TOKEN_TYPE_INT then
                      begin
                        iOffsetIndex := StrToInt(GetCurrLexeme);
                        pOpList.iType := OP_TYPE_ABS_STACK_INDEX;
                        pOpList.iStackIndex := iBaseIndex + iOffsetIndex;
                      end
                      else if IndexToken = TOKEN_TYPE_IDENT then
                      begin
                        pstrIndexIdent := GetCurrLexeme;
                        if GetSymbolByIdent(pstrIndexIdent, iCurrFuncIndex) = nil then
                        begin
                          ExitOnCodeError(ERROR_MSSG_UNDEFINED_IDENT);
                        end;
                        if (GetSizeByIdent(pstrIndexIdent, iCurrFuncIndex) > 1) then
                        begin
                          ExitOnCodeError(ERROR_MSSG_INVALID_ARRAY_INDEX);
                        end;
                        iOffsetIndex := GetStackIndexByIdent(pstrIndexIdent, iCurrFuncIndex);
                        pOpList.iType := OP_TYPE_REL_STACK_INDEX;
                        pOpList.iStackIndex := iBaseIndex;
                        pOpList.iOffserIndex := iOffsetIndex;
                      end
                      else
                      begin
                        ExitOnCodeError(ERROR_MSSG_INVALID_ARRAY_INDEX);
                      end;
                      if (GetNextToken <> TOKEN_TYPE_CLOSE_BRACKET) then
                      begin
                        ExitOnCharExpectedError('[');
                      end;
                    end;
                  end;
                  // label
                  if (CurrOpTypes and OP_FLAG_TYPE_LINE_LABEL) <> 0 then
                  begin
                    pstrLabelIdent := GetCurrLexeme;
                    pLabel := GetLabelByIdent(pstrLabelIdent, iCurrFuncIndex);
                    if pLabel = nil then
                    begin
                      ExitOnCodeError(ERROR_MSSG_UNDEFINED_LINE_TABEL);
                    end;
                    pOpList.iType := OP_TYPE_INSTR_INDEX;
                    pOpList.iInstrIndex := pLabel.iTargetIndex;
                  end;
                  // function name
                  if (CurrOpTypes and OP_FLAG_TYPE_FUNC_NAME) <> 0 then
                  begin
                    pstrFuncName := GetCurrLexeme;
                    pFunc := GetFuncByName(pstrFuncName);
                    if (pFunc = nil) then
                    begin
                      ExitOnCodeError(ERROR_MSSG_UNDEFINED_FUNC);
                    end;
                    pOpList.iType := OP_TYPE_FUNC_INDEX;
                    pOpList.iFuncIndex := pFunc.iIndex;
                  end;
                  // host api
                  if (CurrOpTypes and OP_FLAG_TYPE_HOST_API_CALL) <> 0 then
                  begin
                    pstrHostAPICall := GetCurrLexeme;
                    iIndex := Addstring(@g_HostAPICallTable, pstrHostAPICall);

                    pOpList.iType := OP_TYPE_HOST_API_CALL_INDEX;
                    pOpList.iHostAPICallIndex := iIndex;
                  end;
                end;
            else
              ExitOnCodeError(ERROR_MSSG_INVALID_OP);
            end;

            if (iCurrOpIndex < CurrInstr.iOpcount - 1) then
              if (GetNextToken <> TOKEN_TYPE_COMMA) then
                ExitOnCharExpectedError(',');
            // reser the point
            Dec(pOpList, iCurrOpIndex);
          end;
          // make sure there's no extranous stuff ahead
          if (GetNextToken <> TOKEN_TYPE_NEWLINE) then
            ExitOnCodeError(ERROR_MSSG_INVALID_INPUT);
          inc(g_pInstrStream, g_iCurrInstrIndex);
          g_pInstrStream.pOpList := pOpList;
          Dec(g_pInstrStream, g_iCurrInstrIndex);
          inc(g_iCurrInstrIndex);
        end;
    end;
    // skip to the next line
    if (not SkipToNextLine) then
      Break;
  end;
end;
{$ENDREGION}

procedure PrintAssmblStats();
var
  iVarCount: integer;
  iArrayCount: integer;
  iGlobalCount: integer;
  pCurrNode: pLinkedListNode;
  iCurrNode: integer;
  pCurrSymbol: pSymbolNode;
begin
  iVarCount := 0;
  iArrayCount := 0;
  iGlobalCount := 0;
  //
  pCurrNode := g_SymbolTable.pHead;
  for iCurrNode := 0 to g_SymbolTable.iNodeCount - 1 do
  begin
    pCurrSymbol := pSymbolNode(pCurrNode.pData);
    if (pCurrSymbol.iSize > 1) then
      inc(iArrayCount)
    else
      inc(iVarCount);

    if (pCurrSymbol.iStackIndex >= 0) then
      inc(iGlobalCount);
    //
    pCurrNode := pCurrNode.pNext;
  end;

  Writeln(Format('%s created successfully!' + #13#10, [g_pstrExecFilename]));
  Writeln(Format('Source Lines Processed: %d/%d', [g_iSourceCodeSize, g_iSourceLines]));
  Write('            Stack Size: ');
  if (g_ScriptHeader.iStackSize <> 0) then
    Writeln(Format('%d', [g_ScriptHeader.iStackSize]))
  else
    Writeln('Default');

  Write('              Priority: ');
  case g_ScriptHeader.iPriorityType of
    PRIORITY_USER:
      Writeln(Format('%d ms', [g_ScriptHeader.iUserPriorty]));
    PRIORITY_LOW:
      Writeln(PRIORITY_LOW_KEYWORD);
    PRIORITY_MED:
      Writeln(PRIORITY_MED_KEYWORD);
    PRIORITY_HIGH:
      Writeln(PRIORITY_HIGH_KEYWORD);
  else
    Writeln('Invalid Priority');
  end;

  Writeln(Format('Instructions Assembled: %d', [g_iInstrStreamSize]));
  Writeln(Format('             Varisbles: %d', [iVarCount]));
  Writeln(Format('                Arrays: %d', [iArrayCount]));
  Writeln(Format('               Globals: %d', [iGlobalCount]));
  Writeln(Format('       String Literals: %d', [g_StringTable.iNodeCount]));
  Writeln(Format('                Labels: %d', [g_LabelTable.iNodeCount]));
  Writeln(Format('        Host API Calls: %d', [g_HostAPICallTable.iNodeCount]));
  Writeln(Format('             Functions: %d', [g_FuncTable.iNodeCount]));

  Write('      _Main () Present:');
  if (g_ScriptHeader.iIsMainFuncPresent <> 0) then
    Writeln(Format(' Yes [index %d]', [g_ScriptHeader.iMainFuncIndex]))
  else
    Writeln('No');
end;

procedure BuildXSE();
var
  pExecFile: THandle;
  cVersionMajor: AnsiChar;
  cVersionMinor: AnsiChar;
  XSE: array [0 .. 3] of AnsiChar;
  iCurrInstrIndex: integer;
  sOpcode: SmallInt;
  iOpcount: integer;
  iCurrOpIndex: integer;
  CurrOP: pOP;
  // string
  iCurrNode: integer;
  pNode: pLinkedListNode;
  pstrCurrString: PAnsiChar;
  iCurrStringLength: integer;
  // func
  pFunc: pFuncNode;
  cFuncNameLength: integer;
  // host api
  pstrCurrHostAPICall: PAnsiChar;
  iCurrHostLength: integer;
begin
  if FileExists(g_pstrExecFilename) then
  begin
    DeleteFile(g_pstrExecFilename);
  end;
  pExecFile := FileCreate(g_pstrExecFilename);

  // дID�ַ�����4�ֽڣ�
  StrCopy(PAnsiChar(@XSE), PAnsiChar(AnsiString(XSE_ID_STRING)));
  FileWrite(pExecFile, XSE, 4);
  // д�汾      1/1  2
  cVersionMajor := AnsiChar(VERSION_MAJOR);
  cVersionMinor := AnsiChar(VERSION_MINOR);
  FileWrite(pExecFile, cVersionMajor, 1);
  FileWrite(pExecFile, cVersionMinor, 1);
  // д��ջ��С   4
  FileWrite(pExecFile, g_ScriptHeader.iStackSize, 4);
  // ȫ�����ݴ�С  4
  FileWrite(pExecFile, g_ScriptHeader.iGlobalDataSize, 4);
  // д_Main ���  1
  FileWrite(pExecFile, AnsiChar(g_ScriptHeader.iIsMainFuncPresent), 1);
  // д_Main��������
  FileWrite(pExecFile, g_ScriptHeader.iMainFuncIndex, 4);
  // д���ȼ�
  FileWrite(pExecFile, g_ScriptHeader.iPriorityType, 1);
  // д�û������ʱ��Ƭ
  FileWrite(pExecFile, g_ScriptHeader.iUserPriorty, 4);
  // ���ָ������ 4
  FileWrite(pExecFile, g_iInstrStreamSize, 4);
  // ��23
  // ��ÿ��ָ����ѭ��
  for iCurrInstrIndex := 0 to g_iInstrStreamSize - 1 do
  begin
    inc(g_pInstrStream, iCurrInstrIndex);
    // д������ 2
    sOpcode := g_pInstrStream.iOpcode;
    FileWrite(pExecFile, sOpcode, 2);
    // д������������ 1
    iOpcount := g_pInstrStream.iOpcount;
    FileWrite(pExecFile, AnsiChar(iOpcount), 1);
    // �Բ������б�ѭ������ÿ��������д��
    for iCurrOpIndex := 0 to iOpcount - 1 do
    begin
      CurrOP := g_pInstrStream.pOpList;
      inc(CurrOP, iCurrOpIndex);
      FileWrite(pExecFile, CurrOP.iType, 1);
      // ���ݲ���������д������
      case CurrOP.iType of
        // ����������
        OP_TYPE_INT:
          FileWrite(pExecFile, CurrOP.iIntLiteral, sizeof(integer));
        // ����������
        OP_TYPE_FLOAT:
          FileWrite(pExecFile, CurrOP.fFloatLiteral, sizeof(Single));
        // �ַ�������
        OP_TYPE_STRING_INDEX:
          FileWrite(pExecFile, CurrOP.iStringTableIndex, sizeof(integer));
        // ָ������
        OP_TYPE_INSTR_INDEX:
          FileWrite(pExecFile, CurrOP.iInstrIndex, sizeof(integer));
        // ���Զ�ջ����
        OP_TYPE_ABS_STACK_INDEX:
          FileWrite(pExecFile, CurrOP.iStackIndex, sizeof(integer));
        // ��Զ�ջ����
        OP_TYPE_REL_STACK_INDEX:
          begin
            FileWrite(pExecFile, CurrOP.iStackIndex, sizeof(integer));
            FileWrite(pExecFile, CurrOP.iOffserIndex, sizeof(integer));
          end;
        // ��������
        OP_TYPE_FUNC_INDEX:
          FileWrite(pExecFile, CurrOP.iFuncIndex, sizeof(integer));
        // ��Ӧ�ó���API����
        OP_TYPE_HOST_API_CALL_INDEX:
          FileWrite(pExecFile, CurrOP.iHostAPICallIndex, sizeof(integer));
        // �Ĵ���
        OP_TYPE_REG:
          FileWrite(pExecFile, CurrOP.iReg, sizeof(integer));
      end;
      Dec(CurrOP, iCurrOpIndex);
    end;
    Dec(g_pInstrStream, iCurrInstrIndex);
  end;
  // �ַ���
  // д�ַ�������
  FileWrite(pExecFile, g_StringTable.iNodeCount, 4);
  // ��ָ�����õ�����ͷ
  pNode := g_StringTable.pHead;
  //
  for iCurrNode := 0 to g_StringTable.iNodeCount - 1 do
  begin
    // �����ַ��������㳤��
    pstrCurrString := PAnsiChar(pNode.pData);
    iCurrStringLength := StrLen(pstrCurrString);
    // д�ַ�������
    FileWrite(pExecFile, AnsiChar(iCurrStringLength), 4);
    FileWrite(pExecFile, pstrCurrString^, StrLen(pstrCurrString));
    pNode := pNode.pNext;
  end;
  // ������
  FileWrite(pExecFile, g_FuncTable.iNodeCount, 4);
  // ��ָ�����õ�����ͷ
  pNode := g_FuncTable.pHead;
  // ��������ÿ���ڵ�ѭ����д���ǵ��ַ�����Ϣ
  for iCurrNode := 0 to g_FuncTable.iNodeCount - 1 do
  begin
    // ����
    pFunc := pFuncNode(pNode.pData);
    // д����ڵ� 4
    FileWrite(pExecFile, pFunc.iEntryPoint, sizeof(integer));
    // д���������� 1
    FileWrite(pExecFile, AnsiChar(pFunc.iParamCount), 1);
    // д���ֲ����ݴ�С4
    FileWrite(pExecFile, pFunc.iLocalDataSize, sizeof(integer));
    // д���������� 1�ֽ�
    cFuncNameLength := StrLen(pFunc.pstrName);
    FileWrite(pExecFile, cFuncNameLength, 1);
    // д������ N
    FileWrite(pExecFile, pFunc.pstrName, cFuncNameLength);
    // �Ƶ���һ��
    pNode := pNode.pNext;
  end;
  // ��Ӧ�ó���API
  FileWrite(pExecFile, g_HostAPICallTable.iNodeCount, 4);
  // ��ָ�����õ�����ͷ
  pNode := g_HostAPICallTable.pHead;
  // ��������ÿ���ڵ�ѭ����д���ǵ��ַ���
  for iCurrNode := 0 to g_HostAPICallTable.iNodeCount - 1 do
  begin
    // �����ַ���ָ�벢���㳤��
    pstrCurrHostAPICall := PAnsiChar(pNode.pData);
    iCurrHostLength := StrLen(pstrCurrHostAPICall);
    // д����1
    FileWrite(pExecFile, AnsiChar(iCurrHostLength), 1);
    // д�ַ�������N
    FileWrite(pExecFile, pstrCurrHostAPICall^, StrLen(pstrCurrHostAPICall));
    // �ƶ�����һ�ڵ�
    pNode := pNode.pNext;
  end;
  FileClose(pExecFile);
end;

procedure MyExit();
begin
  ShutDown;
  Exit;
end;

{$REGION '������'}

procedure ExitOnCodeError(pstrErrorMssg: PAnsiChar);
var
  pstrSourceLine: AnsiString;
  iCurrCharIndex: integer;
begin
  Writeln(Format('Error:%s', [pstrErrorMssg]));
  Writeln(Format('Line %d', [g_Lexer.iCurrSourceLine]));

  pstrSourceLine := GetCurrSourceStr(g_Lexer.iCurrSourceLine);
  for iCurrCharIndex := 0 to Length(pstrSourceLine) - 1 do
    if pstrSourceLine[iCurrCharIndex] = '\t' then
      pstrSourceLine[iCurrCharIndex] := ' ';

  Writeln(Format('%s', [pstrSourceLine]));

  for iCurrCharIndex := 0 to g_Lexer.iIndex0 - 1 do
    Writeln(' ');

  Writeln(Format('Could not assemble %s', [g_pstrExecFilename]));
  Exit;
end;

procedure ExitOnCharExpectedError(cChar: AnsiChar);
var
  pstrErrorMssg: AnsiString;
begin
  pstrErrorMssg := Format('%s expected ', [cChar]);
  ExitOnCodeError(PAnsiChar(pstrErrorMssg));
end;
{$ENDREGION}

end.
