' =================================================
' PicoOS - Naval Online v9.1 (PicoCalc Edition)
' Hardware: ClockworkPi PicoCalc (RP2350)
' WebMite 6.02.01
'
' CHAT: [C] abre popup, escreve (max 28 chars),
'       [ENTER] envia, [ESC] cancela/fecha
' =================================================

Option Explicit
Option Default Integer
Randomize Timer

' --- REDE ---
Const HOST$ = "rwr0n1n.pythonanywhere.com"
Dim netBuff%(512\8)
Dim netWaiting      ' 0=idle 1=aguarda 2=dados 3=erro
Dim serverData$
Dim chatPending     ' 1=pedido de rede em curso é de chat

' --- ESTADO GLOBAL ---
Dim k
Dim gState
Dim force_redraw
Dim msg_status$
Dim lastPoll
Dim lastChatPoll
Dim currentSlot

' --- CHAT ---
Const CHAT_MAX  = 28
Dim chatInput$      ' texto que o jogador está a escrever
Dim chatPopup       ' 0=fechado 1=a escrever 2=msg recebida
Dim chatMsg$        ' mensagem recebida a mostrar

' --- ESTADO POR SLOT ---
Dim activeMatches%(5)
Dim activePlayers%(5)
Dim slotProgress%(5)
Dim slotTurn%(5)
Dim slotStrike%(5)
Dim slotMyHits%(5)
Dim slotEnemyHits%(5)

' --- ATALHOS SLOT ACTIVO ---
Dim myPlayerID
Dim matchID
Dim myTurn
Dim firstStrike
Dim myHits
Dim enemyHits

' --- CORES & UI ---
Const C_BG    = RGB(10,15,25)
Const C_BAR   = RGB(20,30,45)
Const C_GRID  = RGB(40,80,120)
Const C_WATER = RGB(15,35,60)
Const C_TEXT  = RGB(200,220,255)
Const C_SEL   = RGB(0,255,128)
Const C_HIT   = RGB(255,50,50)
Const C_WARN  = RGB(255,200,0)
Const C_SHIP  = RGB(150,150,160)
Const C_CHAT  = RGB(30,50,80)
Const T_SIZE  = 26
Const G_X     = (320-(10*T_SIZE))\2
Const G_Y     = 32

' --- MAPAS ---
Dim p1_board%(5,9,9)
Dim p1_radar%(5,9,9)
Dim fleet%(4)

' --- COLOCAÇÃO ---
Dim view_mode
Dim n_idx
Dim cx
Dim cy
Dim dir
Dim old_cx
Dim old_cy

Const SHIP_TOTAL = 17

' =================================================
' INICIALIZAÇÃO
' =================================================
FRAMEBUFFER Create

fleet%(0) = 5 : fleet%(1) = 4 : fleet%(2) = 3
fleet%(3) = 3 : fleet%(4) = 2

gState       = 0  : view_mode   = 0
n_idx        = 0  : cx          = 0
cy           = 0  : dir         = 0
old_cx       = -1 : old_cy      = -1
currentSlot  = 1  : force_redraw = 1
netWaiting   = 0  : lastPoll    = 0
lastChatPoll = 0  : chatPending = 0
chatPopup    = 0  : chatInput$  = ""
chatMsg$     = "" : msg_status$ = ""
serverData$  = ""
myPlayerID   = 0  : matchID     = 0
myTurn       = 0  : firstStrike = 0
myHits       = 0  : enemyHits   = 0

' =================================================
' LOOP PRINCIPAL
' =================================================
Do
  k = Asc(Inkey$)

  ' --- Popup de chat aberto: trata input de texto ---
  If chatPopup = 1 Then
    ChatInput
  ElseIf chatPopup = 2 Then
    ' Msg recebida visível: ESC fecha
    If k = 27 Then
      chatPopup    = 0
      chatMsg$     = ""
      force_redraw = 1
    EndIf
  Else
    ' --- Input normal de jogo ---
    If k = 27 Then
      SaveSlot(currentSlot)
      gState = 0 : netWaiting = 0 : force_redraw = 1
    EndIf
    If (k = 86 Or k = 118) And gState = 5 Then
      view_mode = 1 - view_mode : force_redraw = 1
    EndIf
    ' C abre chat durante batalha
    If (k = 67 Or k = 99) And gState = 5 Then
      chatInput$   = ""
      chatPopup    = 1
      force_redraw = 1
    EndIf

    Select Case gState
      Case 0 : MainMenu
      Case 1 : ShipPlacement
      Case 2 : TutorialScreen
      Case 3 : Matchmaking
      Case 4 : SyncFleet
      Case 5 : OnlineBattle
      Case 7 : WaitReady
    End Select
  EndIf

  CheckNetwork
  Pause 20
Loop

END

' =================================================
' FUNÇÕES DE UTILIDADE
' =================================================

Function Choice$(cond_s, s1_s$, s2_s$)
  If cond_s <> 0 Then
    Choice$ = s1_s$
  Else
    Choice$ = s2_s$
  EndIf
End Function

Function ChoiceI%(cond_i, c1_i, c2_i)
  If cond_i <> 0 Then
    ChoiceI% = c1_i
  Else
    ChoiceI% = c2_i
  EndIf
End Function

Function GetParam$(s_in$, n_p, d_sep$)
  Local ip_p, pp_p, qp_p
  pp_p = 1
  GetParam$ = ""
  If s_in$ = "" Then Exit Function
  For ip_p = 1 To n_p - 1
    pp_p = Instr(pp_p, s_in$, d_sep$)
    If pp_p = 0 Then Exit Function
    pp_p = pp_p + Len(d_sep$)
  Next ip_p
  qp_p = Instr(pp_p, s_in$, d_sep$)
  If qp_p = 0 Then
    GetParam$ = Mid$(s_in$, pp_p)
  Else
    GetParam$ = Mid$(s_in$, pp_p, qp_p - pp_p)
  EndIf
End Function

' =================================================
' SUB LoadSlot / SaveSlot
' =================================================
Sub LoadSlot(s)
  myPlayerID  = activePlayers%(s)
  matchID     = activeMatches%(s)
  myTurn      = slotTurn%(s)
  firstStrike = slotStrike%(s)
  myHits      = slotMyHits%(s)
  enemyHits   = slotEnemyHits%(s)
End Sub

Sub SaveSlot(s)
  slotTurn%(s)      = myTurn
  slotStrike%(s)    = firstStrike
  slotMyHits%(s)    = myHits
  slotEnemyHits%(s) = enemyHits
End Sub

' =================================================
' SUB ChatInput  - trata teclado dentro da popup de escrita
' =================================================
Sub ChatInput
  Local kc
  kc = k

  ' ESC cancela
  If kc = 27 Then
    chatPopup    = 0
    chatInput$   = ""
    force_redraw = 1
    Exit Sub
  EndIf

  ' ENTER envia se tiver texto
  If kc = 13 Then
    If Len(chatInput$) > 0 Then
      SendChat(chatInput$)
      chatInput$   = ""
      chatPopup    = 0
      force_redraw = 1
    EndIf
    Exit Sub
  EndIf

  ' Backspace
  If kc = 8 Or kc = 127 Then
    If Len(chatInput$) > 0 Then
      chatInput$ = Left$(chatInput$, Len(chatInput$) - 1)
    EndIf
    force_redraw = 1
    Exit Sub
  EndIf

  ' Caracteres imprimíveis (32-126)
  If kc >= 32 And kc <= 126 Then
    If Len(chatInput$) < CHAT_MAX Then
      chatInput$ = chatInput$ + Chr$(kc)
      force_redraw = 1
    EndIf
  EndIf

  ' Desenha popup de input
  DrawChatInputPopup
End Sub

' =================================================
' SUB DrawChatInputPopup
' =================================================
Sub DrawChatInputPopup
  Local bx, by, bw, bh
  bx = 20 : by = 155 : bw = 280 : bh = 60
  FRAMEBUFFER Write F
  ' Caixa com borda
  Box bx, by, bw, bh, 1, C_SEL, C_CHAT
  Box bx+2, by+2, bw-4, bh-4, 1, C_CHAT, C_CHAT
  Text 160, by+8,  "SEND MESSAGE [ENTER=OK  ESC=CANCEL]", "CM", 1, 1, C_SEL,  C_CHAT
  Text 160, by+26, chatInput$ + "_",                      "CM", 1, 1, C_TEXT, C_CHAT
  Text 160, by+42, Str$(CHAT_MAX - Len(chatInput$)) + " chars left", "CM", 1, 1, C_WARN, C_CHAT
  FRAMEBUFFER Copy F, N
End Sub

' =================================================
' SUB DrawChatReceivedPopup
' =================================================
Sub DrawChatReceivedPopup
  Local bx, by, bw, bh
  bx = 20 : by = 155 : bw = 280 : bh = 60
  FRAMEBUFFER Write F
  Box bx, by, bw, bh, 1, C_WARN, C_CHAT
  Box bx+2, by+2, bw-4, bh-4, 1, C_CHAT, C_CHAT
  Text 160, by+8,  "MESSAGE FROM ENEMY:",  "CM", 1, 1, C_WARN, C_CHAT
  Text 160, by+26, chatMsg$,               "CM", 1, 1, C_TEXT, C_CHAT
  Text 160, by+44, "[ESC] TO DISMISS",     "CM", 1, 1, C_SEL,  C_CHAT
  FRAMEBUFFER Copy F, N
End Sub

' =================================================
' SUB SendChat  - envia mensagem pelo servidor
' =================================================
Sub SendChat(msg$)
  ' URL-encode básico: substitui espaços por +
  Local enc$, i, ch
  enc$ = ""
  For i = 1 To Len(msg$)
    ch = Asc(Mid$(msg$, i, 1))
    If ch = 32 Then
      enc$ = enc$ + "+"
    Else
      enc$ = enc$ + Chr$(ch)
    EndIf
  Next i
  chatPending = 0   ' chat_send não precisa de ler resposta com prioridade
  SendReq("/update?id=" + Str$(matchID) + "&p=" + Str$(myPlayerID) + "&cmd=chat_send&data=" + enc$)
End Sub

' =================================================
' SUB PollChat  - verifica se há mensagem do adversário
' Chamado apenas quando netWaiting=0
' =================================================
Sub PollChat
  If gState <> 5 Then Exit Sub                  ' só durante batalha
  If chatPopup <> 0 Then Exit Sub               ' não interrompe chat aberto
  If Timer - lastChatPoll < 5000 Then Exit Sub  ' a cada 5 segundos
  lastChatPoll = Timer
  chatPending  = 1
  SendReq("/update?id=" + Str$(matchID) + "&p=" + Str$(myPlayerID) + "&cmd=chat_get")
End Sub

' =================================================
' SUB MainMenu
' =================================================
Sub MainMenu
  If force_redraw Then
    FRAMEBUFFER Write F : CLS C_BG
    Text 160, 25, "PICOCALC NAVAL COMMAND", "CM", 1, 1, C_SEL, C_BG
    Text 160, 45, "SELECT ACTIVE SLOT",     "CM", 7, 1, C_TEXT, C_BG
    Box 50, 65, 220, 105, 1, C_BAR, C_BAR
    Local i_m, txt_m$
    For i_m = 1 To 5
      txt_m$ = "SLOT " + Str$(i_m) + ": "
      If activeMatches%(i_m) = 0 Then
        txt_m$ = txt_m$ + "[ EMPTY ]"
      Else
        txt_m$ = txt_m$ + "M" + Str$(activeMatches%(i_m)) + " P" + Str$(activePlayers%(i_m)) + Choice$(slotProgress%(i_m) < 5, " SETUP", " WAR")
      EndIf
      Text 60, 72+(i_m*16), txt_m$, "L", 7, 1, C_TEXT, C_BAR
    Next i_m
    Text 160, 190, "[ENTER]=NEW  [1-5]=RECALL", "CM", 7, 1, C_WARN, C_BG
    FRAMEBUFFER Copy F, N
    force_redraw = 0
  EndIf

  If k >= 49 And k <= 53 Then
    Local s_idx
    s_idx = k - 48
    If activeMatches%(s_idx) > 0 Then
      currentSlot  = s_idx
      LoadSlot(currentSlot)
      n_idx        = slotProgress%(currentSlot)
      lastPoll     = 0
      If n_idx > 4 Then
        view_mode  = ChoiceI%(myTurn, 1, 0)
        gState     = 5
      Else
        view_mode  = 0
        gState     = 1
      EndIf
      chatPopup    = 0
      force_redraw = 1
    EndIf
  EndIf

  If k = 13 Then
    gState = 3 : netWaiting = 0 : force_redraw = 1
  EndIf
End Sub

' =================================================
' SUB Matchmaking
' =================================================
Sub Matchmaking
  If netWaiting = 0 Then
    msg_status$ = "CONNECTING TO SERVER..."
    DrawStatus
    SendReq("/join")

  ElseIf netWaiting = 2 Then
    Local m_val$, p_val$
    m_val$ = GetParam$(serverData$, 1, ",")
    p_val$ = GetParam$(serverData$, 2, ",")
    If m_val$ = "" Or p_val$ = "" Then
      PopupMsg("SERVER ERROR")
      gState = 0 : netWaiting = 0
      Exit Sub
    EndIf
    Local im, found_s
    found_s = 0
    For im = 1 To 5
      If activeMatches%(im) = 0 Then
        currentSlot = im : found_s = 1 : Exit For
      EndIf
    Next im
    If Not found_s Then
      PopupMsg("NO SLOTS AVAILABLE")
      gState = 0 : netWaiting = 0
      Exit Sub
    EndIf
    activeMatches%(currentSlot)  = Val(m_val$)
    activePlayers%(currentSlot)  = Val(p_val$)
    slotProgress%(currentSlot)   = 0
    slotTurn%(currentSlot)       = 0
    slotStrike%(currentSlot)     = 0
    slotMyHits%(currentSlot)     = 0
    slotEnemyHits%(currentSlot)  = 0
    ClearSlot(currentSlot)
    LoadSlot(currentSlot)
    n_idx        = 0
    netWaiting   = 0
    chatPopup    = 0
    force_redraw = 1
    gState       = 2

  ElseIf netWaiting = 3 Then
    PopupMsg("NETWORK ERROR")
    gState = 0 : netWaiting = 0
  EndIf
End Sub

' =================================================
' SUB TutorialScreen
' =================================================
Sub TutorialScreen
  FRAMEBUFFER Write F : CLS C_BG
  Text 160, 35,  "MISSION BRIEFING",        "CM", 1, 1, C_SEL,  C_BG
  Text 160, 75,  "DEPLOY YOUR FLEET FIRST", "CM", 7, 1, C_WARN, C_BG
  Text 160, 100, "ARROWS  = MOVE",          "CM", 7, 1, C_TEXT, C_BG
  Text 160, 118, "SPACE   = ROTATE SHIP",   "CM", 7, 1, C_TEXT, C_BG
  Text 160, 136, "ENTER   = PLACE SHIP",    "CM", 7, 1, C_TEXT, C_BG
  Text 160, 154, "V       = TOGGLE VIEW",   "CM", 7, 1, C_TEXT, C_BG
  Text 160, 172, "C       = OPEN CHAT",     "CM", 7, 1, C_SEL,  C_BG
  Text 160, 190, "ESC     = BACK TO MENU",  "CM", 7, 1, C_TEXT, C_BG
  Text 160, 220, "PLAYER 2 FIRES FIRST",    "CM", 1, 1, C_HIT,  C_BG
  Text 160, 240, "PRESS [ENTER] TO DEPLOY", "CM", 1, 1, C_WARN, C_BG
  FRAMEBUFFER Copy F, N
  If k = 13 Then
    cx = 0 : cy = 0 : dir = 0
    old_cx = -1 : old_cy = -1
    gState = 1 : force_redraw = 1
  EndIf
End Sub

' =================================================
' SUB ShipPlacement
' =================================================
Sub ShipPlacement
  If n_idx > 4 Then gState = 4 : Exit Sub : EndIf

  Local tam_s
  tam_s = fleet%(n_idx)
  msg_status$ = "SHIP " + Str$(n_idx+1) + "/5 SIZE:" + Str$(tam_s) + " [SPC]=ROT [ENT]=PLACE"

  If dir = 0 Then
    If cx + tam_s > 10 Then cx = 10 - tam_s
    If cy > 9 Then cy = 9
  Else
    If cy + tam_s > 10 Then cy = 10 - tam_s
    If cx > 9 Then cx = 9
  EndIf
  If cx < 0 Then cx = 0
  If cy < 0 Then cy = 0

  If cx <> old_cx Or cy <> old_cy Or force_redraw Then
    DrawAll
    FRAMEBUFFER Write F
    Local v_place, pCor_p, c_p, px_p, py_p
    v_place = CheckPlacement%(cx, cy, dir, tam_s)
    pCor_p  = ChoiceI%(v_place, C_SEL, RGB(255,0,0))
    For c_p = 0 To tam_s - 1
      px_p = ChoiceI%(dir = 0, cx+c_p, cx)
      py_p = ChoiceI%(dir = 1, cy+c_p, cy)
      Box G_X+(px_p*T_SIZE), G_Y+(py_p*T_SIZE), T_SIZE, T_SIZE, 3, pCor_p
    Next c_p
    FRAMEBUFFER Copy F, N
    old_cx = cx : old_cy = cy : force_redraw = 0
  EndIf

  If k = 0 Then Exit Sub

  Select Case k
    Case 128 : If cy > 0 Then cy = cy-1 : force_redraw = 1
    Case 129
      If dir = 1 Then
        If cy+tam_s < 10 Then cy = cy+1 : force_redraw = 1
      Else
        If cy < 9 Then cy = cy+1 : force_redraw = 1
      EndIf
    Case 130 : If cx > 0 Then cx = cx-1 : force_redraw = 1
    Case 131
      If dir = 0 Then
        If cx+tam_s < 10 Then cx = cx+1 : force_redraw = 1
      Else
        If cx < 9 Then cx = cx+1 : force_redraw = 1
      EndIf
    Case 32  : dir = 1-dir : force_redraw = 1
    Case 13
      If CheckPlacement%(cx, cy, dir, tam_s) Then
        Local cp_p, pp_p, yp_p
        For cp_p = 0 To tam_s-1
          pp_p = ChoiceI%(dir=0, cx+cp_p, cx)
          yp_p = ChoiceI%(dir=1, cy+cp_p, cy)
          p1_board%(currentSlot, pp_p, yp_p) = n_idx+1
        Next cp_p
        n_idx = n_idx+1
        slotProgress%(currentSlot) = n_idx
        force_redraw = 1
      EndIf
  End Select
End Sub

' =================================================
' SUB SyncFleet
' =================================================
Sub SyncFleet
  If netWaiting = 0 Then
    msg_status$ = "UPLOADING FLEET..."
    DrawStatus
    Local sy_s$, rs_s, cs_s
    sy_s$ = ""
    For rs_s = 0 To 9
      For cs_s = 0 To 9
        sy_s$ = sy_s$ + Str$(p1_board%(currentSlot, cs_s, rs_s))
      Next cs_s
    Next rs_s
    SendReq("/update?id=" + Str$(matchID) + "&p=" + Str$(myPlayerID) + "&cmd=layout&data=" + sy_s$)

  ElseIf netWaiting = 2 Then
    If Instr(serverData$, "OK") Then
      netWaiting = 0 : lastPoll = 0 : gState = 7 : force_redraw = 1
    Else
      PopupMsg("UPLOAD FAILED") : netWaiting = 0
    EndIf

  ElseIf netWaiting = 3 Then
    PopupMsg("NETWORK ERROR") : netWaiting = 0
  EndIf
End Sub

' =================================================
' SUB WaitReady
' =================================================
Sub WaitReady
  msg_status$ = "WAITING FOR OPPONENT FLEET..."
  DrawStatus

  If netWaiting = 0 Then
    If Timer - lastPoll > 3000 Then
      SendReq("/update?id=" + Str$(matchID) + "&p=" + Str$(myPlayerID) + "&cmd=check_ready")
      lastPoll = Timer
    EndIf

  ElseIf netWaiting = 2 Then
    If Instr(serverData$, "READY") Then
      myTurn       = ChoiceI%(myPlayerID = 2, 1, 0)
      firstStrike  = 0
      view_mode    = ChoiceI%(myTurn, 1, 0)
      SaveSlot(currentSlot)
      lastPoll     = 0
      lastChatPoll = 0
      gState       = 5
      force_redraw = 1
    EndIf
    netWaiting = 0

  ElseIf netWaiting = 3 Then
    netWaiting = 0
  EndIf
End Sub

' =================================================
' SUB OnlineBattle
' =================================================
Sub OnlineBattle
  ' Polling de jogo
  If netWaiting = 0 And Timer - lastPoll > 3000 Then
    If myTurn = 0 And firstStrike = 0 Then
      SendReq("/update?id=" + Str$(matchID) + "&p=" + Str$(myPlayerID) + "&cmd=get_shot")
      lastPoll = Timer
    ElseIf myTurn = 0 And firstStrike = 1 Then
      SendReq("/update?id=" + Str$(matchID) + "&p=" + Str$(myPlayerID) + "&cmd=check_result")
      lastPoll = Timer
    EndIf
  EndIf

  ' Polling de chat (só quando rede livre)
  If netWaiting = 0 Then PollChat

  ' Processa resposta de rede
  If netWaiting = 2 Then
    If chatPending Then
      ' É resposta de chat
      chatPending = 0
      If Not Instr(serverData$, "NONE") And serverData$ <> "" Then
        chatMsg$     = serverData$
        chatPopup    = 2
        force_redraw = 1
        DrawAll
        DrawChatReceivedPopup
      EndIf
    Else
      ' É resposta de jogo
      If serverData$ = "" Or Instr(serverData$, "NONE") Or Instr(serverData$, "WAITING") Then
        ' Nada a fazer
      ElseIf Instr(serverData$, ",") And myTurn = 0 And firstStrike = 0 Then
        ProcessIncomingShot(serverData$)
      ElseIf Instr(serverData$, "HIT") Or Instr(serverData$, "MISS") Then
        ProcessShotResult(serverData$)
      EndIf
    EndIf
    netWaiting   = 0
    chatPending  = 0
    force_redraw = 1
  EndIf

  If netWaiting = 3 Then netWaiting = 0 : chatPending = 0 : EndIf

  ' Desenha (se popup de msg recebida está aberta, não redesenha por baixo)
  If chatPopup = 2 Then Exit Sub

  If force_redraw Then
    DrawAll
    FRAMEBUFFER Write F
    If myTurn Then
      msg_status$ = "YOUR TURN - [ARROWS]AIM [ENTER]FIRE [C]CHAT"
      DrawCursor(cx, cy)
    ElseIf firstStrike Then
      msg_status$ = "AWAITING RESULT... [C]=CHAT"
    Else
      msg_status$ = "ENEMY THINKING... [C]=CHAT"
    EndIf
    FRAMEBUFFER Copy F, N
    force_redraw = 0
  EndIf

  ' Input de jogo (só quando não há popup de chat)
  If chatPopup <> 0 Then Exit Sub
  If myTurn = 0 Then Exit Sub

  If k = 128 And cy > 0 Then cy = cy-1 : force_redraw = 1 : EndIf
  If k = 129 And cy < 9 Then cy = cy+1 : force_redraw = 1 : EndIf
  If k = 130 And cx > 0 Then cx = cx-1 : force_redraw = 1 : EndIf
  If k = 131 And cx < 9 Then cx = cx+1 : force_redraw = 1 : EndIf

  If k = 13 Then
    If p1_radar%(currentSlot, cx, cy) <> 0 Then
      PopupMsg("ALREADY FIRED HERE!")
      Exit Sub
    EndIf
    SendReq("/update?id=" + Str$(matchID) + "&p=" + Str$(myPlayerID) + "&cmd=shoot&data=" + Str$(cx) + "," + Str$(cy))
    PopupMsg("STRIKE AT " + Str$(cx) + "," + Str$(cy) + "!")
    myTurn       = 0
    firstStrike  = 1
    SaveSlot(currentSlot)
    lastPoll     = Timer
    force_redraw = 1
  EndIf
End Sub

' =================================================
' SUB ProcessIncomingShot
' =================================================
Sub ProcessIncomingShot(d_shot$)
  Local sx_i, sy_i, res_i$
  sx_i   = Val(GetParam$(d_shot$, 1, ","))
  sy_i   = Val(GetParam$(d_shot$, 2, ","))
  res_i$ = "MISS"
  If p1_board%(currentSlot, sx_i, sy_i) > 0 And p1_board%(currentSlot, sx_i, sy_i) < 9 Then
    res_i$ = "HIT"
    p1_board%(currentSlot, sx_i, sy_i) = 9
    enemyHits = enemyHits + 1
  EndIf
  SendReq("/update?id=" + Str$(matchID) + "&p=" + Str$(myPlayerID) + "&cmd=send_result&data=" + res_i$)
  PopupMsg("INCOMING: " + res_i$ + " AT " + Str$(sx_i) + "," + Str$(sy_i))
  If enemyHits >= SHIP_TOTAL Then
    PopupMsg("ALL SHIPS SUNK - YOU LOSE!")
    SendReq("/update?id=" + Str$(matchID) + "&p=" + Str$(myPlayerID) + "&cmd=archive")
    activeMatches%(currentSlot) = 0 : slotProgress%(currentSlot) = 0
    gState = 0 : netWaiting = 0 : force_redraw = 1
    Exit Sub
  EndIf
  myTurn = 1 : firstStrike = 0 : view_mode = 1
  SaveSlot(currentSlot) : force_redraw = 1
End Sub

' =================================================
' SUB ProcessShotResult
' =================================================
Sub ProcessShotResult(r_res$)
  If Instr(r_res$, "HIT") Then
    p1_radar%(currentSlot, cx, cy) = 9
    myHits = myHits + 1
    PopupMsg("DIRECT HIT!")
  Else
    p1_radar%(currentSlot, cx, cy) = 1
    PopupMsg("MISS!")
  EndIf
  If myHits >= SHIP_TOTAL Then
    PopupMsg("ALL ENEMY SHIPS SUNK - VICTORY!")
    SendReq("/update?id=" + Str$(matchID) + "&p=" + Str$(myPlayerID) + "&cmd=archive")
    activeMatches%(currentSlot) = 0 : slotProgress%(currentSlot) = 0
    gState = 0 : netWaiting = 0 : force_redraw = 1
    Exit Sub
  EndIf
  myTurn = 0 : firstStrike = 0 : view_mode = 0
  SaveSlot(currentSlot) : force_redraw = 1
End Sub

' =================================================
' SUB DrawAll
' =================================================
Sub DrawAll
  FRAMEBUFFER Write F : CLS C_BG
  Local tit_a$
  tit_a$ = Choice$(view_mode=0, "MY FLEET", "RADAR")
  Box 0, 0, 320, 24, 1, C_BAR, C_BAR
  Text 160, 12, tit_a$ + " | SLOT " + Str$(currentSlot) + " | ID:" + Str$(matchID) + " | P" + Str$(myPlayerID), "CM", 7, 1, C_TEXT, C_BAR
  Local rd_a, cd_a, vd_a, pd_a
  For rd_a = 0 To 9
    For cd_a = 0 To 9
      vd_a = ChoiceI%(view_mode=0, p1_board%(currentSlot,cd_a,rd_a), p1_radar%(currentSlot,cd_a,rd_a))
      pd_a = ChoiceI%(vd_a=9, C_HIT, ChoiceI%(vd_a>=1, C_SHIP, C_WATER))
      Box G_X+(cd_a*T_SIZE), G_Y+(rd_a*T_SIZE), T_SIZE, T_SIZE, 1, C_GRID, pd_a
    Next cd_a
  Next rd_a
  Box 0, 320-28, 320, 28, 1, C_BAR, C_BAR
  Text 160, 320-14, msg_status$, "CM", 1, 1, C_TEXT, C_BAR
  FRAMEBUFFER Copy F, N
End Sub

' =================================================
' SUB DrawStatus
' =================================================
Sub DrawStatus
  FRAMEBUFFER Write F : CLS C_BG
  Text 160, 130, msg_status$,     "CM", 1, 1, C_WARN, C_BG
  Text 160, 155, "PLEASE WAIT...", "CM", 7, 1, C_TEXT, C_BG
  Text 160, 200, "ESC = BACK TO MENU", "CM", 7, 1, C_TEXT, C_BG
  FRAMEBUFFER Copy F, N
End Sub

' =================================================
' SUB DrawCursor
' =================================================
Sub DrawCursor(x_cur, y_cur)
  Box G_X+(x_cur*T_SIZE), G_Y+(y_cur*T_SIZE), T_SIZE, T_SIZE, 3, C_WARN
End Sub

' =================================================
' SUB ClearSlot
' =================================================
Sub ClearSlot(s_c)
  Local rc_c, cc_c
  For rc_c = 0 To 9
    For cc_c = 0 To 9
      p1_board%(s_c, cc_c, rc_c) = 0
      p1_radar%(s_c, cc_c, rc_c) = 0
    Next cc_c
  Next rc_c
End Sub

' =================================================
' SUB PopupMsg
' =================================================
Sub PopupMsg(tx_p$)
  DrawAll
  FRAMEBUFFER Write F
  Box  40, 140, 240, 45, 1, C_WARN, C_WARN
  Box  43, 143, 234, 39, 1, C_BAR,  C_BAR
  Text 160, 162, tx_p$, "CM", 1, 1, C_TEXT, C_BAR
  FRAMEBUFFER Copy F, N
  Pause 1800
  force_redraw = 1
End Sub

' =================================================
' SUB SendReq
' =================================================
Sub SendReq(path_r$)
  Local q_req$
  q_req$ = "GET " + path_r$ + " HTTP/1.1" + Chr$(13) + Chr$(10) + "Host: " + HOST$ + Chr$(13) + Chr$(10) + "Connection: close" + Chr$(13) + Chr$(10) + Chr$(13) + Chr$(10)
  On Error Skip 5
  WEB Open TCP Client HOST$, 80
  WEB TCP Client Request q_req$, netBuff%(), 512
  netWaiting = 1
End Sub

' =================================================
' SUB CheckNetwork
' =================================================
Sub CheckNetwork
  If netWaiting <> 1 Then Exit Sub
  Local r_raw$
  r_raw$ = LGetStr$(netBuff%(), 1, 15)
  If r_raw$ = "" Then Exit Sub
  Local p_net
  p_net = LInStr(netBuff%(), Chr$(13) + Chr$(10) + Chr$(13) + Chr$(10))
  If p_net > 0 Then
    serverData$ = LGetStr$(netBuff%(), p_net+4, 255)
    netWaiting  = 2
    WEB Close TCP Client
  EndIf
End Sub

' =================================================
' FUNCTION CheckPlacement%
' =================================================
Function CheckPlacement%(x_c, y_c, d_c, t_c)
  Local ck_p, xc_p, yc_p
  CheckPlacement% = 1
  For ck_p = 0 To t_c-1
    xc_p = ChoiceI%(d_c=0, x_c+ck_p, x_c)
    yc_p = ChoiceI%(d_c=1, y_c+ck_p, y_c)
    If xc_p<0 Or xc_p>9 Or yc_p<0 Or yc_p>9 Then
      CheckPlacement% = 0 : Exit Function
    EndIf
    If p1_board%(currentSlot, xc_p, yc_p) <> 0 Then
      CheckPlacement% = 0 : Exit Function
    EndIf
  Next ck_p
End Function
