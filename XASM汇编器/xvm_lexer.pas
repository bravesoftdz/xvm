unit xvm_lexer;

interface

uses
  xvm_types, xvm_instr, System.SysUtils;

type
  // ---- Lexical Analysis ---------------------------------
  Token = integer;

  // ��������
  _Lexer = record
    iCurrSourceLine: integer; // ��Դ�ļ�������
    iIndex0: integer; // �ַ�������
    iIndex1: integer;
    CurrToken: Token; //
    pstrCurrLexeme: array [0 .. MAX_LEXEME_SIZE - 1] of AnsiChar; // ��ǰԪ��
    iCurrLexState: integer; // ��ǰ����״̬
  end;

  Lexer = _Lexer;

function IsCharWhitespace(cChar: AnsiChar): Boolean;
function IsCharNumeric(cChar: AnsiChar): Boolean;
function IsCharIdent(cChar: AnsiChar): Boolean;
function IsCharDelimiter(cChar: AnsiChar): Boolean;
function IsStringWhitespace(pstrString: PAnsiChar): Boolean;
function IsStringIdent(pstrString: PAnsiChar): Boolean;
function IsStringInteger(pstrString: PAnsiChar): Boolean;
function IsStringFloat(pstrString: PAnsiChar): Boolean;
//
function GetCurrSourceStr(currLine: integer): PAnsiChar;
function GetCurrOpType(aOptype: pOpType; currIndex: integer): OpType;
procedure ResetLexer();
function GetNextToken(): Token;
function GetCurrLexeme(): PAnsiChar;
function GetLookAheadChar(): AnsiChar;
function SkipToNextLine(): Boolean;

var
  g_Lexer: Lexer; // the lexer
  g_ppstrSourceCode: PPAnsiChar;
  // ������
  g_iSourceLines: integer;
  // ��Ч��
  g_iSourceCodeSize: integer;

implementation

function GetCurrSourceStr(currLine: integer): PAnsiChar;
begin
  inc(g_ppstrSourceCode, currLine);
  Result := g_ppstrSourceCode^;
  Dec(g_ppstrSourceCode, currLine);
end;

function GetCurrOpType(aOptype: pOpType; currIndex: integer): OpType;
begin
  inc(aOptype, currIndex);
  Result := aOptype^;
  Dec(aOptype, currIndex);
end;

function IsCharWhitespace(cChar: AnsiChar): Boolean;
begin
  Result := (cChar = ' ') or (cChar = #9);
end;

function IsCharNumeric(cChar: AnsiChar): Boolean;
begin
  Result := cChar in ['0' .. '9'];
end;

function IsCharIdent(cChar: AnsiChar): Boolean;
begin
  Result := (cChar in ['0' .. '9', 'A' .. 'Z', 'a' .. 'z', '_']);
end;

function IsCharDelimiter(cChar: AnsiChar): Boolean;
begin
  Result := (cChar in [':', ',', '"', '[', ']', '{', '}', #10]) or IsCharWhitespace(cChar);
end;

function IsStringWhitespace(pstrString: PAnsiChar): Boolean;
var
  iCurrCharIndex: integer;
begin
  // if the string is null ,return false
  if pstrString = nil then
  begin
    Result := False;
    Exit;
  end;
  // if the length is zero,it's technicall whitespace
  if StrLen(pstrString) = 0 then
  begin
    Result := False;
    Exit;
  end;
  // loop through each character and return false if a non-whitespace is found
  for iCurrCharIndex := 0 to StrLen(pstrString) - 1 do
  begin
    if (not IsCharWhitespace(pstrString[iCurrCharIndex])) and (pstrString[iCurrCharIndex] <> '\n')
    then
    begin
      Result := False;
      Exit;
    end;
  end;
  Result := True;
end;

function IsStringIdent(pstrString: PAnsiChar): Boolean;
var
  iCurrCharIndex: integer;
begin
  if pstrString = nil then
  begin
    Result := False;
    Exit;
  end;
  if StrLen(pstrString) = 0 then
  begin
    Result := False;
    Exit;
  end;
  if pstrString[0] in ['0' .. '9'] then
  begin
    Result := False;
    Exit;
  end;
  for iCurrCharIndex := 0 to StrLen(pstrString) - 1 do
  begin
    if (not IsCharIdent(pstrString[iCurrCharIndex])) then
    begin
      Result := False;
      Exit;
    end;
  end;

  Result := True;
end;

function IsStringInteger(pstrString: PAnsiChar): Boolean;
var
  iCurrCharIndex: integer;
begin
  if pstrString = nil then
  begin
    Result := False;
    Exit;
  end;
  if StrLen(pstrString) = 0 then
  begin
    Result := False;
    Exit;
  end;
  for iCurrCharIndex := 0 to StrLen(pstrString) - 1 do
  begin
    if (not IsCharNumeric(pstrString[iCurrCharIndex])) and (pstrString[iCurrCharIndex] <> '-') then
    begin
      Result := False;
      Exit;
    end;
  end;
  for iCurrCharIndex := 1 to StrLen(pstrString) - 1 do
  begin
    if pstrString[iCurrCharIndex] = '-' then
    begin
      Result := False;
      Exit;
    end;
  end;

  Result := True;
end;

function IsStringFloat(pstrString: PAnsiChar): Boolean;
var
  iCurrCharIndex: integer;
  iRadixPointFound: integer;
begin
  if pstrString = nil then
  begin
    Result := False;
    Exit;
  end;
  if StrLen(pstrString) = 0 then
  begin
    Result := False;
    Exit;
  end;
  // first make sure we've got only numbers and radix points
  for iCurrCharIndex := 0 to StrLen(pstrString) - 1 do
  begin
    if (not IsCharNumeric(pstrString[iCurrCharIndex])) and (not(pstrString[iCurrCharIndex] = '.'))
      and (not(pstrString[iCurrCharIndex] = '-')) then
    begin
      Result := False;
      Exit;
    end;
  end;
  // make sure only one radix point is present
  iRadixPointFound := 0;
  for iCurrCharIndex := 0 to StrLen(pstrString) - 1 do
  begin
    if pstrString[iCurrCharIndex] = '.' then
    begin
      if iRadixPointFound <> 0 then
      begin
        Result := False;
        Exit;
      end
      else
      begin
        iRadixPointFound := 1;
      end;
    end;
  end;
  // make sure the minus sign only appears in the first character
  for iCurrCharIndex := 1 to StrLen(pstrString) - 1 do
  begin
    if pstrString[iCurrCharIndex] = '-' then
    begin
      Result := False;
      Exit;
    end;
  end;
  // if a radix point was found,return true;otherwise,it must be an integer so return false
  Result := iRadixPointFound <> 0;
end;

procedure ResetLexer();
begin
  g_Lexer.iCurrSourceLine := 0;
  g_Lexer.iIndex0 := 0;
  g_Lexer.iIndex1 := 0;
  //
  g_Lexer.CurrToken := TOKEN_TYPE_INVALID;
  //
  g_Lexer.iCurrLexState := LEX_STATE_NO_STRING;
end;

function SkipToNextLine(): Boolean;
begin
  inc(g_Lexer.iCurrSourceLine);
  if (g_Lexer.iCurrSourceLine >= g_iSourceCodeSize) then
  begin
    Result := False;
    Exit;
  end;
  g_Lexer.iIndex0 := 0;
  g_Lexer.iIndex1 := 0;
  g_Lexer.iCurrLexState := LEX_STATE_NO_STRING;
  Result := True;
end;

function GetCurrLexeme(): PAnsiChar;
begin
  Result := PAnsiChar(@g_Lexer.pstrCurrLexeme);
end;

function GetLookAheadChar(): AnsiChar;
var
  iCurrSourceLine: integer;
  iIndex: integer;
begin
  iCurrSourceLine := g_Lexer.iCurrSourceLine;
  iIndex := g_Lexer.iIndex1;
  if g_Lexer.iCurrLexState <> LEX_STATE_IN_STRING then
  begin
    while True do
    begin
      if iIndex >= StrLen(GetCurrSourceStr(g_Lexer.iCurrSourceLine)) then
      begin
        inc(iCurrSourceLine);
        if (iCurrSourceLine >= g_iSourceCodeSize) then
        begin
          Result := #0;
          Exit;
        end;
        iIndex := 0;
      end;
      //
      if (not IsCharWhitespace(GetCurrSourceStr(g_Lexer.iCurrSourceLine)[iIndex])) then
        Break;
      //
      inc(iIndex);
    end;
  end;
  Result := GetCurrSourceStr(g_Lexer.iCurrSourceLine)[iIndex];
end;

function GetInstrByMnemonic(pstrMnemonic: PAnsiChar; pInstr: pInstrLookup): Boolean;
var
  iCurrInstrIndex: integer;
begin
  for iCurrInstrIndex := 0 to MAX_INSTR_LOOKUP_COUNT - 1 do
  begin
    if StrComp(PAnsiChar(@g_InstrTable[iCurrInstrIndex].pstrMnemonic), pstrMnemonic) = 0 then
    begin
      pInstr^ := g_InstrTable[iCurrInstrIndex];
      Result := True;
      Exit;
    end;
    Result := False;
  end;
end;

function GetNextToken(): Token;
var
  iCurrSourceIndex: integer;
  iCurrDestIndex: integer;
  InStr: InstrLookup;
begin
  g_Lexer.iIndex0 := g_Lexer.iIndex1;

  if (g_Lexer.iIndex0 >= StrLen(GetCurrSourceStr(g_Lexer.iCurrSourceLine))) then
  begin
    if not SkipToNextLine then
    begin
      Result := END_OF_TOKEN_STREAM;
      Exit;
    end;
  end;

  if (g_Lexer.iCurrLexState = LEX_STATE_END_STRING) then
  begin
    g_Lexer.iCurrLexState := LEX_STATE_NO_STRING;
  end;

  // �����ַ����ڵĻ������ո�
  if (g_Lexer.iCurrLexState <> LEX_STATE_IN_STRING) then
  begin
    while True do
    begin
      if (not IsCharWhitespace(GetCurrSourceStr(g_Lexer.iCurrSourceLine)[g_Lexer.iIndex0]))
      then
      begin
        Break;
      end;
      inc(g_Lexer.iIndex0);
    end;
  end;

  g_Lexer.iIndex1 := g_Lexer.iIndex0;

  // �ǿո��ַ�����ʼ�ִ�
  while True do
  begin
    // ɨ���ַ���
    if (g_Lexer.iCurrLexState = LEX_STATE_IN_STRING) then
    begin
      // û���ַ���������
      if (g_Lexer.iIndex1 >= StrLen(GetCurrSourceStr(g_Lexer.iCurrSourceLine))) then
      begin
        g_Lexer.CurrToken := TOKEN_TYPE_INVALID;
        Result := g_Lexer.CurrToken;
        Exit;
      end;
      // ת���ַ�
      if (GetCurrSourceStr(g_Lexer.iCurrSourceLine)[g_Lexer.iIndex1] = '\') then
      begin
        inc(g_Lexer.iIndex1, 2);
        Continue;
      end;
      // �ַ���������
      if (GetCurrSourceStr(g_Lexer.iCurrSourceLine)[g_Lexer.iIndex1] = '"') then
      begin
        Break;
      end;
      inc(g_Lexer.iIndex1);
    end
    // ���ַ���
    else
    begin
      // �����ǰ������β,���ʽ��������˳�ѭ��
      if (g_Lexer.iIndex1 >= StrLen(GetCurrSourceStr(g_Lexer.iCurrSourceLine))) then
      begin
        Break;
      end;
      // �����ǰ���Ƿָ���,��ǰ�ƶ�һ���ַ�,�����˳�ѭ��
      if (IsCharDelimiter(GetCurrSourceStr(g_Lexer.iCurrSourceLine)[g_Lexer.iIndex1])) then
      begin
        Break;
      end;
      inc(g_Lexer.iIndex1);
    end;
  end;

  if (g_Lexer.iIndex1 - g_Lexer.iIndex0 = 0) then
  begin
    inc(g_Lexer.iIndex1);
  end;

  iCurrDestIndex := 0;
  iCurrSourceIndex := g_Lexer.iIndex0;
  while iCurrSourceIndex < g_Lexer.iIndex1 do
  begin
    // ������ڷ���һ���ַ���,���ת���ַ�����֧������б��֮����ַ�
    if (g_Lexer.iCurrLexState = LEX_STATE_IN_STRING) then
      if (GetCurrSourceStr(g_Lexer.iCurrSourceLine)[iCurrSourceIndex] = '\' { '\\' } ) then
      begin
        inc(iCurrSourceIndex);
      end;
    // copy the character from the source line to the lexeme
    g_Lexer.pstrCurrLexeme[iCurrDestIndex] := GetCurrSourceStr(g_Lexer.iCurrSourceLine)
      [iCurrSourceIndex];

    inc(iCurrDestIndex);
    inc(iCurrSourceIndex);
  end;

  g_Lexer.pstrCurrLexeme[iCurrDestIndex] := #0 { '\0' };

  if (g_Lexer.iCurrLexState <> LEX_STATE_IN_STRING) then
  begin
    StrUpper(PAnsiChar(@g_Lexer.pstrCurrLexeme));
  end;
  // ----������ʶ��
  // �ҳ��µĵ������������������֣�����ʷ�������û����ƥ���������
  // ���ͣ�������Ϊ���Ϸ����ͣ�Invalid��
  g_Lexer.CurrToken := TOKEN_TYPE_INVALID;
  // ��һ���������򵥵ģ�����ַ��������ǻ�Ծ״̬
  // ���Ǿ�֪���Ҵ�������ַ��������֣��˶�������ַ�����˫���ű�־
  // �����ζ�����Ƕ������ǿմ�������Ӧ������һ��˫����
  if (StrLen(PAnsiChar(@g_Lexer.pstrCurrLexeme)) > 1) or (g_Lexer.pstrCurrLexeme[0] <> '"') then
  begin
    if (g_Lexer.iCurrLexState = LEX_STATE_IN_STRING) then
    begin
      g_Lexer.CurrToken := TOKEN_TYPE_STRING;
      Result := TOKEN_TYPE_STRING;
      Exit;
    end;
  end;
  // ���ڼ�鵥�ַ�������
  // now let's check for the single-character tokens
  if (StrLen(PAnsiChar(@g_Lexer.pstrCurrLexeme)) = 1) then
  begin
    case g_Lexer.pstrCurrLexeme[0] of
      '"':
        begin
          case (g_Lexer.iCurrLexState) of
            LEX_STATE_NO_STRING:
              begin
                g_Lexer.iCurrLexState := LEX_STATE_IN_STRING;
              end;
            LEX_STATE_IN_STRING:
              begin
                g_Lexer.iCurrLexState := LEX_STATE_END_STRING;
              end;
          end;
          g_Lexer.CurrToken := TOKEN_TYPE_QUOTE;
        end;
      // Comma
      ',':
        begin
          g_Lexer.CurrToken := TOKEN_TYPE_COMMA;
        end;
      // Colon
      ':':
        begin
          g_Lexer.CurrToken := TOKEN_TYPE_COLON;
        end;
      // Opening Bracket
      '[':
        begin
          g_Lexer.CurrToken := TOKEN_TYPE_OPEN_BRACKET;
        end;
      // Close Bracket
      ']':
        begin
          g_Lexer.CurrToken := TOKEN_TYPE_CLOSE_BRACKET;
        end;
      // Opening Brace
      '{':
        begin
          g_Lexer.CurrToken := TOKEN_TYPE_OPEN_BRACE;
        end;
      // close Brace
      '}':
        begin
          g_Lexer.CurrToken := TOKEN_TYPE_CLOSE_BRACE;
        end;
      // Newline
      #10:
        begin
          g_Lexer.CurrToken := TOKEN_TYPE_NEWLINE;
        end;
    end;
  end;
  // now let's check for the multi-character tokens
  // is it an integer?
  if (IsStringInteger(PAnsiChar(@g_Lexer.pstrCurrLexeme))) then
    g_Lexer.CurrToken := TOKEN_TYPE_INT;
  // float
  if (IsStringFloat(PAnsiChar(@g_Lexer.pstrCurrLexeme))) then
    g_Lexer.CurrToken := TOKEN_TYPE_FLOAT;
  if (IsStringIdent(PAnsiChar(@g_Lexer.pstrCurrLexeme))) then
    g_Lexer.CurrToken := TOKEN_TYPE_IDENT;
  if (StrIComp(PAnsiChar(@g_Lexer.pstrCurrLexeme), 'SETSTACKSIZE') = 0) then
    g_Lexer.CurrToken := TOKEN_TYPE_SETSTACKSIZE;
  if (StrIComp(PAnsiChar(@g_Lexer.pstrCurrLexeme), 'SETPRIORITY') = 0) then
    g_Lexer.CurrToken := TOKEN_TYPE_SETPRIORITY;
  if (StrIComp(PAnsiChar(@g_Lexer.pstrCurrLexeme), 'VAR') = 0) then
    g_Lexer.CurrToken := TOKEN_TYPE_VAR;
  if (StrIComp(PAnsiChar(@g_Lexer.pstrCurrLexeme), 'FUNC') = 0) then
    g_Lexer.CurrToken := TOKEN_TYPE_FUNC;
  if (StrIComp(PAnsiChar(@g_Lexer.pstrCurrLexeme), 'PARAM') = 0) then
    g_Lexer.CurrToken := TOKEN_TYPE_PARAM;
  if (StrIComp(PAnsiChar(@g_Lexer.pstrCurrLexeme), '_RETVAL') = 0) then
    g_Lexer.CurrToken := TOKEN_TYPE_REG_RETVAL;
  // it is an instruction
  if (GetInstrByMnemonic(PAnsiChar(@g_Lexer.pstrCurrLexeme), @InStr)) then
  begin
    g_Lexer.CurrToken := TOKEN_TYPE_INSTR;
  end;
  Result := g_Lexer.CurrToken;
end;

end.
