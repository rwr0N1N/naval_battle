from flask import Flask, request, jsonify

app = Flask(__name__)

# Base de dados em memória
matches = {}
waiting_queue = []

@app.route('/')
def home():
    return "Servidor Batalha Naval PicoOS Ativo!"

@app.route('/join')
def join():
    global waiting_queue
    player_id = request.args.get('uid', 'anon')
    
    if not waiting_queue:
        match_id = len(matches) + 1000
        matches[match_id] = {
            'p1': player_id, 'p2': None, 
            'p1_board': None, 'p2_board': None,
            'turn': 0, 'last_shot': None
        }
        waiting_queue.append(match_id)
        return f"{match_id},1" # ID da Match, Tu és Jogador 1
    else:
        match_id = waiting_queue.pop(0)
        matches[match_id]['p2'] = player_id
        return f"{match_id},2" # ID da Match, Tu és Jogador 2

@app.route('/update')
def update():
    m_id = int(request.args.get('id'))
    p_num = int(request.args.get('p'))
    data = request.args.get('data', '')
    cmd = request.args.get('cmd', '')

    if m_id not in matches: return "ERR,NO_MATCH"
    
    match = matches[m_id]
    if cmd == "layout":
        match[f'p{p_num}_board'] = data
        if match['p1_board'] and match['p2_board']:
            match['turn'] = 1 # Começa o Jogo!
        return "OK"
    
    if cmd == "shoot":
        match['last_shot'] = f"{p_num},{data}" # ex: "1,4,5" (P1 atirou em 4,5)
        match['turn'] = 2 if p_num == 1 else 1
        return "OK"
    
    # Retorna status: turn, last_shot
    return f"{match['turn']},{match['last_shot']}"

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
