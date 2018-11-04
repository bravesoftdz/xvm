{ ******************************************************* }
{                                                         }
{ XVM                                                     }
{                                                         }
{ ��Ȩ���� (C) 2012 adsj                                  }
{ Mode�� ��������ģ��                                     }
{ ******************************************************* }

unit code_emnit;

interface

uses
  System.SysUtils, globals, symbol_table, func_table, i_code, linked_list;

const
  ppstrMnemonics: array [0 .. 32] of AnsiString = ('Mov', 'Add', 'Sub', 'Mul', 'Div', 'Mod', 'Exp',
    'Neg', 'Inc', 'Dec', 'And', 'Or', 'XOr', 'Not', 'ShL', 'ShR', 'Concat', 'GetChar', 'SetChar',
    'Jmp', 'JE', 'JNE', 'JG', 'JL', 'JGE', 'JLE', 'Push', 'Pop', 'Call', 'Ret', 'CallHost',
    'Pause', 'Exit');
  // ----------------------------------------------------------
  (* ����ͷ�ļ� *)
procedure EmitHeader();
(* ���ɻ������ *)
procedure EmitDirectives();
(* ���ɷ������� *)
procedure EmitScopeSymbols(iScope: Integer; iType: Integer);
(* ���ɺ��� *)
procedure EmitFunc(pFunc: pFuncNode);
(* ��������XASM *)
procedure EmitCode();

// ----------------------------------------------------------
var
  sf: TextFile;

  // ----------------------------------------------------------
implementation

uses codesitelogging;

function madespace(icount: Integer): AnsiString;
var
  i: Integer;
begin
  Result := '';
  if icount <= 0 then
  begin
    Exit;
  end;

  for i := 0 to icount - 1 do
    Result := Result + ' ';
end;

procedure EmitCode();
var
  pNode: pLinkedListNode;
  pCurrFunc: pFuncNode;
  pMainFunc: pFuncNode;
begin
  g_pstrOutPutFileName := 'C:\2.txt';
  AssignFile(sf, g_pstrOutPutFileName);
  Rewrite(sf);
  // ----�����ļ�ͷ
  EmitHeader();
  // ----��������
  Writeln(sf, '; ---- Directives---------------------');
  EmitDirectives();
  // ----����ȫ�ֱ�������
  Writeln(sf, '; ---- Global Variables --------------');
  EmitScopeSymbols(SCOPE_GLOBAL, 0);
  // ----���ɺ���
  Writeln(sf, '; ---- Functions ---------------------');
  // ��������ֲ��ڵ�
  pNode := g_FuncTable.pHead;
  // �ֲ������ڵ�ָ��
  pCurrFunc := nil;
  // ��������˺���_Main(),����ָ�뱣��
  pMainFunc := nil;
  // ����ÿ�����������ʹ���
  if g_FuncTable.iNodeCount > 0 then
  begin
    while True do
    begin
      // ��ýڵ�ָ��
      pCurrFunc := pFuncNode(pNode.pData);
      // ����������Ӧ�ó���API�����ڵ�
      if pCurrFunc.iIsHostAPI = 0 then
      begin
        // ��ǰ����_Main()
        if StrIComp(pCurrFunc.pstrName, MAIN_FUNC_NAME) = 0 then
        begin
          // �ǣ������Ա�����
          pMainFunc := pCurrFunc;
        end
        else
        begin
          // ���ǣ���ô����
          EmitFunc(pCurrFunc);
          Write(sf, #13#10#13#10); // \n\n
        end;
      end;
      // next node
      pNode := pNode.pNext;
      if pNode = nil then
        Break;
    end;
  end;
  // ----����_Main()
  Writeln(sf, '; ---- Main -------------------------------');
  // ������_Main(),�Ǿ������������
  if pMainFunc <> nil then
  begin
    Write(sf, #13#10#13#10);
    EmitFunc(pMainFunc);
  end;
  // �ر��ļ�
  Flush(sf);
  Close(sf);
end;

procedure EmitHeader();
begin
  Writeln(sf, Format('; %s', [g_pstrOutPutFileName]));
  Writeln(sf, Format('; Source File: %s', [g_pstrSourceFileName]));
  Writeln(sf, Format('; XSC Version: %d.%d', [VERSION_MAJOR, VERSION_MINOR]));
  Writeln(sf, Format('; Timestamp: %s', [FormatDateTime('yyyy-mm-dd-hh:MM:ss', Now)]));
end;

procedure EmitDirectives();
begin
  if g_ScriptHeader.iStackSize <> 0 then
  begin
    Writeln(sf, Format('        SetStackSize %d', [g_ScriptHeader.iStackSize]));
  end;
  // ����趨�����ȼ�SetPriority����
  if g_ScriptHeader.iPriorityType <> PRIORITY_NONE then
  begin
    Write(sf, '        SetPriority ');
    case g_ScriptHeader.iPriorityType of
      PRIORITY_LOW:
        Writeln(sf, PRIORITY_LOW_KEYWORD);
      PRIORITY_MED:
        Writeln(sf, PRIORITY_MED_KEYWORD);
      PRIORITY_HIGH:
        Writeln(sf, PRIORITY_HIGH_KEYWORD);
      PRIORITY_USER:
        Writeln(sf, Format('%d', [g_ScriptHeader.iUserPriority]));
    end;
  end;
end;

procedure EmitScopeSymbols(iScope: Integer; iType: Integer);
var
  pCurrSymbol: PSymbolNode;
  iCurrSymbolIndex: Integer;
  bAddNewLine: Boolean;
begin
  for iCurrSymbolIndex := 0 to g_SymbolTable.iNodeCount - 1 do
  begin
    pCurrSymbol := GetSymbolByIndex(iCurrSymbolIndex);
    if (pCurrSymbol.iScope = iScope) and (pCurrSymbol.iType = iType) then
    begin
      Write(sf, madespace(4));
      if iScope <> SCOPE_GLOBAL then
        Write(sf, madespace(4));
      if pCurrSymbol.iType = SYMBOL_TYPE_PARAM then
        Write(sf, Format('Param  %s', [pCurrSymbol.pstrIdent]));
      if pCurrSymbol.iType = SYMBOL_TYPE_VAR then
      begin
        Write(sf, Format('Var  %s', [pCurrSymbol.pstrIdent]));
        if pCurrSymbol.iSize > 1 then
          Write(sf, Format('[ %d ]', [pCurrSymbol.iSize]));
      end;
      Writeln(sf, '');
      // bAddNewLine := True;
    end;
  end;
  // if bAddNewLine then
  // Writeln(sf, '');
end;

procedure EmitFunc(pFunc: pFuncNode);
var
  iIsFirstSourceLine: Boolean;
  iCurrInstrIndex: Integer;
  pCurrNode: pICodeNode;
  // source tag
  pstrSourceLine: PAnsiChar;
  iLastCharIndex: Integer;
  //
  iOpCount: Integer;
  iCurrOpIndex: Integer;
  apOp: pOp;
  //
  ispace: Integer;
begin
  // ���ɺ�������
  Writeln(sf, Format('Func %s', [pFunc.pstrName]));
  Writeln(sf, madespace(4) + '{');
  // ���ɺ�����������
  EmitScopeSymbols(pFunc.iIndex, SYMBOL_TYPE_PARAM);
  // ���ɾֲ���������
  EmitScopeSymbols(pFunc.iIndex, SYMBOL_TYPE_VAR);

  if pFunc.ICodeStream.iNodeCount > 0 then
  begin
    iIsFirstSourceLine := True;

    for iCurrInstrIndex := 0 to pFunc.ICodeStream.iNodeCount - 1 do
    begin
      pCurrNode := GetICodeNodeByImpIndex(pFunc.iIndex, iCurrInstrIndex);

      case pCurrNode.iType of
        // Դ�����ע
        ICODE_NODE_SOURCE_LINE:
          begin
            //
            pstrSourceLine := pCurrNode.pstrSourceLine;
            iLastCharIndex := StrLen(pstrSourceLine) - 1;
            if pstrSourceLine[iLastCharIndex] = #10 then
              pstrSourceLine[iLastCharIndex] := #0;
            // ����ע�ͣ�������ǵ�һ�еĻ�Ԥ�ȼ���һ�����з�
            if not iIsFirstSourceLine then
              Writeln(sf, '');

            Writeln(sf, Format(madespace(8) + '; %s', [trim(AnsiString(pstrSourceLine))])); // \n\n
          end;
        // �м����ָ��
        ICODE_NODE_INSTR:
          begin
            // ���ɲ�����
            Write(sf, Format(madespace(8) + '%s', [ppstrMnemonics[pCurrNode.Instr.iOpcode]]));
            iOpCount := pCurrNode.Instr.OpList.iNodeCount;
            if iOpCount > 0 then
            begin
              // ÿ��ָ������һ��TAB
              // Write(sf, madespace(8));
              // ����ַ�̫�����ټ�һ��TAB
              if Length(ppstrMnemonics[pCurrNode.Instr.iOpcode]) < TAB_STOP_WIDTH then
                Write(sf, madespace(TAB_STOP_WIDTH -
                  Length(ppstrMnemonics[pCurrNode.Instr.iOpcode])));

              for iCurrOpIndex := 0 to iOpCount - 1 do
              begin
                apOp := GetICodeOpByIndex(pCurrNode, iCurrOpIndex);

                case apOp.iType of
                  OP_TYPE_INT:
                    Write(sf, ' ' + IntToStr(apOp.iIntLiteral));
                  OP_TYPE_FLOAT:
                    Write(sf, ' ' + floattostr(apOp.fFloatLiteral));
                  OP_TYPE_STRING_INDEX:
                    Write(sf, Format(' "%s"', [GetStringByIndex(@g_StringTable,
                      apOp.iStringIndex)]));
                  OP_TYPE_VAR:
                    Write(sf, Format(' %s', [GetSymbolByIndex(apOp.iSymbolIndex).pstrIdent]));
                  OP_TYPE_ARRAY_INDEX_ABS:
                    Write(sf, Format(' %s [ %d ]', [GetSymbolByIndex(apOp.iSymbolIndex).pstrIdent,
                      apOp.iOffset]));
                  OP_TYPE_ARRAY_INDEX_VAR:
                    Write(sf, Format(' %s [ %s ]', [GetSymbolByIndex(apOp.iStringIndex).pstrIdent,
                      GetSymbolByIndex(apOp.iOffsetSymbolIndex).pstrIdent]));
                  OP_TYPE_FUNC_INDEX:
                    Write(sf, Format(' %s', [GetFuncByIndex(apOp.iSymbolIndex).pstrName]));
                  OP_TYPE_REG:
                    Write(sf, '_RetVal');
                  OP_TYPE_JUMP_TARGET_INDEX:
                    Write(sf, Format(' _L%d', [apOp.iJumpTargetIndex]));
                end;
                if iCurrOpIndex <> iOpCount - 1 then
                  Write(sf, ', ');
              end;
            end;
            Write(sf, #13#10);
          end;
        // ��תĿ��
        ICODE_NODE_JUMP_TARGET:
          Writeln(sf, Format(madespace(8) + ' _L%d:', [pCurrNode.iJumpTargetIndex]));
      end;
      if iIsFirstSourceLine then
        iIsFirstSourceLine := False;
    end;

  end
  else
    Writeln(sf, madespace(8) + '; (No Code)');
  Writeln(sf, madespace(4) + '}');
end;

end.
