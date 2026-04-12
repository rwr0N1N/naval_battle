' =================================================
' PicoOS - Naval Online v5.8.1 (PicoCalc Edition)
' Hardware: ClockworkPi PicoCalc
' CPU: Raspberry Pi Pico 2W (RP2350)
' Firmware: WebMite v6.02.01
' Logic: Multi-Slot 3D Memory + Iron Wall Clamping
' =================================================

Option Explicit
Option Default Integer
Randomize Timer

' --- CONFIGURAÇÃO DE REDE ---
Const HOST$ = "rwr0n1n.pythonanywhere.com"
Dim matchID = 0, myPlayerID = 0, myTurn = 0
Dim lastPoll = 0, force_redraw = 1, k
Dim msg_status$ = "", serverData$ = ""
Dim netBuff%(4096/8)
Dim netWaiting = 0

' --- WAR ROOM (SLOTS) ---
Dim activeMatches%(5), activePlayers%(5), slotProgress%(5)
Dim currentSlot = 1

' --- CORES & UI (Optimized for PicoCalc Display) ---
Const C_BG      = RGB(10, 15, 25)  : Const C_BAR   = RGB(20, 30, 45)
Const C_GRID    = RGB(40, 80, 120) : Const C_WATER = RGB(15, 35, 60)
Const C_TEXT    = RGB(200, 220, 255): Const C_SEL   = RGB(0, 255, 128)
Const C_HIT     = RGB(255, 50, 50) : Const C_WARN  = RGB(255, 200, 0)
Const C_SHIP    = RGB(150, 150, 160)
Const T_SIZE    = 26 : Const G_X = (320-(10*T_SIZE))\2 : Const G_Y = 32

' --- MAPAS 3D (Layer 1 a 5) ---
Dim p1_board%(5, 9, 9), p1_radar%(5, 9, 9)
Dim fleet%(4) = (5, 4, 3, 3, 2)
Dim gState = 0, view_mode = 0, n_idx = 0
Dim cx = 0, cy = 0, dir = 0, old_cx = -1, old_cy = -1

FRAMEBUFFER Create

' ==================================================
' LOOP PRINCIPAL
' ==================================================
Do
  k = Asc(Inkey$)
  If k = 27 Then
     gState = 0 : netWaiting = 0 : force_redraw = 1
  EndIf
  If k = 86 OR k = 118 Then ' Tecla V (Toggle View)
     view_mode = 1 - view_mode : force_redraw = 1
  EndIf

  Select Case gState
    Case 0 : MainMenu
    Case 1 : ShipPlacement
    Case 2 : TutorialScreen
    Case 3 : Matchmaking
    Case 4 : SyncFleet
    Case 5 : OnlineBattle
  End Select
  CheckNetwork
  Pause 20
Loop

' ==================================================
' 0. MENU PRINCIPAL
' ==================================================
Sub MainMenu
  If force_redraw Then
    FRAMEBUFFER Write F : CLS C_BG
    Text 160, 25, "PICOCALC NAVAL COMMAND", "CM", 1, 1, C_SEL, C_BG
    Text 160, 45, "SELECT ACTIVE SLOT", "CM", 7, 1, C_TEXT, C_BG
    Box 50, 65, 220, 105, 1, C_BAR, C_BAR
    Local i%, txt$
    For i% = 1 To 5
      txt$ = "SLOT " + Str$(i%) + ": "
      If activeMatches%(i%) = 0 Then
         txt$ = txt$ + "[ EMPTY ]"
      Else
         txt$ = txt$ + "MATCH " + Str$(activeMatches%(i%)) + Choice$(slotProgress%(i%)<5, " (SETUP)", " (WAR)")
      EndIf
      Text 60, 72 + (i%*16), txt$, "L", 7, 1, C_TEXT, -1
    Next i%
    Text 160, 190, "PRESS [ENTER] FOR NEW MATCH", "CM", 7, 1, C_WARN, -1
    Text 160, 215, "KEYS [1-5]: RECALL SLOT", "CM", 7, 1, C_TEXT, -1
    FRAMEBUFFER Copy F, N : force_redraw = 0
  EndIf
  If k >= 49 AND k <= 53 Then
     Local s% = k - 48
     If activeMatches%(s%) > 0 Then
        currentSlot = s% : matchID = activeMatches%(s%) : myPlayerID = activePlayers%(s%)
        n_idx = slotProgress%(s%)
        gState = ChoiceI%(n_idx > 4, 5, 1)
        view_mode = ChoiceI%(gState = 5, 1, 0)
        force_redraw = 1
     EndIf
  EndIf
  If k = 13 Then : gState = 3 : netWaiting = 0 : force_redraw = 1 : EndIf
End Sub

' ==================================================
' 3. MATCHMAKING
' ==================================================
Sub Matchmaking
  If netWaiting = 0 Then
     msg_status$ = "CONNECTING..." : DrawAll : SendReq("/join")
  ElseIf netWaiting = 2 Then
     If Instr(serverData$, ",") > 0 Then
        Local i%, found% = 0
        For i% = 1 To 5
          If activeMatches%(i%) = 0 Then : currentSlot = i% : found% = 1 : Exit For : EndIf
        Next i%
        If found% Then
           activeMatches%(currentSlot) = Val(GetParam$(serverData$, 1, ","))
           activePlayers%(currentSlot) = Val(GetParam$(serverData$, 2, ","))
           matchID = activeMatches%(currentSlot) : myPlayerID = activePlayers%(currentSlot)
           slotProgress%(currentSlot) = 0 : n_idx = 0
           ClearSlot(currentSlot)
           gState = 2 : netWaiting = 0 : force_redraw = 1
        Else
           PopupMsg("NO SLOTS AVAILABLE") : gState = 0
        EndIf
     EndIf
  ElseIf netWaiting = 3 Then : PopupMsg("NETWORK ERROR") : gState = 0 : netWaiting = 0 : EndIf
End Sub

' ==================================================
' 1. SHIP PLACEMENT (IRON WALL LOGIC)
' ==================================================
Sub ShipPlacement
  If n_idx > 4 Then : gState = 4 : Exit Sub : EndIf
  Local tam, c, v, pCor, px, py : tam = fleet%(n_idx)
  msg_status$ = "DEPLOYING UNITS..."

  If dir = 0 Then
     If cx + tam > 10 Then cx = 10 - tam
     If cy > 9 Then cy = 9
  Else
     If cy + tam > 10 Then cy = 10 - tam
     If cx > 9 Then cx = 9
  EndIf
  If cx < 0 Then cx = 0
  If cy < 0 Then cy = 0

  If cx<>old_cx Or cy<>old_cy Or force_redraw Then
    DrawAll : FRAMEBUFFER Write F
    v = CheckPlacement%(cx, cy, dir, tam)
    pCor = ChoiceI%(v = 1, C_SEL, RGB(255,0,0))
    For c = 0 To tam - 1
      px = ChoiceI%(dir = 0, cx + c, cx) : py = ChoiceI%(dir = 1, cy + c, cy)
      Box G_X+(px*T_SIZE), G_Y+(py*T_SIZE), T_SIZE, T_SIZE, 3, pCor, -1
    Next c
    FRAMEBUFFER Copy F, N : old_cx = cx : old_cy = cy : force_redraw = 0
  EndIf

  If k <> 0 Then
    Select Case k
      Case 128: If cy > 0 Then cy = cy - 1 : force_redraw = 1 ' UP
      Case 129: ' DOWN
        If dir = 1 Then
           If cy + tam < 10 Then cy = cy + 1 : force_redraw = 1
        Else
           If cy < 9 Then cy = cy + 1 : force_redraw = 1
        EndIf
      Case 130: If cx > 0 Then cx = cx - 1 : force_redraw = 1 ' LEFT
      Case 131: ' RIGHT
        If dir = 0 Then
           If cx + tam < 10 Then cx = cx + 1 : force_redraw = 1
        Else
           If cx < 9 Then cx = cx + 1 : force_redraw = 1
        EndIf
      Case 32: dir = 1 - dir : force_redraw = 1 ' SPACE (Rotate)
      Case 13: ' ENTER
        If CheckPlacement%(cx, cy, dir, tam) Then
          For c = 0 To tam - 1
            px = ChoiceI%(dir = 0, cx + c, cx) : py = ChoiceI%(dir = 1, cy + c, cy)
            p1_board%(currentSlot, px, py) = n_idx + 1
          Next c
          n_idx = n_idx + 1 : slotProgress%(currentSlot) = n_idx : force_redraw = 1
        EndIf
    End Select
  EndIf
End Sub

' ==================================================
' 5. ONLINE BATTLE
' ==================================================
Sub OnlineBattle
  If Timer - lastPoll > 3000 AND netWaiting = 0 Then
    SendReq("/update?id=" + Str$(matchID) + "&p=" + Str$(myPlayerID))
  End If
  If netWaiting = 2 Then
     myTurn = (Val(GetParam$(serverData$, 1, ",")) = myPlayerID)
     netWaiting = 0 : lastPoll = Timer : force_redraw = 1
  End If
  If force_redraw Then
    DrawAll : FRAMEBUFFER Write F
    If myTurn Then : msg_status$ = "YOUR TURN! STRIKE!" : DrawCursor(cx, cy)
    Else : msg_status$ = "ENEMY THINKING..." : EndIf
    FRAMEBUFFER Copy F, N : force_redraw = 0
  End If
  If myTurn AND k = 13 Then
     SendReq("/update?id="+Str$(matchID)+"&p="+Str$(myPlayerID)+"&cmd=shoot&data="+Str$(cx)+","+Str$(cy))
     PopupMsg("STRIKE SENT!") : myTurn = 0 : lastPoll = Timer
  EndIf
  If myTurn AND (k >= 128 AND k <= 131) Then
     If k=128 AND cy>0 Then cy=cy-1 : force_redraw=1
     If k=129 AND cy<9 Then cy=cy+1 : force_redraw=1
     If k=130 AND cx>0 Then cx=cx-1 : force_redraw=1
     If k=131 AND cx<9 Then cx=cx+1 : force_redraw=1
  EndIf
End Sub

' ==================================================
' HELPERS
' ==================================================
Sub DrawAll
  FRAMEBUFFER Write F : CLS C_BG
  Local tit$ = Choice$(view_mode=0, "MY FLEET", "RADAR")
  Box 0, 0, 320, 24, 1, C_BAR, C_BAR
  Text 160, 12, tit$ + " | SLOT " + Str$(currentSlot) + " | ID:" + Str$(matchID), "CM", 7, 1, C_TEXT, -1
  Local r, c, val, pCor
  For r = 0 To 9 : For c = 0 To 9
    val = ChoiceI%(view_mode=0, p1_board%(currentSlot, c, r), p1_radar%(currentSlot, c, r))
    pCor = ChoiceI%(val >= 1, C_SHIP, C_WATER)
    Box G_X+(c*T_SIZE), G_Y+(r*T_SIZE), T_SIZE, T_SIZE, 1, C_GRID, pCor
  Next c : Next r
  Box 0, 320-28, 320, 28, 1, C_BAR, C_BAR
  Text 160, 320-14, msg_status$, "CM", 1, 1, C_TEXT, -1
  FRAMEBUFFER Copy F, N
End Sub

Sub ClearSlot(s%)
  Local r, c : For r=0 To 9 : For c=0 To 9 : p1_board%(s%,c,r)=0 : p1_radar%(s%,c,r)=0 : Next c : Next r
End Sub

Sub PopupMsg(tx$)
  DrawAll : FRAMEBUFFER Write F
  Box 40, 140, 240, 45, 1, C_WARN, C_WARN : Box 43, 143, 234, 39, 1, C_BAR, C_BAR
  Text 160, 162, tx$, "CM", 1, 1, C_TEXT, -1
  FRAMEBUFFER Copy F, N : Pause 1800 : force_redraw = 1
End Sub

Sub SendReq(path$)
  Local q$ : q$ = "GET "+path$+" HTTP/1.1"+Chr$(13)+Chr$(10)+"Host: "+HOST$+Chr$(13)+Chr$(10)+"Connection: close"+Chr$(13)+Chr$(10)+Chr$(13)+Chr$(10)
  On Error Skip 5 : WEB OPEN TCP CLIENT HOST$, 80 : WEB TCP CLIENT REQUEST q$, netBuff%(), 800 : netWaiting = 1
End Sub

Sub CheckNetwork
  If netWaiting = 1 Then
     Local raw$ = LGetStr$(netBuff%(), 1, 15)
     If raw$ <> "" Then
        If Instr(raw$, "200") > 0 Then
           Local p% = LINSTR(netBuff%(), Chr$(13)+Chr$(10)+Chr$(13)+Chr$(10))
           If p% > 0 Then : serverData$ = LGetStr$(netBuff%(), p% + 4, 255) : netWaiting = 2 : EndIf
        Else : netWaiting = 3 : EndIf
        WEB CLOSE TCP CLIENT
     EndIf
  EndIf
End Sub

Function CheckPlacement%(x, y, d, t)
  Local c, px, py : CheckPlacement% = 1
  For c = 0 To t - 1
    px = ChoiceI%(d = 0, x + c, x) : py = ChoiceI%(d = 1, y + c, y)
    If px<0 Or px>9 Or py<0 Or py>9 Then : CheckPlacement%=0 : Exit Function : EndIf
    If p1_board%(currentSlot, px, py) <> 0 Then : CheckPlacement% = 0 : Exit Function : EndIf
  Next c
End Function

Sub TutorialScreen
  FRAMEBUFFER Write F : CLS C_BG
  Text 160, 40, "MISSION BRIEFING", "CM", 1, 1, C_SEL, -1
  Text 160, 80, "- MOVE WITH ARROWS", "CM", 7, 1, C_TEXT, -1
  Text 160, 100, "- [SPACE] TO ROTATE", "CM", 7, 1, C_TEXT, -1
  Text 160, 120, "- [V] TO TOGGLE RADAR/FLEET", "CM", 7, 1, C_TEXT, -1
  Text 160, 200, "PRESS [ENTER] TO CONTINUE", "CM", 1, 1, C_WARN, -1
  FRAMEBUFFER Copy F, N
  If k = 13 Then : gState = 1 : force_redraw = 1 : EndIf
End Sub

Sub SyncFleet
  If netWaiting = 0 Then
     msg_status$ = "SYNCING SLOT..." : DrawAll
     Local s$ = "", r, c
     For r = 0 To 9 : For c = 0 To 9 : s$ = s$ + Str$(p1_board%(currentSlot, c, r)) : Next c : Next r
     SendReq("/update?id="+Str$(matchID)+"&p="+Str$(myPlayerID)+"&cmd=layout&data="+s$)
  ElseIf netWaiting = 2 Then
     If Instr(serverData$, "OK") > 0 Then : gState = 5 : Else : gState = 0 : EndIf
     netWaiting = 0 : force_redraw = 1
  EndIf
End Sub

Sub DrawCursor(x, y) : Box G_X+(x*T_SIZE), G_Y+(y*T_SIZE), T_SIZE, T_SIZE, 3, C_WARN, -1 : End Sub
Function GetParam$(s$, n, d$)
  Local i, p, q : p = 1 : For i = 1 To n - 1
    p = Instr(p, s$, d$) : If p = 0 Then : GetParam$ = "" : Exit Function : EndIf
    p = p + Len(d$) : Next i
  q = Instr(p, s$, d$) : If q = 0 Then : GetParam$ = Mid$(s$, p) : Else : GetParam$ = Mid$(s$, p, q - p) : EndIf
End Function
Function Choice$(cond, s1$, s2$) : If cond <> 0 Then : Choice$ = s1$ : Else : Choice$ = s2$ : EndIf : End Function
Function ChoiceI%(cond, c1, c2) : If cond <> 0 Then : ChoiceI% = c1 : Else : ChoiceI% = c2 : EndIf : End Function
