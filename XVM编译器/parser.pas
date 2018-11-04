{ ******************************************************* }
{                                                         }
{ XVM                                                     }
{                                                         }
{ ��Ȩ���� (C) 2012 adsj                                  }
{ Mode�� �﷨������ģ��                                   }
{      ע:1.�ݲ�֧�� Forѭ��(����˵������Ԥ����׶�       }
{          ��ForתΪWhile)                                }
{         2.�ݲ�֧�� ++X��ǰ�õ�Ŀ����                    }
{ ******************************************************* }
unit parser;

interface

uses
  System.SysUtils, globals, errors, Lexer, stacks, symbol_table, linked_list, func_table, i_code;

const
  MAX_FUNC_DECLARE_PARAM_COUNT = 32;

type
  // ----------------------------------------------------------
  _Expr = record
    iStackOffset: Integer;
  end;

  Expr = _Expr;

  // ----------------------------------------------------------
  Loop = record
    iStartTargetIndex: Integer;
    iEndTargetIndex: Integer;
  end;

  pLoop = ^Loop;
  // ----------------------------------------------------------
  (* �����ض������Է� *)
procedure ReadToken(const ReqToken: Token);

// ----------------------------------------------------------
// �ķ�����
(* ����ȫ�ַ�Χ��� *)
procedure ParseSourceCode();
(* ��� *)
procedure ParseStatement();
(* �� *)
procedure ParseBlock();
(* �������������� Var [] *)
procedure ParseVar();
(* ��Ӧ�ó��� API *)
procedure ParseHost();
(* ���� Func *)
procedure ParseFuncCall();
procedure ParseFunc();

(* �������ʽ *)
// �����ӱ��ʽ
procedure ParseFactor();
procedure ParseSubExpr();
procedure ParseTerm();
procedure ParseExpr();
// ��ֵ���
procedure ParseAssign();
// �����߼�
procedure ParseIf();
procedure ParseWhile();
procedure ParseFor();
procedure ParseBreak();
procedure ParseContinue();
procedure ParseReturn();
// ----------------------------------------------------------
procedure printError(error: PAnsiChar);

var
  // ��ǰ��Χ
  // 0ȫ��
  // ~0��ʾ��ǰ�����ں������е�����
  g_iCurrScope: Integer;
  g_LoopStack: Stack;

implementation

procedure printError(error: PAnsiChar);
begin
//  StrCat(error, '[parser]');
  ExitOnCodeError(GetCurrSourceLineIndex(), GetCurrSourceLine(),
    g_CurrLexerState.iCurrLexemeStart, error);
end;

function IsOpRelational(iOpType: Integer): Boolean;
begin
  Result := (iOpType in [OP_TYPE_EQUAL, OP_TYPE_NOT_EQUAL, OP_TYPE_LESS, OP_TYPE_GREATER,
    OP_TYPE_LESS_EQUAL, OP_TYPE_GREATER_EQUAL]);
end;

function IsOpLogical(iOpType: Integer): Boolean;
begin
  Result := (iOpType in [OP_TYPE_LOGICAL_NOT, OP_TYPE_LOGICAL_AND, OP_TYPE_LOGICAL_OR]);
end;

procedure ReadToken(const ReqToken: Token);
var
  pstrError: PAnsiChar;
begin
  if GetNextToken() <> ReqToken then
  begin
    GetMem(pstrError, 255);
    FillChar(pstrError^, 255, #0);
    try
      case ReqToken of
        TOKEN_TYPE_INT:
          StrCopy(pstrError, 'Integer');
        TOKEN_TYPE_FLOAT:
          StrCopy(pstrError, 'Float');
        TOKEN_TYPE_IDENT:
          StrCopy(pstrError, 'Identifier');
        TOKEN_TYPE_RSRVD_VAR:
          StrCopy(pstrError, 'var');
        TOKEN_TYPE_RSRVD_TRUE:
          StrCopy(pstrError, 'true');
        TOKEN_TYPE_RSRVD_FALSE:
          StrCopy(pstrError, 'false');
        TOKEN_TYPE_RSRVD_IF:
          StrCopy(pstrError, 'if');
        TOKEN_TYPE_RSRVD_ELSE:
          StrCopy(pstrError, 'else');
        TOKEN_TYPE_RSRVD_BREAK:
          StrCopy(pstrError, 'break');
        TOKEN_TYPE_RSRVD_CONTINUE:
          StrCopy(pstrError, 'continue');
        TOKEN_TYPE_RSRVD_FOR:
          StrCopy(pstrError, 'for');
        TOKEN_TYPE_RSRVD_WHILE:
          StrCopy(pstrError, 'while');
        TOKEN_TYPE_RSRVD_FUNC:
          StrCopy(pstrError, 'func');
        TOKEN_TYPE_RSRVD_RETURN:
          StrCopy(pstrError, 'return');
        TOKEN_TYPE_RSRVD_HOST:
          StrCopy(pstrError, 'host');
        TOKEN_TYPE_OP:
          StrCopy(pstrError, 'Operator');
        TOKEN_TYPE_DELIM_COMMA:
          StrCopy(pstrError, ',');
        TOKEN_TYPE_DELIM_OPEN_PAREN:
          StrCopy(pstrError, '(');
        TOKEN_TYPE_DELIM_CLOSE_PAREN:
          StrCopy(pstrError, ')');
        TOKEN_TYPE_DELIM_OPEN_BRACE:
          StrCopy(pstrError, '[');
        TOKEN_TYPE_DELIM_CLOSE_BRACE:
          StrCopy(pstrError, ']');
        TOKEN_TYPE_DELIM_OPEN_CURLY_BRACE:
          StrCopy(pstrError, '{');
        TOKEN_TYPE_DELIM_CLOSE_CURLY_BRACE:
          StrCopy(pstrError, '}');
        TOKEN_TYPE_DELIM_SEMICOLON:
          StrCopy(pstrError, ';');
        TOKEN_TYPE_STRING:
          StrCopy(pstrError, 'String');
      end;
      StrCat(pstrError, ' expected');
      // ��ӡ������Ϣ��������������
      printError(pstrError);
    finally
      // �ͷ�
      FreeMem(pstrError);
    end;
  end;
end;

procedure ParseSourceCode();
begin
  // ���ôʷ�������
  ResetLexer();
  InitStack(@g_LoopStack);
  // ����ǰ������������Ϊȫ��
  g_iCurrScope := SCOPE_GLOBAL;
  while True do
  begin
    // ������һ����䲢�����ļ��������
    ParseStatement();
    // ����Ѿ�������������ĩβ,������ѭ��
    if (GetNextToken() = TOKEN_TYPE_END_OF_STREAM) then
      Break
    else
      RewindTokenStream();
  end;
  // free the loop stack
  FreeStack(@g_LoopStack);
end;

procedure ParseStatement();
var
  InitToken: Token;
begin
  // �����һ�������Ƿֺţ���ô����һ�������
  if GetLookAHeadChar() = ';' then
  begin
    // ';'
    ReadToken(TOKEN_TYPE_DELIM_SEMICOLON);
    Exit;
  end;
  // ȷ�����Ŀ�ʼ����
  InitToken := GetNextToken();
  // �������Է���ֱ����ͬ�ķ�������
  case InitToken of
    // �ļ��������
    TOKEN_TYPE_END_OF_STREAM:
      printError('Unexpected end of file');
    // '{'
    TOKEN_TYPE_DELIM_OPEN_CURLY_BRACE:
      ParseBlock();
    // 'var'
    TOKEN_TYPE_RSRVD_VAR:
      ParseVar();
    // host
    TOKEN_TYPE_RSRVD_HOST:
      ParseHost();
    // 'func'
    TOKEN_TYPE_RSRVD_FUNC:
      ParseFunc();
    // if block
    TOKEN_TYPE_RSRVD_IF:
      ParseIf();
    TOKEN_TYPE_RSRVD_WHILE:
      ParseWhile();
    // For ѭ���ݲ�֧��
    // TOKEN_TYPE_RSRVD_FOR:
    // ParseFor();
    TOKEN_TYPE_RSRVD_BREAK:
      ParseBreak();
    TOKEN_TYPE_RSRVD_CONTINUE:
      ParseContinue();
    TOKEN_TYPE_RSRVD_RETURN:
      ParseReturn();
    // ������ ++���ݲ�֧��
    // TOKEN_TYPE_OP
    TOKEN_TYPE_IDENT:
      begin
        if GetSymbolByIdent(GetCurrLexeme(), g_iCurrScope) <> nil then
        begin
          ParseAssign();
        end
        else if GetFuncByName(GetCurrLexeme()) <> nil then
        begin
          AddICodeSourceLine(g_iCurrScope, GetCurrSourceLine());
          ParseFuncCall();
          ReadToken(TOKEN_TYPE_DELIM_SEMICOLON);
        end
        else
        begin
          printError('Invalid identifier');
          ExitOnCodeError(GetCurrSourceLineIndex(), GetCurrSourceLine(),
            g_CurrLexerState.iCurrLexemeStart, 'Invalid identifier');
        end;
      end
  else
    // ExitOnError('Unexpected input');
   printError('Unexpected input');
  end;
end;

procedure ParseBlock();
begin
  // ȷ������û����ȫ�ַ�Χ��
  if g_iCurrScope = SCOPE_GLOBAL then
    printError( 'Code blocks illegal in global scope');
  // ����ÿ�����ֱ�������
  while GetLookAHeadChar() <> '}' do
    ParseStatement();
  // ���� '}'
  ReadToken(TOKEN_TYPE_DELIM_CLOSE_CURLY_BRACE);
end;

procedure ParseVar();
var
  pstrIdent: PAnsiChar;
  iSize: Integer;
begin
  //
  ReadToken(TOKEN_TYPE_IDENT);
  // ��ǰ���ʸ��Ƶ�һ���ֲ��ַ������������Ա�������ı�ʶ��
  GetMem(pstrIdent, MAX_LEXEME_SIZE);
  try
    CopyCurrLexeme(pstrIdent);
    iSize := 1;
    // ��ǰ�鿴�Ƿ���������
    if GetLookAHeadChar() = '[' then
    begin
      // ��֤������
      ReadToken(TOKEN_TYPE_DELIM_OPEN_BRACE);
      // ����ǣ������������Է�
      ReadToken(TOKEN_TYPE_INT);
      // ����ǰ����ת��Ϊ�����Ի�ô�С
      iSize := StrToInt(GetCurrLexeme());
      ReadToken(TOKEN_TYPE_DELIM_CLOSE_BRACE);
    end;
    if AddSymbol(pstrIdent, iSize, g_iCurrScope, SYMBOL_TYPE_VAR) = -1 then
      printError( 'IdentiFier redefinition');

    ReadToken(TOKEN_TYPE_DELIM_SEMICOLON);
  finally
    FreeMem(pstrIdent);
  end;
end;

procedure ParseHost();
begin
  // ������Ӧ�ó��� API ��������
  ReadToken(TOKEN_TYPE_IDENT);
  // ��������ӵ��������в�������Ӧ�ó���API���
  if AddFunc(GetCurrLexeme(), 1) = -1 then
    printError( 'Function redefinition');
  // ȷ���������ֺ������()
  ReadToken(TOKEN_TYPE_DELIM_OPEN_PAREN);
  ReadToken(TOKEN_TYPE_DELIM_CLOSE_PAREN);

  // ����ֺ�
  ReadToken(TOKEN_TYPE_DELIM_SEMICOLON);
end;

procedure ParseFunc();
var
  iFuncIndex: Integer;
  iParamCount: Integer;
  // ���鱣��ֲ������б�
  ppstrParamList: array [0 .. MAX_FUNC_DECLARE_PARAM_COUNT - 1] of AnsiString;
  clex: PAnsiChar;
begin
  // ����������Ƕ��,�������������ȫ��
  if g_iCurrScope <> SCOPE_GLOBAL then
    printError('Nested function illegal');
  // ���뺯������
  ReadToken(TOKEN_TYPE_IDENT);
  // ������Ӧ�ó���API�������뵽�����������������
  iFuncIndex := AddFunc(GetCurrLexeme(), 0); // 0 not host api
  // ��麯�����ظ�����
  if iFuncIndex = -1 then
    printError('Function redefinition');
  // �趨������������
  g_iCurrScope := iFuncIndex;
  // ----���������б� '('
  ReadToken(TOKEN_TYPE_DELIM_OPEN_PAREN);
  // ʹ����ǰ�鿴�ַ�ȷ�������Ƿ��в���
  if GetLookAHeadChar() <> ')' then
  begin
    // ��������������_Main(),�Ǿ͸���������,��Ϊ_Main()�������κβ���
    if (g_ScriptHeader.iIsMainFuncPresent <> 0) and (g_ScriptHeader.iMainFuncIndex = iFuncIndex)
    then
    begin
      printError('_Main() cannot accept parameters');
    end;
    // ����������0��ʼ
    iParamCount := 0;
    // ����һ�����鱣��ֲ������б�
    // ������
    while True do
    begin
      ReadToken(TOKEN_TYPE_IDENT);
      // ��ǰ�ĵ��ʸ��Ƶ���������
      GetMem(clex, 32);
      CopyCurrLexeme(clex);
      ppstrParamList[iParamCount] := AnsiString(clex);
      FreeMem(clex);
      // CopyCurrLexeme(@ppstrParamList[iParamCount]);
      //
      Inc(iParamCount);
      // �����������ȷ�������б��Ƿ����
      if GetLookAHeadChar = ')' then
        Break;
      // ���������һ�����Ž��Ŵ�����һ������
      ReadToken(TOKEN_TYPE_DELIM_COMMA);
    end;
    // ���ò�������
    SetFuncParamCount(g_iCurrScope, iParamCount);
    // ������������д�뵽�����ķ��ű�
    while iParamCount > 0 do
    begin
      Dec(iParamCount);
      AddSymbol(PAnsiChar(ppstrParamList[iParamCount]), 1, g_iCurrScope, SYMBOL_TYPE_PARAM);
    end;
  end;
  // ����������

  ReadToken(TOKEN_TYPE_DELIM_CLOSE_PAREN);
  // ----����������
  // ���� '{'
  ReadToken(TOKEN_TYPE_DELIM_OPEN_CURLY_BRACE);
  // ����������
  ParseBlock();
  // ���ص�ȫ�ַ�Χ
  g_iCurrScope := SCOPE_GLOBAL;
end;

// <Ident> (<Expr>,<Expr>);
procedure ParseFuncCall();
var
  pFunc: pFuncNode;
  iParamCount: Integer;
  iCallInstr: Integer;
  iInstrIndex: Integer;
begin
  iParamCount := 0;
  // ���ݱ�ʶ����ú���
  pFunc := GetFuncByName(GetCurrLexeme());
  // ��ͼ����������
  ReadToken(TOKEN_TYPE_DELIM_OPEN_PAREN);
  // ����ÿ��������������ѹ�뵽��ջ
  while True do
  begin
    // �鿴�Ƿ��в���
    if GetLookAHeadChar() <> ')' then
    begin
      // ���в���,���Ե���һ�����ʽ������
      ParseExpr();
      // ���Ӳ�������������������û�г����������Խ��ܵĲ�������(��������Ӧ�ó���API����)
      Inc(iParamCount);
      if (pFunc.iIsHostAPI = 0) and (iParamCount > pFunc.iParamCount) then
      begin
        printError('Too many parametes');
      end;
      // ����������һ������,���붺��
      if GetLookAHeadChar() <> ')' then
        ReadToken(TOKEN_TYPE_DELIM_COMMA);
    end
    else
    begin
      // û�ж���,�˳�ѭ����ɷ���
      Break;
    end;
  end;
  // ���������
  ReadToken(TOKEN_TYPE_DELIM_CLOSE_PAREN);
  // ����������̫��(��������Ӧ�ó���API����)
  if (pFunc.iIsHostAPI = 0) and (iParamCount < pFunc.iParamCount) then
  begin
    printError('Too few parameters');
  end;
  // ���ú���,ȷ��ʹ����ȷ�ĺ�������ָ��
  iCallInstr := INSTR_CALL;
  if pFunc.iIsHostAPI = 1 then
  begin
    iCallInstr := INSTR_CALLHOST;
  end;
  iInstrIndex := AddICodeInstr(g_iCurrScope, iCallInstr);
  AddFuncICodeOp(g_iCurrScope, iInstrIndex, pFunc.iIndex);
end;

// <Ident> <Assign-Op> <Expr>
procedure ParseAssign();
var
  iInstrIndex: Integer;
  // ��ֵ�����
  iAssignOp: Integer;
  pSymbol: pSymbolNode;
  bIsArray: Boolean;
begin
  if g_iCurrScope = SCOPE_GLOBAL then
  begin
    printError('Assignment illegal in global scope');
  end;
  { TODO :  }
  AddICodeSourceLine(g_iCurrScope, GetCurrSourceLine());
  // ����������������
  pSymbol := GetSymbolByIdent(GetCurrLexeme(), g_iCurrScope);
  // ��ʶ�������Ƿ�������
  bIsArray := False;
  if GetLookAHeadChar() = '[' then
  begin
    // ȷ���������������
    if pSymbol.iSize = 1 then
      printError('Invalid array');
    // ���������
    ReadToken(TOKEN_TYPE_DELIM_OPEN_BRACE);
    // ȷ���������б��ʽ
    if GetLookAHeadChar() = ']' then
      printError('Invalid expression');
    // �������ʽ�Եõ�����
    ParseExpr();
    // ȷ�����ʽ����������
    ReadToken(TOKEN_TYPE_DELIM_CLOSE_BRACE);
    // ����������
    bIsArray := True;
  end
  else
  begin
    // ȷ�����������������
    if pSymbol.iSize > 1 then
      printError('Arrays must be indexed');
  end;

  if (GetNextToken() <> TOKEN_TYPE_OP) and //
    (not(GetCurrOp in [OP_TYPE_ASSIGN, OP_TYPE_ASSIGN_ADD, OP_TYPE_ASSIGN_SUB, OP_TYPE_ASSIGN_MUL,
    OP_TYPE_ASSIGN_DIV, OP_TYPE_ASSIGN_MOD, OP_TYPE_ASSIGN_EXP, OP_TYPE_ASSIGN_CONCAT,
    OP_TYPE_ASSIGN_AND, OP_TYPE_ASSIGN_OR, OP_TYPE_ASSIGN_XOR, OP_TYPE_ASSIGN_SHIFT_LEFT,
    OP_TYPE_ASSIGN_SHIFT_RIGHT])) then
  begin
    printError('Illegal assignment operator');
  end
  else
  begin
    iAssignOp := GetCurrOp();
  end;
  // ����ֵ���ʽ
  ParseExpr();
  // ��֤�ֺ��Ƿ����
  ReadToken(TOKEN_TYPE_DELIM_SEMICOLON);
  // ��ֵ������_T0
  iInstrIndex := AddICodeInstr(g_iCurrScope, INSTR_POP);
  AddVarICodeOp(g_iCurrScope, iInstrIndex, g_iTempVar0SymbolIndex);
  // ����������ʱ���飬����ջ������Ԫ�ص�����_T1
  if bIsArray then
  begin
    iInstrIndex := AddICodeInstr(g_iCurrScope, INSTR_POP);
    AddVarICodeOp(g_iCurrScope, iInstrIndex, g_iTempVar1SymbolIndex);
  end;
  // Ϊ�м�������ɸ�ֵָ��
  case iAssignOp of
    // =
    OP_TYPE_ASSIGN:
      iInstrIndex := AddICodeInstr(g_iCurrScope, INSTR_MOV);
    // +=
    OP_TYPE_ASSIGN_ADD:
      iInstrIndex := AddICodeInstr(g_iCurrScope, INSTR_ADD);
    // -=
    OP_TYPE_ASSIGN_SUB:
      iInstrIndex := AddICodeInstr(g_iCurrScope, INSTR_SUB);
    // *=
    OP_TYPE_ASSIGN_MUL:
      iInstrIndex := AddICodeInstr(g_iCurrScope, INSTR_MUL);
    // /=
    OP_TYPE_ASSIGN_DIV:
      iInstrIndex := AddICodeInstr(g_iCurrScope, INSTR_DIV);
    // %=
    OP_TYPE_ASSIGN_MOD:
      iInstrIndex := AddICodeInstr(g_iCurrScope, INSTR_MOD);
    // ^=
    OP_TYPE_ASSIGN_EXP:
      iInstrIndex := AddICodeInstr(g_iCurrScope, INSTR_EXP);
    // $=
    OP_TYPE_ASSIGN_CONCAT:
      iInstrIndex := AddICodeInstr(g_iCurrScope, INSTR_CONCAT);
    // &=
    OP_TYPE_ASSIGN_AND:
      iInstrIndex := AddICodeInstr(g_iCurrScope, INSTR_AND);
    // |=
    OP_TYPE_ASSIGN_OR:
      iInstrIndex := AddICodeInstr(g_iCurrScope, INSTR_OR);
    // #=
    OP_TYPE_ASSIGN_XOR:
      iInstrIndex := AddICodeInstr(g_iCurrScope, INSTR_XOR);
    // <<=
    OP_TYPE_ASSIGN_SHIFT_LEFT:
      iInstrIndex := AddICodeInstr(g_iCurrScope, INSTR_SHL);
    // >>=
    OP_TYPE_ASSIGN_SHIFT_RIGHT:
      iInstrIndex := AddICodeInstr(g_iCurrScope, INSTR_SHR);
  end;
  // ����Ŀ�������
  if bIsArray then
  begin
    AddArrayIndexVarICodeOp(g_iCurrScope, iInstrIndex, pSymbol.iIndex, g_iTempVar1SymbolIndex);
  end
  else
  begin
    AddVarICodeOp(g_iCurrScope, iInstrIndex, pSymbol.iIndex);
  end;
  // ����Դ������
  AddVarICodeOp(g_iCurrScope, iInstrIndex, g_iTempVar0SymbolIndex);
end;

procedure ParseFactor();
var
  iInstrIndex: Integer;
  bUnaryOpPending: Boolean;
  iOpType: Integer;
  itmp: Integer;
  iStringIndex: Integer;
  //
  pSymbol: pSymbolNode;
  //
  iTrueJumpTargetIndex: Integer;
  iExitJumpTargetIndex: Integer;
  //
  iOpIndex: Integer;
begin
  bUnaryOpPending := False;
  // ���ȼ�鵥Ŀ�����
  if ((GetNextToken() = TOKEN_TYPE_OP) and //
    (GetCurrOp in [OP_TYPE_ADD, OP_TYPE_SUB, OP_TYPE_BITWISE_NOT, OP_TYPE_LOGICAL_NOT])) then
  begin
    // ����ҵ��ͱ��沢���õ�Ŀ������
    bUnaryOpPending := True;
    iOpType := GetCurrOp();
  end
  else
  begin
    // ����ؾ����Է���
    RewindTokenStream();
  end;
  // ������һ�����Է�ȷ���������ڴ������������
  case GetNextToken() of
    // ��True��False���������԰�0,1 ѹ���ջ
    TOKEN_TYPE_RSRVD_TRUE, TOKEN_TYPE_RSRVD_FALSE:
      begin
        iInstrIndex := AddICodeInstr(g_iCurrScope, INSTR_PUSH);
        if GetCurrToken() = TOKEN_TYPE_RSRVD_TRUE then
          itmp := 1
        else
          itmp := 0;

        AddIntICodeOp(g_iCurrScope, iInstrIndex, itmp);
      end;
    TOKEN_TYPE_INT:
      begin
        iInstrIndex := AddICodeInstr(g_iCurrScope, INSTR_PUSH);
        AddIntICodeOp(g_iCurrScope, iInstrIndex, StrToInt(GetCurrLexeme()));
      end;
    TOKEN_TYPE_FLOAT:
      begin
        iInstrIndex := AddICodeInstr(g_iCurrScope, INSTR_PUSH);
        AddFloatICodeOp(g_iCurrScope, iInstrIndex, StrToFloat(GetCurrLexeme()));
      end;
    // ��һ���ַ��������������Խ�����뵽�ַ�������в�������ѹ���ջ��
    TOKEN_TYPE_STRING:
      begin
        iStringIndex := AddString(@g_stringTable, GetCurrLexeme());
        iInstrIndex := AddICodeInstr(g_iCurrScope, INSTR_PUSH);
        AddStringICodeOp(g_iCurrScope, iInstrIndex, iStringIndex);
      end;
    // ��ʶ���Ļ�
    TOKEN_TYPE_IDENT:
      begin
        // ���ȼ���ʶ���Ǳ�����������
        pSymbol := GetSymbolByIdent(GetCurrLexeme(), g_iCurrScope);
        if pSymbol <> nil then
        begin
          // ��ʶ�������Ƿ�������
          if GetLookAHeadChar() = '[' then
          begin
            // ȷ���������ʱһ������
            if pSymbol.iSize = 1 then
            begin
              printError('Invalid array');
            end;
            // ���������
            ReadToken(TOKEN_TYPE_DELIM_OPEN_BRACE);
            // ȷ�����ʽ�Ĵ���
            if (GetLookAHeadChar() = ']') then
            begin
              printError('Invalid expression');
            end;
            // �ݹ�����������ʽ
            ParseExpr();
            // ȷ�����Ŵ���
            ReadToken(TOKEN_TYPE_DELIM_CLOSE_BRACE);
            // �����������_T0
            iInstrIndex := AddICodeInstr(g_iCurrScope, INSTR_POP);
            AddVarICodeOp(g_iCurrScope, iInstrIndex, g_iTempVar0SymbolIndex);
            // ��ԭ���ı�ʶ��ѹ���ջ�У�����_T0��Ϊ����
            iInstrIndex := AddICodeInstr(g_iCurrScope, INSTR_PUSH);
            AddArrayIndexVarICodeOp(g_iCurrScope, iInstrIndex, pSymbol.iIndex,
              g_iTempVar0SymbolIndex);
          end
          else
          begin
            // ������ǣ�ȷ�������ʶ������һ�����飬������ѹ�뵽��ջ��
            if pSymbol.iSize = 1 then
            begin
              iInstrIndex := AddICodeInstr(g_iCurrScope, INSTR_PUSH);
              AddVarICodeOp(g_iCurrScope, iInstrIndex, pSymbol.iIndex);
            end
            else
            begin
              printError('Arrays must be indexed');
            end;
          end;
        end
        else
        begin
          if (GetFuncByName(GetCurrLexeme()) <> nil) then
          begin
            // �Ǻ����������������
            ParseFuncCall();
            // ѹ�뷵��ֵ
            iInstrIndex := AddICodeInstr(g_iCurrScope, INSTR_PUSH);
            AddRegICodeOp(g_iCurrScope, iInstrIndex, REG_CODE_RETVAL);
          end;
        end;
      end;
    // ��һ��Ƕ�׵ı��ʽ�����Եݹ����ParseExpr() �����������
    TOKEN_TYPE_DELIM_OPEN_PAREN:
      begin
        ParseExpr();
        ReadToken(TOKEN_TYPE_DELIM_CLOSE_PAREN);
      end;
  else
    printError('Invalid input');
  end;
  // �Ƿ���û�д���ĵ�Ŀ�����
  if (bUnaryOpPending) then
  begin
    // �еĻ��Ӷ�ջ�е�������
    iInstrIndex := AddICodeInstr(g_iCurrScope, INSTR_POP);
    AddVarICodeOp(g_iCurrScope, iInstrIndex, g_iTempVar0SymbolIndex);
    // ִ�е�Ŀ�����
    if iOpType = OP_TYPE_LOGICAL_NOT then
    begin
      iTrueJumpTargetIndex := GetNextJumpTargetIndex();
      iExitJumpTargetIndex := GetNextJumpTargetIndex();

      // je _T0,0,true
      iInstrIndex := AddICodeInstr(g_iCurrScope, INSTR_JE);
      AddVarICodeOp(g_iCurrScope, iInstrIndex, g_iTempVar0SymbolIndex);
      AddIntICodeOp(g_iCurrScope, iInstrIndex, 0);
      AddJumpTargetICodeOp(g_iCurrScope, iInstrIndex, iTrueJumpTargetIndex);

      // push 0
      iInstrIndex := AddICodeInstr(g_iCurrScope, INSTR_PUSH);
      AddIntICodeOp(g_iCurrScope, iInstrIndex, 0);

      // jmp L1
      iInstrIndex := AddICodeInstr(g_iCurrScope, INSTR_JMP);
      AddJumpTargetICodeOp(g_iCurrScope, iInstrIndex, iExitJumpTargetIndex);

      // L0: (True)
      AddICodeInstr(g_iCurrScope, iTrueJumpTargetIndex);

      // push 1
      iInstrIndex := AddICodeInstr(g_iCurrScope, INSTR_PUSH);
      AddIntICodeOp(g_iCurrScope, iInstrIndex, 1);

      // L1: (Exit)
      AddICodeJumpTarget(g_iCurrScope, iExitJumpTargetIndex);
    end
    else
    begin
      case iOpType of
        OP_TYPE_SUB:
          iOpIndex := INSTR_NEG;
        OP_TYPE_BITWISE_NOT:
          iOpIndex := INSTR_NOT;
      end;

      // add the instruction's operand
      iInstrIndex := AddICodeInstr(g_iCurrScope, iOpIndex);
      AddVarICodeOp(g_iCurrScope, iInstrIndex, g_iTempVar0SymbolIndex);
      // push the result onto the stack
      iInstrIndex := AddICodeInstr(g_iCurrScope, INSTR_PUSH);
      AddVarICodeOp(g_iCurrScope, iInstrIndex, g_iTempVar0SymbolIndex);
    end;
  end;
end;

procedure ParseTerm();
var
  iInstrIndex: Integer;
  iOpType: Integer;
  iOpInstr: Integer;
begin
  // ������һ������
  ParseFactor();
  // ���� ������* , /,%,^,&,|,#,>> and >> �����
  while True do
  begin
    // �����һ�����Է�
    if ( //
      (GetNextToken() <> TOKEN_TYPE_OP) or //
      (not(GetCurrOp in [OP_TYPE_MUL, OP_TYPE_DIV, OP_TYPE_MOD, OP_TYPE_EXP, OP_TYPE_BITWISE_AND,
      OP_TYPE_BITWISE_OR, OP_TYPE_BITWISE_XOR, OP_TYPE_BITWISE_SHIFT_LEFT,
      OP_TYPE_BITWISE_SHIFT_RIGHT]))) then
    begin
      RewindTokenStream();
      Break;
    end;
    // ���������
    iOpType := GetCurrOp();
    // �����ڶ�������
    ParseFactor();
    // ����һ��������������_T1
    iInstrIndex := AddICodeInstr(g_iCurrScope, INSTR_POP);
    AddVarICodeOp(g_iCurrScope, iInstrIndex, g_iTempVar1SymbolIndex);
    // ���ڶ���������������_T0
    iInstrIndex := AddICodeInstr(g_iCurrScope, INSTR_POP);
    AddVarICodeOp(g_iCurrScope, iInstrIndex, g_iTempVar0SymbolIndex);
    // ������������������Ӧ�Ĳ���
    case iOpType of
      OP_TYPE_MUL:
        iOpInstr := INSTR_MUL;
      OP_TYPE_DIV:
        iOpInstr := INSTR_DIV;
      OP_TYPE_MOD:
        iOpInstr := INSTR_MOD;
      OP_TYPE_EXP:
        iOpInstr := INSTR_EXP;
      OP_TYPE_BITWISE_AND:
        iOpInstr := INSTR_AND;
      OP_TYPE_BITWISE_OR:
        iOpInstr := INSTR_OR;
      OP_TYPE_BITWISE_XOR:
        iOpInstr := INSTR_XOR;
      OP_TYPE_BITWISE_SHIFT_LEFT:
        iOpInstr := INSTR_SHL;
      OP_TYPE_BITWISE_SHIFT_RIGHT:
        iOpInstr := INSTR_SHR;
    end;

    iInstrIndex := AddICodeInstr(g_iCurrScope, iOpInstr);
    AddVarICodeOp(g_iCurrScope, iInstrIndex, g_iTempVar0SymbolIndex);
    AddVarICodeOp(g_iCurrScope, iInstrIndex, g_iTempVar1SymbolIndex);
    // �����ջ(���浽_T0)
    iInstrIndex := AddICodeInstr(g_iCurrScope, INSTR_PUSH);
    AddVarICodeOp(g_iCurrScope, iInstrIndex, g_iTempVar0SymbolIndex);
  end;
end;

procedure ParseExpr();
var
  iInstrIndex: Integer;
  iOpType: Integer;
  //
  iTrueJumpTargetIndex: Integer;
  iFalseJumpTargetIndex: Integer;
  iExitJumpTargetIndex: Integer;
begin
  ParseSubExpr();

  while True do
  begin
    if ((GetNextToken() <> TOKEN_TYPE_OP) or ((not IsOpRelational(GetCurrOp())) and
      (not IsOpLogical(GetCurrOp())))) then
    begin
      RewindTokenStream();
      Break;
    end;
    // save the operator
    iOpType := GetCurrOp();
    // parse the second term
    ParseSubExpr();
    // pop the first operand into _T1
    iInstrIndex := AddICodeInstr(g_iCurrScope, INSTR_POP);
    AddVarICodeOp(g_iCurrScope, iInstrIndex, g_iTempVar1SymbolIndex);
    // pop the second operand into _T0
    iInstrIndex := AddICodeInstr(g_iCurrScope, INSTR_POP);
    AddVarICodeOp(g_iCurrScope, iInstrIndex, g_iTempVar0SymbolIndex);
    // perform the binary operation associated with the specified operator
    // determine the operator type
    if IsOpRelational(iOpType) then
    begin
      // get a pair of free jump target indices
      iTrueJumpTargetIndex := GetNextJumpTargetIndex();
      iExitJumpTargetIndex := GetNextJumpTargetIndex();
      // it's a relational operator
      case iOpType of
        // equal
        OP_TYPE_EQUAL:
          iInstrIndex := AddICodeInstr(g_iCurrScope, INSTR_JE);
        // not equal
        OP_TYPE_NOT_EQUAL:
          iInstrIndex := AddICodeInstr(g_iCurrScope, INSTR_JNE);
        // greater
        OP_TYPE_GREATER:
          iInstrIndex := AddICodeInstr(g_iCurrScope, INSTR_JG);
        // less
        OP_TYPE_LESS:
          iInstrIndex := AddICodeInstr(g_iCurrScope, INSTR_JL);
        // Greater or equal
        OP_TYPE_GREATER_EQUAL:
          // generate a JGE instruction
          iInstrIndex := AddICodeInstr(g_iCurrScope, INSTR_JGE);
        // ;less then or equal
        OP_TYPE_LESS_EQUAL:
          iInstrIndex := AddICodeInstr(g_iCurrScope, INSTR_JLE);
      end;
      // add the jump instruction's operands (_T0 and _T1)
      AddVarICodeOp(g_iCurrScope, iInstrIndex, g_iTempVar0SymbolIndex);
      AddVarICodeOp(g_iCurrScope, iInstrIndex, g_iTempVar1SymbolIndex);
      AddJumpTargetICodeOp(g_iCurrScope, iInstrIndex, iTrueJumpTargetIndex);
      // generate the outcome for falsehood
      iInstrIndex := AddICodeInstr(g_iCurrScope, INSTR_PUSH);
      AddIntICodeOp(g_iCurrScope, iInstrIndex, 0);
      // generate a jump past the true outcome
      iInstrIndex := AddICodeInstr(g_iCurrScope, INSTR_JMP);
      AddJumpTargetICodeOp(g_iCurrScope, iInstrIndex, iExitJumpTargetIndex);
      // set the jump target for the true outcome
      AddICodeJumpTarget(g_iCurrScope, iTrueJumpTargetIndex);
      // generate the outcome for truth
      iInstrIndex := AddICodeInstr(g_iCurrScope, INSTR_PUSH);
      AddIntICodeOp(g_iCurrScope, iInstrIndex, 1);
      // set the jump target for exiting the operand evaluation
      AddICodeJumpTarget(g_iCurrScope, iExitJumpTargetIndex);
    end
    else
    begin
      // it must be a logical operator
      case iOpType of
        // and
        OP_TYPE_LOGICAL_AND:
          begin
            iFalseJumpTargetIndex := GetNextJumpTargetIndex();
            iExitJumpTargetIndex := GetNextJumpTargetIndex();

            // JE _T0,0,True
            iInstrIndex := AddICodeInstr(g_iCurrScope, INSTR_JE);
            AddVarICodeOp(g_iCurrScope, iInstrIndex, g_iTempVar0SymbolIndex);
            AddIntICodeOp(g_iCurrScope, iInstrIndex, 0);
            AddJumpTargetICodeOp(g_iCurrScope, iInstrIndex, iFalseJumpTargetIndex);
            // JE _T1,0,True
            iInstrIndex := AddICodeInstr(g_iCurrScope, INSTR_JE);
            AddVarICodeOp(g_iCurrScope, iInstrIndex, g_iTempVar1SymbolIndex);
            AddIntICodeOp(g_iCurrScope, iInstrIndex, iFalseJumpTargetIndex);
            // Push 1
            iInstrIndex := AddICodeInstr(g_iCurrScope, INSTR_PUSH);
            AddIntICodeOp(g_iCurrScope, iInstrIndex, 1);
            // Jmp Exit
            iInstrIndex := AddICodeInstr(g_iCurrScope, INSTR_JMP);
            AddJumpTargetICodeOp(g_iCurrScope, iInstrIndex, iExitJumpTargetIndex);
            // L0:(False)
            AddICodeInstr(g_iCurrScope, iFalseJumpTargetIndex);
            // Push 0
            iInstrIndex := AddICodeInstr(g_iCurrScope, INSTR_PUSH);
            AddIntICodeOp(g_iCurrScope, iInstrIndex, 0);
            // L1:(Exit)
            AddICodeJumpTarget(g_iCurrScope, iExitJumpTargetIndex);
          end;
        // or
        OP_TYPE_LOGICAL_OR:
          begin
            // get a pair of free jump target indices
            iTrueJumpTargetIndex := GetNextJumpTargetIndex();
            iExitJumpTargetIndex := GetNextJumpTargetIndex();
            // JNE _T0,0,True
            iInstrIndex := AddICodeInstr(g_iCurrScope, INSTR_JNE);
            AddVarICodeOp(g_iCurrScope, iInstrIndex, g_iTempVar0SymbolIndex);
            AddIntICodeOp(g_iCurrScope, iInstrIndex, 0);
            AddJumpTargetICodeOp(g_iCurrScope, iInstrIndex, iTrueJumpTargetIndex);
            // JNE _T1,0,True
            iInstrIndex := AddICodeInstr(g_iCurrScope, INSTR_JNE);
            AddVarICodeOp(g_iCurrScope, iInstrIndex, g_iTempVar1SymbolIndex);
            AddIntICodeOp(g_iCurrScope, iInstrIndex, 0);
            AddJumpTargetICodeOp(g_iCurrScope, iInstrIndex, iTrueJumpTargetIndex);
            // Push 0
            iInstrIndex := AddICodeInstr(g_iCurrScope, INSTR_PUSH);
            AddIntICodeOp(g_iCurrScope, iInstrIndex, 0);
            // Jmp Exit
            iInstrIndex := AddICodeInstr(g_iCurrScope, INSTR_JMP);
            AddJumpTargetICodeOp(g_iCurrScope, iInstrIndex, iExitJumpTargetIndex);
            // L0:(True)
            AddICodeJumpTarget(g_iCurrScope, iTrueJumpTargetIndex);
            // Push 1
            iInstrIndex := AddICodeInstr(g_iCurrScope, INSTR_PUSH);
            AddIntICodeOp(g_iCurrScope, iInstrIndex, 1);
            // L1:(Exit)
            AddICodeJumpTarget(g_iCurrScope, iExitJumpTargetIndex);
          end;
      end;
    end
  end;
end;

procedure ParseSubExpr();
var
  iInstrIndex: Integer;
  iOpType: Integer;
  iOpInstr: Integer;
begin
  // ������һ��
  ParseTerm();
  // ���������� + ���� - �����
  while True do
  begin
    // �����һ�����Է�
    if ((GetNextToken() <> TOKEN_TYPE_OP) or //
      (not(GetCurrOp() in [OP_TYPE_ADD, OP_TYPE_SUB, OP_TYPE_CONCAT]))) then
    begin
      RewindTokenStream();
      Break;
    end;
    iOpType := GetCurrOp();
    // �����ڶ���
    ParseTerm();
    // ����һ��������������_T1
    iInstrIndex := AddICodeInstr(g_iCurrScope, INSTR_POP);
    AddVarICodeOp(g_iCurrScope, iInstrIndex, g_iTempVar1SymbolIndex);
    // ���ڶ���������������_T0
    iInstrIndex := AddICodeInstr(g_iCurrScope, INSTR_POP);
    AddVarICodeOp(g_iCurrScope, iInstrIndex, g_iTempVar0SymbolIndex);
    // �����ض��������������Ӧ�Ĳ���  + - $
    case iOpType of
      // add
      OP_TYPE_ADD:
        iOpInstr := INSTR_ADD;
      OP_TYPE_SUB:
        iOpInstr := INSTR_SUB;
      OP_TYPE_CONCAT:
        iOpInstr := INSTR_CONCAT;
    end;
    iInstrIndex := AddICodeInstr(g_iCurrScope, iOpInstr);
    AddVarICodeOp(g_iCurrScope, iInstrIndex, g_iTempVar0SymbolIndex);
    AddVarICodeOp(g_iCurrScope, iInstrIndex, g_iTempVar1SymbolIndex);
    // �����ջ(������_T0��)
    iInstrIndex := AddICodeInstr(g_iCurrScope, INSTR_PUSH);
    AddVarICodeOp(g_iCurrScope, iInstrIndex, g_iTempVar0SymbolIndex);
  end;
end;

// �����߼��﷨
procedure ParseIf();
var
  iInstrIndex: Integer;
  iFalseJumpTargetIndex: Integer;
  iSkipFalseJumpTargetIndex: Integer;
begin
  if g_iCurrScope = SCOPE_GLOBAL then
    ExitOnError('if illegal in global scope');

  // ��ע������
  AddICodeSourceLine(g_iCurrScope, GetCurrSourceLine());

  // ����һ����תĿ��
  iFalseJumpTargetIndex := GetNextJumpTargetIndex();

  // ����������
  ReadToken(TOKEN_TYPE_DELIM_OPEN_PAREN);

  // �������ʽ����ֵ�ŵ���ջ��
  ParseExpr();

  // ����������
  ReadToken(TOKEN_TYPE_DELIM_CLOSE_PAREN);

  // �����������_T0,���� 0 ���бȽ�
  iInstrIndex := AddICodeInstr(g_iCurrScope, INSTR_POP);
  AddVarICodeOp(g_iCurrScope, iInstrIndex, g_iTempVar0SymbolIndex);

  // �������� 0����ת��falseĿ��
  iInstrIndex := AddICodeInstr(g_iCurrScope, INSTR_JE);
  AddVarICodeOp(g_iCurrScope, iInstrIndex, g_iTempVar0SymbolIndex);
  AddIntICodeOp(g_iCurrScope, iInstrIndex, 0);
  AddJumpTargetICodeOp(g_iCurrScope, iInstrIndex, iFalseJumpTargetIndex);

  // ����true����
  ParseStatement();

  // ����else���
  if GetNextToken() = TOKEN_TYPE_RSRVD_ELSE then
  begin
    // ����ҵ�����true�����������������ת������false����
    iSkipFalseJumpTargetIndex := GetNextJumpTargetIndex();
    iInstrIndex := AddICodeInstr(g_iCurrScope, INSTR_JMP);
    AddJumpTargetICodeOp(g_iCurrScope, iInstrIndex, iSkipFalseJumpTargetIndex);

    // ��falseĿ�����false�����ǰ��
    AddICodeJumpTarget(g_iCurrScope, iFalseJumpTargetIndex);

    // ����false����
    ParseStatement();

    // ����false����������תĿ��
    AddICodeJumpTarget(g_iCurrScope, iSkipFalseJumpTargetIndex);
  end
  else
  begin
    // ����ؾ�������
    RewindTokenStream();

    // ��falseĿ�����true�����ĺ���
    AddICodeJumpTarget(g_iCurrScope, iFalseJumpTargetIndex);
  end;
end;

// while ( <Expression> ) <Statement>
procedure ParseWhile();
var
  iInstrIndex: Integer;
  iStartTargetIndex: Integer;
  iEndTargetIndex: Integer;
  apLoop: pLoop;
begin
  // ȷ��������һ��������
  if g_iCurrScope = SCOPE_GLOBAL then
    printError('statement illegal in global scope');

  // ��ע������
  AddICodeSourceLine(g_iCurrScope, GetCurrSourceLine());

  // ���������תĿ�ꡣ�ֱ��Ӧ��ѭ�������͵ײ�����
  iStartTargetIndex := GetNextJumpTargetIndex();
  iEndTargetIndex := GetNextJumpTargetIndex();

  // ��ѭ�����������һ����תĿ��
  AddICodeJumpTarget(g_iCurrScope, iStartTargetIndex);

  // ���������� '('
  ReadToken(TOKEN_TYPE_DELIM_OPEN_PAREN);

  // �������ʽ�������ѹ�뵽��ջ
  ParseExpr();

  // ���������� ')'
  ReadToken(TOKEN_TYPE_DELIM_CLOSE_PAREN);

  // �����������_T0,����� 0 �Ļ�������ѭѭ��
  iInstrIndex := AddICodeInstr(g_iCurrScope, INSTR_POP);
  AddVarICodeOp(g_iCurrScope, iInstrIndex, g_iTempVar0SymbolIndex);

  iInstrIndex := AddICodeInstr(g_iCurrScope, INSTR_JE);
  AddVarICodeOp(g_iCurrScope, iInstrIndex, g_iTempVar0SymbolIndex);
  AddIntICodeOp(g_iCurrScope, iInstrIndex, 0);
  AddJumpTargetICodeOp(g_iCurrScope, iInstrIndex, iEndTargetIndex);

  // ����һ���µ�ѭ��ʵ���ṹ
  GetMem(apLoop, SizeOf(Loop));

  // ���ÿ�ʼ�ͽ�����ת��Ŀ������
  apLoop.iStartTargetIndex := iStartTargetIndex;
  apLoop.iEndTargetIndex := iEndTargetIndex;

  // ��ѭ���ṹѹ�뵽��ջ��
  Push(@g_LoopStack, apLoop);

  // ����ѭ����
  ParseStatement();

  // ����ѭ����
  PopUp(@g_LoopStack);

  // ��������ת�ص�ѭ����ʼ�ĵط�
  iInstrIndex := AddICodeInstr(g_iCurrScope, INSTR_JMP);
  AddJumpTargetICodeOp(g_iCurrScope, iInstrIndex, iStartTargetIndex);

  // ����ѭ��������תĿ��
  AddICodeJumpTarget(g_iCurrScope, iEndTargetIndex);
end;

// for ( <Initializer>; <Condition>; <Perpetuator> )
// <Statement>
procedure ParseFor();
var
  iInstrIndex: Integer;
  iStartTargetIndex: Integer;
  iEndTargetIndex: Integer;
  apLoop: pLoop;
  InitToken: Token;
begin
  // like the loop of while
  if g_iCurrScope = SCOPE_GLOBAL then
    ExitOnError('for illegal in global scope');

  // annotate the line
  AddICodeSourceLine(g_iCurrScope, GetCurrSourceLine());

  // A for loop parser implementation could go here
  // ���������תĿ�꣬�ֱ��Ӧ��ѭ�������͵ײ�
  iStartTargetIndex := GetNextJumpTargetIndex();
  iEndTargetIndex := GetNextJumpTargetIndex();
  // ��ѭ�����������һ����תĿ��
  AddICodeJumpTarget(g_iCurrScope, iStartTargetIndex);
  // ���������� '('
  ReadToken(TOKEN_TYPE_DELIM_OPEN_PAREN);
  // ������һ����ֵ���
  if GetLookAHeadChar() = ';' then
  begin
    // ';'
    ReadToken(TOKEN_TYPE_DELIM_SEMICOLON);
  end
  else
  begin
    InitToken := GetNextToken();
    case InitToken of
      TOKEN_TYPE_END_OF_STREAM:
        printError('Unexpected end of file');
      TOKEN_TYPE_IDENT:
        begin
          ParseAssign();
        end;
    else
      printError('L_Value is Error in the first parame of for');
    end;
  end;
  // �����������ʽ
  if GetLookAHeadChar() = ';' then
  begin
    // ';'
    ReadToken(TOKEN_TYPE_DELIM_SEMICOLON);
  end
  else
  begin
    ParseExpr();
  end;

  // // ����������
  // if GetLookAHeadChar() = ';' then
  // begin
  // // ';'
  // ReadToken(TOKEN_TYPE_DELIM_SEMICOLON);
  // end
  // else
  // begin
  // ParseExpr();
  // end;
  // // ���������� ')'
  // ReadToken(TOKEN_TYPE_DELIM_CLOSE_PAREN);

  // �����������_T0,����� 0 �Ļ�������ѭѭ��
  iInstrIndex := AddICodeInstr(g_iCurrScope, INSTR_POP);
  AddVarICodeOp(g_iCurrScope, iInstrIndex, g_iTempVar0SymbolIndex);

  iInstrIndex := AddICodeInstr(g_iCurrScope, INSTR_JE);
  AddVarICodeOp(g_iCurrScope, iInstrIndex, g_iTempVar0SymbolIndex);
  AddIntICodeOp(g_iCurrScope, iInstrIndex, 0);
  AddJumpTargetICodeOp(g_iCurrScope, iInstrIndex, iEndTargetIndex);

  // ����һ���µ�ѭ��ʵ���ṹ
  GetMem(apLoop, SizeOf(Loop));

  // ���ÿ�ʼ�ͽ�����ת��Ŀ������
  apLoop.iStartTargetIndex := iStartTargetIndex;
  apLoop.iEndTargetIndex := iEndTargetIndex;

  // ��ѭ���ṹѹ�뵽��ջ��
  Push(@g_LoopStack, apLoop);

  // ����ѭ����
  ParseStatement();

  // ����ѭ����
  PopUp(@g_LoopStack);

  // ��������ת�ص�ѭ����ʼ�ĵط�
  iInstrIndex := AddICodeInstr(g_iCurrScope, INSTR_JMP);
  AddJumpTargetICodeOp(g_iCurrScope, iInstrIndex, iStartTargetIndex);

  // ����ѭ��������תĿ��
  AddICodeJumpTarget(g_iCurrScope, iEndTargetIndex);
end;

procedure ParseBreak();
var
  iTargetIndex: Integer;
  iInstrIndex: Integer;
begin
  // ȷ����һ��ѭ����
  if IsStackEmpty(@g_LoopStack) then
    printError('break illegal outside loops');

  // ��ע������
  AddICodeSourceLine(g_iCurrScope, GetCurrSourceLine());

  // ��ͼ����һ���ֺ�
  ReadToken(TOKEN_TYPE_DELIM_SEMICOLON);

  // ���ѭ����������תĿ������
  iTargetIndex := pLoop(peek(@g_LoopStack)).iEndTargetIndex;

  // ��������ת��ѭ���Ľ���λ��
  iInstrIndex := AddICodeInstr(g_iCurrScope, INSTR_JMP);
  AddJumpTargetICodeOp(g_iCurrScope, iInstrIndex, iTargetIndex);
end;

procedure ParseContinue();
var
  iTargetIndex: Integer;
  iInstrIndex: Integer;
begin
  if IsStackEmpty(@g_LoopStack) then
    printError('continue illegal outside loops');

  // ��׼������
  AddICodeSourceLine(g_iCurrScope, GetCurrSourceLine());

  // ��ͼ����ֺ�
  ReadToken(TOKEN_TYPE_DELIM_SEMICOLON);

  // ���ѭ����ʼλ�õ���תĿ������
  iTargetIndex := pLoop(peek(@g_LoopStack)).iStartTargetIndex;

  // ��������ת
  iInstrIndex := AddICodeInstr(g_iCurrScope, INSTR_JMP);
  AddJumpTargetICodeOp(g_iCurrScope, iInstrIndex, iTargetIndex);
end;

procedure ParseReturn();
var
  iInstrIndex: Integer;
begin
  // ȷ��������һ��������
  if g_iCurrScope = SCOPE_GLOBAL then
    printError('return illegal in global scope');
  // ��ע������
  AddICodeSourceLine(g_iCurrScope, GetCurrSourceLine());
  // �������û�зֺţ��������ʽ��������ŵ�_RetVal��
  if GetLookAHeadChar() <> ';' then
  begin
    // �������ʽ�����㷵��ֵ��������ֵ�ŵ���ջ��
    ParseExpr();
    // ȷ�����Ǵ��ĸ���������
    if (g_ScriptHeader.iIsMainFuncPresent = 1) and (g_ScriptHeader.iMainFuncIndex = g_iCurrScope)
    then
    begin
      // ����� _Main(), �����������_T0
      iInstrIndex := AddICodeInstr(g_iCurrScope, INSTR_POP);
      AddVarICodeOp(g_iCurrScope, iInstrIndex, g_iTempVar0SymbolIndex);
    end
    else
    begin
      // �������_Main,�����������_RetVal�Ĵ���
      iInstrIndex := AddICodeInstr(g_iCurrScope, INSTR_POP);
      AddRegICodeOp(g_iCurrScope, iInstrIndex, REG_CODE_RETVAL);
    end;

  end
  else
  begin
    // �˳�_Main()��ʱ������ _T0
    if (g_ScriptHeader.iIsMainFuncPresent = 1) and (g_ScriptHeader.iMainFuncIndex = g_iCurrScope)
    then
    begin
      iInstrIndex := AddICodeInstr(g_iCurrScope, INSTR_MOV);
      AddVarICodeOp(g_iCurrScope, iInstrIndex, 0);
    end;
  end;

  if (g_ScriptHeader.iIsMainFuncPresent = 1) and (g_ScriptHeader.iMainFuncIndex = g_iCurrScope) then
  begin
    // ��_Main,�����˳�����_T0��Ϊ�˳�����
    iInstrIndex := AddICodeInstr(g_iCurrScope, INSTR_EXIT);
    AddVarICodeOp(g_iCurrScope, iInstrIndex, g_iTempVar0SymbolIndex);
  end
  else
  begin
    // ����_Main,���ԴӺ�������
    AddICodeInstr(g_iCurrScope, INSTR_RET);
  end;
end;

end.
