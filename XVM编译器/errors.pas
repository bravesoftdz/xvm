{ ******************************************************* }
{                                                         }
{ XVM                                                     }
{                                                         }
{ ��Ȩ���� (C) 2012 adsj                                  }
{ Mode�� ������ģ��                                     }
{ ******************************************************* }
unit errors;

interface

uses
  System.SysUtils, globals;
(* ��ӡ��ͨ���� *)
procedure ExitOnError(pstrErrorMssg: PAnsiChar);
(* ��ӡ������� *)
// procedure ExitOnCodeError(pstrErrorMssg: PAnsiChar);
procedure ExitOnCodeError(iSourceLine: Integer; pstrCurrSourceLine: PAnsiChar;
  iLexemeStartIndex: Integer; pstrErrorMssg: PAnsiChar);

implementation

procedure ExitOnError(pstrErrorMssg: PAnsiChar);
begin
  Writeln(Format('Fatal Error: %s.', [pstrErrorMssg]));
  Readln;
  Halt(0);
end;

procedure ExitOnCodeError(iSourceLine: Integer; pstrCurrSourceLine: PAnsiChar;
  iLexemeStartIndex: Integer; pstrErrorMssg: PAnsiChar);
var
  pstrSourceLine: PAnsiChar;
  iLastCharIndex: Integer;
  iCurrCharIndex: Integer;
  iCurrSpace: Integer;
begin
  { TODO -oadsj -c��ӡ���� : ��ʱ����ȫ����������� }
  // ��ӡ��Ϣ
  Writeln(Format('Error: %s.', [pstrErrorMssg]));
  Writeln(Format('Line %d', [iSourceLine])); // GetCurrSourceLineIndex()
  // ��Դ�����е����пհ׻�Ϊtab
  // ����λ��
  if pstrCurrSourceLine <> nil then
  begin
    GetMem(pstrSourceLine, StrLen(pstrCurrSourceLine) + 1);
    StrCopy(pstrSourceLine, pstrCurrSourceLine);
  end
  else
  begin
    GetMem(pstrSourceLine, 1);
    pstrSourceLine[0] := #0;
  end;
  // ������е����һ���ַ��Ƕ��б�ǣ��Ͱ�������ȥ��
  iLastCharIndex := StrLen(pstrSourceLine) - 1;
  if pstrSourceLine[iLastCharIndex] = #10 then
    pstrSourceLine[iLastCharIndex] := #0;
  // ���ÿ���ַ����ÿո��滻TAB
  for iCurrCharIndex := 0 to StrLen(pstrSourceLine) - 1 do
  begin
    if pstrSourceLine[iCurrCharIndex] = #9 then
      pstrSourceLine[iCurrCharIndex] := ' ';
  end;
  // ��ӡ�����Դ������
  Writeln(pstrSourceLine);
  // �ڳ���ĵ���ǰ���ӡһ��^
  for iCurrSpace := 0 to iLexemeStartIndex - 1 do
    Write(' ');
  Writeln('^');
  // ��ӡ��Ϣ����Դ���벻�ܱ�ת��Ϊ���
  Writeln(Format('Could not compile %s.', [g_pstrSourceFileName]));
  Readln;
  Halt(0);
end;

end.
