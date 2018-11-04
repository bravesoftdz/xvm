{ ******************************************************* }
{                                                         }
{ XVM                                                     }
{                                                         }
{ ��Ȩ���� (C) 2012 adsj                                  }
{ Mode�� �ʷ�������ģ��                                   }
{ ******************************************************* }
unit lexer;

interface

uses
  System.SysUtils, linked_list, globals;

const
{$REGION '��������'}
  MAX_LEXEME_SIZE = 128;
  MAX_DELIM_COUNT = 8; // 24
  // ----Operators
  MAX_OP_STATE_COUNT = 34;
  // ----Lexer States
  LEX_STATE_UNKNOWN = 0;
  LEX_STATE_START = 1;
  LEX_STATE_INT = 2;
  LEX_STATE_FLOAT = 3;
  LEX_STATE_IDENT = 4; // ������
  LEX_STATE_OP = 5; // �����
  LEX_STATE_DELIM = 6; // �ָ���
  LEX_STATE_STRING = 7;
  LEX_STATE_STRING_ESCAPE = 8;
  LEX_STATE_STRING_CLOSE_QUOTE = 9;
  // ----TOKEN types
  TOKEN_TYPE_END_OF_STREAM = 0;
  TOKEN_TYPE_INVALID = 1;

  TOKEN_TYPE_INT = 2;
  TOKEN_TYPE_FLOAT = 3;
  TOKEN_TYPE_IDENT = 4;
  TOKEN_TYPE_RSRVD_VAR = 5;
  TOKEN_TYPE_RSRVD_TRUE = 6;
  TOKEN_TYPE_RSRVD_FALSE = 7;
  TOKEN_TYPE_RSRVD_IF = 8;
  TOKEN_TYPE_RSRVD_ELSE = 9;
  TOKEN_TYPE_RSRVD_BREAK = 10;
  TOKEN_TYPE_RSRVD_CONTINUE = 11;
  TOKEN_TYPE_RSRVD_FOR = 12;
  TOKEN_TYPE_RSRVD_WHILE = 13;
  TOKEN_TYPE_RSRVD_FUNC = 14;
  TOKEN_TYPE_RSRVD_RETURN = 15;
  TOKEN_TYPE_RSRVD_HOST = 16; // host

  TOKEN_TYPE_OP = 18; // �����
  TOKEN_TYPE_DELIM_COMMA = 19;
  TOKEN_TYPE_DELIM_OPEN_PAREN = 20;
  TOKEN_TYPE_DELIM_CLOSE_PAREN = 21;
  TOKEN_TYPE_DELIM_OPEN_BRACE = 22;
  TOKEN_TYPE_DELIM_CLOSE_BRACE = 23;
  TOKEN_TYPE_DELIM_OPEN_CURLY_BRACE = 24;
  TOKEN_TYPE_DELIM_CLOSE_CURLY_BRACE = 25;
  TOKEN_TYPE_DELIM_SEMICOLON = 26;

  TOKEN_TYPE_STRING = 27;

  // ��������
  OP_TYPE_ADD = 0; // +
  OP_TYPE_SUB = 1; // -
  OP_TYPE_MUL = 2; // *
  OP_TYPE_DIV = 3; // /
  OP_TYPE_MOD = 4; // %
  OP_TYPE_EXP = 5; // ^
  OP_TYPE_CONCAT = 35; // $

  OP_TYPE_INC = 15; // ++
  OP_TYPE_DEC = 17; // --

  OP_TYPE_ASSIGN_ADD = 14; // +=
  OP_TYPE_ASSIGN_SUB = 16; // -=
  OP_TYPE_ASSIGN_MUL = 18; // *=
  OP_TYPE_ASSIGN_DIV = 19; // /=
  OP_TYPE_ASSIGN_MOD = 20; // %=
  OP_TYPE_ASSIGN_EXP = 21; // ^=
  OP_TYPE_ASSIGN_CONCAT = 36; // $=
  // λ����
  OP_TYPE_BITWISE_AND = 6; // &
  OP_TYPE_BITWISE_OR = 7; // |
  OP_TYPE_BITWISE_XOR = 8; // #
  OP_TYPE_BITWISE_NOT = 9; // ~
  OP_TYPE_BITWISE_SHIFT_LEFT = 30; // <<
  OP_TYPE_BITWISE_SHIFT_RIGHT = 32; // >>

  OP_TYPE_ASSIGN_AND = 22; // &=
  OP_TYPE_ASSIGN_OR = 24; // |=
  OP_TYPE_ASSIGN_XOR = 26; // #=
  OP_TYPE_ASSIGN_SHIFT_LEFT = 33; // <<=
  OP_TYPE_ASSIGN_SHIFT_RIGHT = 34; // >>=
  // �߼�
  OP_TYPE_LOGICAL_AND = 23; // &&
  OP_TYPE_LOGICAL_OR = 25; // ||
  OP_TYPE_LOGICAL_NOT = 10; // !
  // ��ϵ
  OP_TYPE_EQUAL = 28; // ==
  OP_TYPE_NOT_EQUAL = 27; // !=
  OP_TYPE_LESS = 12; // <
  OP_TYPE_GREATER = 13; // >
  OP_TYPE_LESS_EQUAL = 29; // <=
  OP_TYPE_GREATER_EQUAL = 31; // >=
  // ��ֵ
  OP_TYPE_ASSIGN = 11; // =
{$ENDREGION}

type
  // ----------------------------------------------------------------
  _OpState = record
    cChar: AnsiChar; // ״̬�ַ�
    iSubStateIndex: Integer; // ���״̬��������
    // ���״̬��Ϣ
    iSubStateCount: Integer; // ���״̬����
    iIndex: Integer; // ���������
  end;

  OpState = _OpState;

  // ----------------------------------------------------------------
const
  cDelims: array [0 .. MAX_DELIM_COUNT - 1] of AnsiChar = (',', '(', ')', '[', ']', '{', '}', ';');
  // ������ַ����е�һ���ַ� 34
  g_OpChars0: array [0 .. 13] of OpState = //
    ((cChar: '+'; iSubStateIndex: 0; iSubStateCount: 2; iIndex: 0), //
    (cChar: '-'; iSubStateIndex: 2; iSubStateCount: 2; iIndex: 1), //
    (cChar: '*'; iSubStateIndex: 4; iSubStateCount: 1; iIndex: 2), //
    (cChar: '/'; iSubStateIndex: 5; iSubStateCount: 1; iIndex: 3), //
    (cChar: '%'; iSubStateIndex: 6; iSubStateCount: 1; iIndex: 4), //
    (cChar: '^'; iSubStateIndex: 7; iSubStateCount: 1; iIndex: 5), //
    (cChar: '&'; iSubStateIndex: 8; iSubStateCount: 2; iIndex: 6), //
    (cChar: '|'; iSubStateIndex: 10; iSubStateCount: 2; iIndex: 7), //
    (cChar: '#'; iSubStateIndex: 12; iSubStateCount: 1; iIndex: 8), //
    (cChar: '~'; iSubStateIndex: 0; iSubStateCount: 0; iIndex: 9), //
    (cChar: '!'; iSubStateIndex: 13; iSubStateCount: 1; iIndex: 10), //
    (cChar: '='; iSubStateIndex: 14; iSubStateCount: 1; iIndex: 11), //
    (cChar: '<'; iSubStateIndex: 15; iSubStateCount: 2; iIndex: 12), //
    (cChar: '>'; iSubStateIndex: 17; iSubStateCount: 2; iIndex: 13));
  // ������ַ����еĵڶ����ַ���
  g_OpChars1: array [0 .. 19] of OpState = //
    ((cChar: '='; iSubStateIndex: 0; iSubStateCount: 0; iIndex: 14), // +=
    (cChar: '+'; iSubStateIndex: 0; iSubStateCount: 0; iIndex: 15), // ++
    (cChar: '='; iSubStateIndex: 0; iSubStateCount: 0; iIndex: 16), // -=
    (cChar: '-'; iSubStateIndex: 0; iSubStateCount: 0; iIndex: 17), // --
    (cChar: '='; iSubStateIndex: 0; iSubStateCount: 0; iIndex: 18), // *=
    (cChar: '='; iSubStateIndex: 0; iSubStateCount: 0; iIndex: 19), // /=
    (cChar: '='; iSubStateIndex: 0; iSubStateCount: 0; iIndex: 20), // %=
    (cChar: '='; iSubStateIndex: 0; iSubStateCount: 0; iIndex: 21), // ^=
    (cChar: '='; iSubStateIndex: 0; iSubStateCount: 0; iIndex: 22), // &=
    (cChar: '&'; iSubStateIndex: 0; iSubStateCount: 0; iIndex: 23), // &&
    (cChar: '='; iSubStateIndex: 0; iSubStateCount: 0; iIndex: 24), // |=
    (cChar: '|'; iSubStateIndex: 0; iSubStateCount: 0; iIndex: 25), // ||
    (cChar: '='; iSubStateIndex: 0; iSubStateCount: 0; iIndex: 26), // #=
    (cChar: '='; iSubStateIndex: 0; iSubStateCount: 0; iIndex: 27), // !=
    (cChar: '='; iSubStateIndex: 0; iSubStateCount: 0; iIndex: 28), // ==
    (cChar: '='; iSubStateIndex: 0; iSubStateCount: 0; iIndex: 29), // <=
    (cChar: '<'; iSubStateIndex: 0; iSubStateCount: 1; iIndex: 30), // <<
    (cChar: '='; iSubStateIndex: 0; iSubStateCount: 0; iIndex: 31), // >=
    (cChar: '>'; iSubStateIndex: 1; iSubStateCount: 1; iIndex: 32), // >>
    (cChar: '='; iSubStateIndex: 0; iSubStateCount: 0; iIndex: 36) // $=
    ); // >>
  // ������ַ����еĵ������ַ�
  g_OpChars2: array [0 .. 1] of OpState = //
    ((cChar: '='; iSubStateIndex: 0; iSubStateCount: 0; iIndex: 33), //
    (cChar: '>'; iSubStateIndex: 0; iSubStateCount: 0; iIndex: 34));

type
  Token = Integer;

  // ----------------------------------------------------------------
  // �ʷ�������״̬
  _LexerState = record
    iCurrLineIndex: Integer; // ��ǰ������
    pCurrLine: pLinkedListNode; // ��ǰ�нڵ�ָ��
    CurrToken: Token; // ��ǰ���Է�
    pstrCurrLexeme: array [0 .. MAX_LEXEME_SIZE - 1] of AnsiChar; // ��ǰ����
    iCurrLexemeStart: Integer; // ��ʼ����
    iCurrLexemeEnd: Integer; // ��������
    iCurrOp: Integer; // ��������
  end;

  LexerState = _LexerState;
  // ----------------------------------------------------------------
  (* ���ôʷ������� *)
procedure ResetLexer();
(* ���ƴʷ�������״̬ *)
procedure CopyLexerState(var pDestState: LexerState; var pSourceState: LexerState);
(* ��ò�����״̬���� *)
function GetOpStateIndex(cChar: AnsiChar; iCharIndex: Integer; iSubStateIndex: Integer;
  iSubStateCount: Integer): Integer;
(* �ƶ��ʷ����������:?�ؾ������� *)
procedure RewindTokenStream();
(* �����һ���ַ� *)
function GetNextChar(): AnsiChar;
(* ��ǰ�鿴�ַ� *)
function GetLookAheadChar(): AnsiChar;
(* �����һ����ʶ�� *)
function GetNextToken(): Token;
(* ��õ�ǰ���� *)
function GetCurrLexeme: PAnsiChar;
(* ���ص�ǰ���Է� *)
function GetCurrToken(): Token;
(* ���Ƶ�ǰ���� *)
procedure CopyCurrLexeme(pstrBuffer: PAnsiChar);
(* ���ص�ǰ�д��� *)
function GetCurrSourceLine(): PAnsiChar;
(* ���ص�ǰ�к� *)
function GetCurrSourceLineIndex(): Integer;
(* ���ص�ǰ������ʼ���� *)
function GetLexemeStartIndex(): Integer;
//
function GetCurrOp(): Integer;

var
  // lexer
  g_CurrLexerState: LexerState;
  g_PrevLexerState: LexerState;

implementation

{$REGION '�ַ��ж�'}

function IsCharWitespace(cChar: AnsiChar): Boolean;
begin
  Result := cChar in [' ', #9, #10];
end;

function IsCharNumeric(cChar: AnsiChar): Boolean;
begin
  Result := cChar in ['0' .. '9'];
end;

function IsCharIdent(cChar: AnsiChar): Boolean;
begin
  Result := ((cChar in ['0' .. '9']) or (cChar in ['A' .. 'Z']) or (cChar in ['a' .. 'z']) or
    (cChar = '_'));
end;

function IsCharDelim(cChar: AnsiChar): Boolean;
var
  iCurrDelimerIndex: Integer;
begin
  for iCurrDelimerIndex := 0 to MAX_DELIM_COUNT - 1 do
  begin
    if cChar = cDelims[iCurrDelimerIndex] then
    begin
      Result := True;
      Exit;
    end;
  end;
  Result := False;
end;

function IsCharOpChar(cChar: AnsiChar; iCharIndex: Integer): Boolean;
var
  iCurrOpStateIndex: Integer;
  cOpChar: AnsiChar;
begin
  case iCharIndex of
    0:
      for iCurrOpStateIndex := 0 to Length(g_OpChars0) - 1 do
      begin
        cOpChar := g_OpChars0[iCurrOpStateIndex].cChar;
        if cChar = cOpChar then
        begin
          Result := True;
          Exit;
        end;
      end;
    1:
      for iCurrOpStateIndex := 0 to Length(g_OpChars1) - 1 do
      begin
        cOpChar := g_OpChars1[iCurrOpStateIndex].cChar;
        if cChar = cOpChar then
        begin
          Result := True;
          Exit;
        end;
      end;
    2:
      for iCurrOpStateIndex := 0 to Length(g_OpChars2) - 1 do
      begin
        cOpChar := g_OpChars2[iCurrOpStateIndex].cChar;
        if cChar = cOpChar then
        begin
          Result := True;
          Exit;
        end;
      end;
  end;
  Result := False;
end;
{$ENDREGION}

function GetOpStateIndex(cChar: AnsiChar; iCharIndex: Integer; iSubStateIndex: Integer;
  iSubStateCount: Integer): Integer;
var
  iStartStateIndex: Integer;
  iEndStateIndex: Integer;
  iCurrOpStateIndex: Integer;
  cOpChar: AnsiChar;
begin
  if iCharIndex = 0 then
  begin
    iStartStateIndex := 0;
    iEndStateIndex := MAX_OP_STATE_COUNT;
  end
  else
  begin
    iStartStateIndex := iSubStateIndex;
    iEndStateIndex := iStartStateIndex + iSubStateCount;
  end;

  for iCurrOpStateIndex := iStartStateIndex to iEndStateIndex - 1 do
  begin
    case iCharIndex of
      0:
        cOpChar := g_OpChars0[iCurrOpStateIndex].cChar;
      1:
        cOpChar := g_OpChars1[iCurrOpStateIndex].cChar;
      2:
        cOpChar := g_OpChars2[iCurrOpStateIndex].cChar;
    end;
    if cChar = cOpChar then
    begin
      Result := iCurrOpStateIndex;
      Exit;
    end;
  end;

  Result := -1;
end;

function GetOpState(iCharIndex: Integer; iStateIndex: Integer): OpState;
var
  State: OpState;
begin
  case iCharIndex of
    0:
      State := g_OpChars0[iStateIndex];
    1:
      State := g_OpChars1[iStateIndex];
    2:
      State := g_OpChars2[iStateIndex];
  end;
  Result := State;
end;

function GetCurrOp(): Integer;
begin
  Result := g_CurrLexerState.iCurrOp;
end;

//
procedure ResetLexer();
begin
  // Set the current line of code to the new line

  g_CurrLexerState.iCurrLineIndex := 0;
  g_CurrLexerState.pCurrLine := g_SourceCode.pHead;

  // Reset the start and end of the current lexeme to the beginning of the source

  g_CurrLexerState.iCurrLexemeStart := 0;
  g_CurrLexerState.iCurrLexemeEnd := 0;

  // Reset the current operator

  g_CurrLexerState.iCurrOp := 0;
end;

procedure CopyLexerState(var pDestState: LexerState; var pSourceState: LexerState);
begin
  pDestState.iCurrLineIndex := pSourceState.iCurrLineIndex;
  pDestState.pCurrLine := pSourceState.pCurrLine;
  pDestState.CurrToken := pSourceState.CurrToken;
  StrCopy(PAnsiChar(@pDestState.pstrCurrLexeme), PAnsiChar(@pSourceState.pstrCurrLexeme));
  pDestState.iCurrLexemeStart := pSourceState.iCurrLexemeStart;
  pDestState.iCurrLexemeEnd := pSourceState.iCurrLexemeEnd;
  pDestState.iCurrOp := pSourceState.iCurrOp;
end;

procedure RewindTokenStream();
begin
  CopyLexerState(g_CurrLexerState, g_PrevLexerState);
end;

function GetNextChar(): AnsiChar;
var
  pstrCurrLine: PAnsiChar;
begin
  // ���ַ������оֲ����ƣ�����λ��Դ�����ĩβ
  if g_CurrLexerState.pCurrLine <> nil then
    pstrCurrLine := PAnsiChar(g_CurrLexerState.pCurrLine.pData)
  else
  begin
    Result := #0;
    Exit;
  end;
  // �����ǰ���ʵĽ��������Ѿ������ַ������ȣ����ѵ���β
  if (g_CurrLexerState.iCurrLexemeEnd >= Integer(strlen(pstrCurrLine))) then
  begin
    // ����Դ�������һ���ڵ�
    g_CurrLexerState.pCurrLine := g_CurrLexerState.pCurrLine.pNext;
    // �����Ƿ�Ϸ�
    if g_CurrLexerState.pCurrLine <> nil then
    begin
      //
      pstrCurrLine := PAnsiChar(g_CurrLexerState.pCurrLine.pData);
      Inc(g_CurrLexerState.iCurrLineIndex);
      g_CurrLexerState.iCurrLexemeStart := 0;
      g_CurrLexerState.iCurrLexemeEnd := 0;
    end
    else
    begin
      Result := #0;
      Exit;
    end;
  end;
  // �����ַ���������ָ��
  Result := pstrCurrLine[g_CurrLexerState.iCurrLexemeEnd];
  Inc(g_CurrLexerState.iCurrLexemeEnd);
end;

function GetLookAheadChar(): AnsiChar;
var
  PrevLexerState: LexerState;
  cCurrChar: AnsiChar;
begin
  cCurrChar := #0;
  // ���浱ǰ״̬
  CopyLexerState(PrevLexerState, g_CurrLexerState);
  while True do
  begin
    cCurrChar := GetNextChar();
    if not IsCharWitespace(cCurrChar) then
      Break;
  end;
  // �ָ��ʷ�������״̬
  CopyLexerState(g_CurrLexerState, PrevLexerState);
  // ������ǰ�鿴�ַ�
  Result := cCurrChar;
end;

function GetNextToken: Token;
var
  iCurrLexState: Integer;
  iLexemeDone: Boolean;
  cCurrChar: AnsiChar;
  iNextLexemeCharIndex: Integer;
  iAddCurrChar: Boolean;
  // op
  iCurrOpCharIndex: Integer; { 0,1,2 ��ǰ������±� }
  iCurrOpStateIndex: Integer; // ���������
  CurrOpState: OpState; // ��ǰ�����״̬��Ϣ
  //
  TokenType: Token;
begin
  // ����ʷ��������ĵ�ǰ״̬�Իؾ����Է���
  CopyLexerState(g_PrevLexerState, g_CurrLexerState);

  g_CurrLexerState.iCurrLexemeStart := g_CurrLexerState.iCurrLexemeEnd;

  // ��ʼ״̬
  iCurrLexState := LEX_STATE_START;
  //
  iCurrOpCharIndex := 0;
  iCurrOpStateIndex := 0;
  // �����Ƿ����
  iLexemeDone := False;

  iNextLexemeCharIndex := 0;

  while True do
  begin
    cCurrChar := GetNextChar();
    if cCurrChar = #0 then
      Break;

    iAddCurrChar := True;

    case iCurrLexState of

      LEX_STATE_UNKNOWN:
        iLexemeDone := True;
      LEX_STATE_START:
        begin
          if IsCharWitespace(cCurrChar) then
          begin
            Inc(g_CurrLexerState.iCurrLexemeStart);
            iAddCurrChar := False;
          end
          else if IsCharNumeric(cCurrChar) then
          begin
            iCurrLexState := LEX_STATE_INT;
          end
          else if (cCurrChar = '.') then
          begin
            iCurrLexState := LEX_STATE_FLOAT;
          end
          else if IsCharIdent(cCurrChar) then
          begin
            iCurrLexState := LEX_STATE_IDENT;
          end
          else if IsCharDelim(cCurrChar) then
          begin
            iCurrLexState := LEX_STATE_DELIM;
          end
          else if IsCharOpChar(cCurrChar, 0) then
          begin
            // �����������״̬����
            iCurrOpStateIndex := GetOpStateIndex(cCurrChar, 0, 0, 0);
            if iCurrOpStateIndex = -1 then
            begin
              Result := TOKEN_TYPE_INVALID;
              Exit;
            end;

            CurrOpState := GetOpState(0, iCurrOpStateIndex);
            // �ƶ�����һ���ַ�
            iCurrOpCharIndex := 1;
            g_CurrLexerState.iCurrOp := CurrOpState.iIndex;
            iCurrLexState := LEX_STATE_OP;
          end
          else if cCurrChar = '"' then
          begin
            iAddCurrChar := False;
            iCurrLexState := LEX_STATE_STRING;
          end
          else
          begin
            iCurrLexState := LEX_STATE_UNKNOWN;
          end;
        end;
      LEX_STATE_INT:
        begin
          if IsCharNumeric(cCurrChar) then
          begin
            iCurrLexState := LEX_STATE_INT;
          end
          else if cCurrChar = '.' then
          begin
            iCurrLexState := LEX_STATE_FLOAT;
          end
          else if IsCharWitespace(cCurrChar) or IsCharDelim(cCurrChar) then
          begin
            iAddCurrChar := False;
            iLexemeDone := True;
          end
          else
          begin
            iCurrLexState := LEX_STATE_UNKNOWN;
          end;
        end;
      LEX_STATE_FLOAT:
        begin
          if IsCharNumeric(cCurrChar) then
          begin
            iCurrLexState := LEX_STATE_FLOAT;
          end
          else if IsCharWitespace(cCurrChar) or IsCharDelim(cCurrChar) then
          begin
            iLexemeDone := True;
            iAddCurrChar := False;
          end
          else
          begin
            iCurrLexState := LEX_STATE_UNKNOWN;
          end;
        end;
      LEX_STATE_IDENT:
        begin
          { TODO 1 -oandj -cLex : �޷��������� (x>y)������û�пո�����������ַ� }
          if IsCharIdent(cCurrChar) then
          begin
            iCurrLexState := LEX_STATE_IDENT;
          end
          else if IsCharWitespace(cCurrChar) or IsCharDelim(cCurrChar) then
          begin
            iAddCurrChar := False;
            iLexemeDone := True;
          end
          else
          begin
            iCurrLexState := LEX_STATE_UNKNOWN;
          end;
        end;
      LEX_STATE_OP:
        begin
          // ���������еĵ�ǰ�ַ�û�к��״̬����ôʶ�������
          if CurrOpState.iSubStateCount = 0 then
          begin
            iAddCurrChar := False;
            iLexemeDone := True;
            Break;
          end;
          //
          if IsCharOpChar(cCurrChar, iCurrOpCharIndex) then
          begin
            //
            iCurrOpStateIndex := GetOpStateIndex(cCurrChar, iCurrOpCharIndex,
              CurrOpState.iSubStateIndex, CurrOpState.iSubStateCount);
            if iCurrOpStateIndex = -1 then
            begin
              iCurrLexState := LEX_STATE_UNKNOWN;
            end
            else
            begin
              // �����һ�����״̬�ṹ
              CurrOpState := GetOpState(iCurrOpCharIndex, iCurrOpStateIndex);
              // ���Ŵ������������һ���ַ�
              Inc(iCurrOpCharIndex);
              g_CurrLexerState.iCurrOp := CurrOpState.iIndex;
            end;
          end
          else
          begin
            iAddCurrChar := False;
            iLexemeDone := True;
          end;
        end;
      LEX_STATE_DELIM:
        begin
          iAddCurrChar := False;
          iLexemeDone := True;
        end;
      LEX_STATE_STRING:
        begin
          if cCurrChar = '"' then
          begin
            iAddCurrChar := False;
            iCurrLexState := LEX_STATE_STRING_CLOSE_QUOTE;
          end
          else if cCurrChar = #0 then
          begin
            iAddCurrChar := False;
            iCurrLexState := LEX_STATE_UNKNOWN;
          end
          else if cCurrChar = '\' then
          begin
            iAddCurrChar := False;
            iCurrLexState := LEX_STATE_STRING_ESCAPE;
          end;
        end;
      LEX_STATE_STRING_ESCAPE:
        begin
          iCurrLexState := LEX_STATE_STRING;
        end;
      LEX_STATE_STRING_CLOSE_QUOTE:
        begin
          iAddCurrChar := False;
          iLexemeDone := True;
        end;
    end;

    if iAddCurrChar then
    begin
      g_CurrLexerState.pstrCurrLexeme[iNextLexemeCharIndex] := cCurrChar;
      Inc(iNextLexemeCharIndex);
    end;
    if iLexemeDone then
    begin
      Break;
    end;
  end;
  g_CurrLexerState.pstrCurrLexeme[iNextLexemeCharIndex] := #0;
  Dec(g_CurrLexerState.iCurrLexemeEnd);

  case iCurrLexState of
    LEX_STATE_UNKNOWN:
      TokenType := TOKEN_TYPE_INVALID;
    LEX_STATE_INT:
      TokenType := TOKEN_TYPE_INT;
    LEX_STATE_FLOAT:
      TokenType := TOKEN_TYPE_FLOAT;
    LEX_STATE_IDENT:
      begin
        TokenType := TOKEN_TYPE_IDENT;
        if StrIComp(g_CurrLexerState.pstrCurrLexeme, 'var') = 0 then
          TokenType := TOKEN_TYPE_RSRVD_VAR;
        if StrIComp(g_CurrLexerState.pstrCurrLexeme, 'true') = 0 then
          TokenType := TOKEN_TYPE_RSRVD_TRUE;
        if StrIComp(g_CurrLexerState.pstrCurrLexeme, 'false') = 0 then
          TokenType := TOKEN_TYPE_RSRVD_FALSE;
        if StrIComp(g_CurrLexerState.pstrCurrLexeme, 'if') = 0 then
          TokenType := TOKEN_TYPE_RSRVD_IF;
        if StrIComp(g_CurrLexerState.pstrCurrLexeme, 'else') = 0 then
          TokenType := TOKEN_TYPE_RSRVD_ELSE;
        if StrIComp(g_CurrLexerState.pstrCurrLexeme, 'break') = 0 then
          TokenType := TOKEN_TYPE_RSRVD_BREAK;
        if StrIComp(g_CurrLexerState.pstrCurrLexeme, 'continue') = 0 then
          TokenType := TOKEN_TYPE_RSRVD_CONTINUE;
        if StrIComp(g_CurrLexerState.pstrCurrLexeme, 'for') = 0 then
          TokenType := TOKEN_TYPE_RSRVD_FOR;
        if StrIComp(g_CurrLexerState.pstrCurrLexeme, 'while') = 0 then
          TokenType := TOKEN_TYPE_RSRVD_WHILE;
        if StrIComp(g_CurrLexerState.pstrCurrLexeme, 'func') = 0 then
          TokenType := TOKEN_TYPE_RSRVD_FUNC;
        if StrIComp(g_CurrLexerState.pstrCurrLexeme, 'return') = 0 then
          TokenType := TOKEN_TYPE_RSRVD_RETURN;
        if StrIComp(g_CurrLexerState.pstrCurrLexeme, 'host') = 0 then
          TokenType := TOKEN_TYPE_RSRVD_HOST;
      end;
    LEX_STATE_DELIM:
      begin
        case g_CurrLexerState.pstrCurrLexeme[0] of
          ',':
            TokenType := TOKEN_TYPE_DELIM_COMMA;
          '(':
            TokenType := TOKEN_TYPE_DELIM_OPEN_PAREN;
          ')':
            TokenType := TOKEN_TYPE_DELIM_CLOSE_PAREN;
          '[':
            TokenType := TOKEN_TYPE_DELIM_OPEN_BRACE;
          ']':
            TokenType := TOKEN_TYPE_DELIM_CLOSE_BRACE;
          '{':
            TokenType := TOKEN_TYPE_DELIM_OPEN_CURLY_BRACE;
          '}':
            TokenType := TOKEN_TYPE_DELIM_CLOSE_CURLY_BRACE;
          ';':
            TokenType := TOKEN_TYPE_DELIM_SEMICOLON;
        end;
      end;
    LEX_STATE_OP:
      begin
        TokenType := TOKEN_TYPE_OP;
      end;
    LEX_STATE_STRING_CLOSE_QUOTE:
      TokenType := TOKEN_TYPE_STRING;
  else
    TokenType := TOKEN_TYPE_END_OF_STREAM;
  end;
  // +
  g_CurrLexerState.CurrToken := TokenType;
  Result := TokenType;
end;

function GetCurrLexeme: PAnsiChar;
begin
  Result := @g_CurrLexerState.pstrCurrLexeme;
end;

function GetCurrToken(): Token;
begin
  Result := g_CurrLexerState.CurrToken;
end;

procedure CopyCurrLexeme(pstrBuffer: PAnsiChar);
begin
  StrCopy(pstrBuffer, @g_CurrLexerState.pstrCurrLexeme)
end;

function GetCurrSourceLine(): PAnsiChar;
begin
  if g_CurrLexerState.pCurrLine <> nil then
    Result := PAnsiChar(g_CurrLexerState.pCurrLine.pData)
  else
    Result := nil;
end;

function GetCurrSourceLineIndex(): Integer;
begin
  Result := g_CurrLexerState.iCurrLineIndex;
end;

function GetLexemeStartIndex(): Integer;
begin
  Result := g_CurrLexerState.iCurrLexemeStart;
end;

end.
