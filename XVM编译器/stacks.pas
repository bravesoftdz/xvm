{ ******************************************************* }
{                                                         }
{                   XVM                                   }
{                                                         }
{                  ��Ȩ���� (C) 2012 adsj                 }
{                  Mode�� ��ջִ��ģ��                    }
{ ******************************************************* }
unit stacks;

interface

uses
  System.SysUtils, linked_list;

type
  // ��ջ
  pStack = ^stack;

  _Stack = record
    ElmnList: LinkedList;
  end;

  stack = _Stack;
  //
  (* ��ʼ����ջ *)
procedure InitStack(AStack: pStack);
(* �ͷŶ�ջ *)
procedure FreeStack(AStack: pStack);
(* ȷ����ջ�Ƿ�Ϊ�� *)
function IsStackEmpty(AStack: pStack): Boolean;
(* ���ջ��ѹ������ *)
procedure Push(AStack: pStack; pData: Pointer);
(* �Ӷ�ջ�е������� *)
procedure PopUp(AStack: pStack);
(* ���ջ��Ԫ�� *)
function Peek(AStack: pStack): Pointer;

implementation

procedure InitStack(AStack: pStack);
begin
  InitLinkedList(@AStack.ElmnList);
end;

procedure FreeStack(AStack: pStack);
begin
  FreeLinkedList(@AStack.ElmnList);
end;

function IsStackEmpty(AStack: pStack): Boolean;
begin
  if AStack.ElmnList.iNodeCount > 0 then
    Result := False
  else
    Result := True;
end;

procedure Push(AStack: pStack; pData: Pointer);
begin
  AddNode(@AStack.ElmnList, pData);
end;

procedure PopUp(AStack: pStack);
begin
  DelNode(@AStack.ElmnList, AStack.ElmnList.pTail);
end;

function Peek(AStack: pStack): Pointer;
begin
  Result := AStack.ElmnList.pTail.pData;
end;

end.
