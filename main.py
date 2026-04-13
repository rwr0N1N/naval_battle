from flask import Flask, request, render_template_string
import time

app = Flask(__name__)

games = {}
waiting_queue = []
hall_of_fame = []

# --- PAINEL WEB ---
@app.route('/')
def index():
    now = time.time()
    html = """
    <!DOCTYPE html><html>
    <head><title>Pico Naval: War Room</title>
    <meta http-equiv="refresh" content="10">
    <style>
      body{background:#050a10;color:#00ffcc;font-family:'Courier New',monospace;padding:20px}
      .card{border:1px solid #1a3a3a;background:#0a1420;padding:15px;margin:10px 0;border-radius:5px}
      .btn-del{color:#ff5555;text-decoration:none;border:1px solid #ff5555;padding:2px 5px;font-size:.8em}
      .grid{display:grid;grid-template-columns:1fr 1fr;gap:20px}
      h1{border-bottom:2px solid #00ffcc;padding-bottom:10px}
    </style></head>
    <body>
    <h1>⚓ PICO NAVAL COMMAND CENTER</h1>
    <div class="grid"><div>
      <h3>ESTADO</h3>
      <p>Fila: <strong>{{ w_len }}</strong> | Batalhas: <strong>{{ g_len }}</strong></p>
      <h3>BATALHAS</h3>
      {% for id, d in games_list.items() %}
      <div class="card">
        <strong>ID:{{ id }}</strong> | Turno: P{{ d.turn }}<br>
        P1: {{ "✅"|safe if d.p1_l else "⏳"|safe }} |
        P2: {{ "✅"|safe if d.p2_l else "⏳"|safe }} |
        Shot: {{ d.pending_shot }} | Status: {{ d.shot_status }}<br>
        Chat: {{ d.chat_msg if d.chat_msg else "—" }}<br>
        {{ (now-d.last_act)|int }}s atrás &nbsp;
        <a href="/admin/delete/{{ id }}" class="btn-del">APAGAR</a>
      </div>
      {% endfor %}
    </div><div>
      <h3>🏆 VITÓRIAS</h3>
      <ul>{% for w in hof %}<li>{{ w }}</li>{% else %}<li style="color:#555">—</li>{% endfor %}</ul>
      <hr>
      <form action="/admin/clear_all" method="post">
        <button style="background:#330000;color:red;border:1px solid red;cursor:pointer">LIMPAR TUDO</button>
      </form>
    </div></div></body></html>
    """
    return render_template_string(html, w_len=len(waiting_queue), g_len=len(games),
                                  games_list=games, now=now, hof=hall_of_fame[-10:])

@app.route('/admin/delete/<int:m_id>')
def delete_match(m_id):
    if m_id in games: del games[m_id]
    return '<script>window.location.href="/";</script>'

@app.route('/admin/clear_all', methods=['POST'])
def clear_all():
    global games, waiting_queue
    games.clear(); waiting_queue.clear()
    return '<script>alert("Limpeza completa!"); window.location.href="/";</script>'

# --- JOGO ---

@app.route('/join')
def join():
    if not waiting_queue:
        m_id = 1000 + int(time.time()) % 9000
        waiting_queue.append(m_id)
        games[m_id] = {
            'p1_id': 1, 'p2_id': None,
            'p1_l': None, 'p2_l': None,
            'turn': 1,
            'pending_shot': None,
            'shot_status': 'WAITING',
            'chat_msg': None,       # ← campo de chat
            'last_act': time.time()
        }
        return f"{m_id},1"
    else:
        m_id = waiting_queue.pop(0)
        if m_id not in games: return "0,ERR"
        games[m_id]['p2_id'] = 2
        games[m_id]['last_act'] = time.time()
        return f"{m_id},2"

@app.route('/update')
def update():
    m_id = request.args.get('id', type=int)
    p_id = request.args.get('p', type=int)
    cmd  = request.args.get('cmd', '')
    data = request.args.get('data', '')

    if m_id not in games: return "ERR_NOT_FOUND"

    g = games[m_id]
    g['last_act'] = time.time()

    if cmd == 'wait_p2':
        return "JOINED" if g['p2_id'] is not None else "WAITING"

    if cmd == 'layout':
        if p_id == 1: g['p1_l'] = data
        else:         g['p2_l'] = data
        return "OK"

    if cmd == 'check_ready':
        return "READY" if (g['p1_l'] and g['p2_l']) else "WAITING"

    if cmd == 'shoot':
        g['pending_shot'] = data
        g['shot_status']  = 'WAITING'
        return "OK"

    if cmd == 'get_shot':
        if g['pending_shot'] and g['turn'] == p_id:
            return g['pending_shot']
        return "NONE"

    if cmd == 'send_result':
        g['shot_status']  = data
        g['pending_shot'] = None
        g['turn'] = 2 if p_id == 1 else 1
        return "OK"

    if cmd == 'check_result':
        if g['shot_status'] != 'WAITING':
            res = g['shot_status']
            g['shot_status'] = 'WAITING'
            return res
        return "WAITING"

    if cmd == 'archive':
        msg = f"Match {m_id}: Player {p_id} Victory! [{time.strftime('%d/%m %H:%M')}]"
        hall_of_fame.append(msg)
        if m_id in games: del games[m_id]
        return "ARCHIVED"

    # --- CHAT ---

    if cmd == 'chat_send':
        # Guarda mensagem (máx 28 chars, sanitiza)
        msg = data[:28].replace('\n', ' ').replace('\r', '')
        g['chat_msg'] = msg
        return "OK"

    if cmd == 'chat_get':
        # Devolve mensagem e apaga do servidor imediatamente
        if g['chat_msg']:
            msg = g['chat_msg']
            g['chat_msg'] = None
            return msg
        return "NONE"

    return "ERR_CMD"

if __name__ == '__main__':
    app.run(debug=True)
