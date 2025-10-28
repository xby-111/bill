from flask import Flask, request, jsonify
from flask_cors import CORS
import os, mysql.connector as mysql
from datetime import datetime

app = Flask(__name__)
CORS(app)

DB_CFG = dict(
    host=os.getenv('DB_HOST', '127.0.0.1'),
    user=os.getenv('DB_USER', 'root'),
    password=os.getenv('DB_PASS', ''),
    database=os.getenv('DB_NAME', 'family_ledger'),
    port=int(os.getenv('DB_PORT', '3306'))
)

def get_conn():
    return mysql.connect(**DB_CFG)

@app.get('/health')
def health():
    return {'ok': True, 'time': datetime.utcnow().isoformat()}

@app.get('/api/expenses')
def list_expenses():
    kw = request.args.get('keyword', '')
    start = request.args.get('start_date')
    end = request.args.get('end_date')
    q = "SELECT id, date, receiver, amount, project, type, pay_method, note FROM expenses WHERE 1=1"
    params = []
    if kw:
        q += " AND (receiver LIKE %s OR project LIKE %s OR note LIKE %s)"
        like = f"%{kw}%"
        params += [like, like, like]
    if start:
        q += " AND date >= %s"
        params.append(start)
    if end:
        q += " AND date <= %s"
        params.append(end)
    q += " ORDER BY date DESC, id DESC"

    with get_conn() as conn:
        cur = conn.cursor(dictionary=True)
        cur.execute(q, params)
        rows = cur.fetchall()
    return jsonify(rows)

@app.post('/api/expenses')
def add_expense():
    data = request.json or {}
    sql = ("INSERT INTO expenses(date, receiver, amount, project, type, pay_method, note) VALUES(%s,%s,%s,%s,%s,%s,%s)")
    vals = (
        data.get('date'), data.get('receiver'), data.get('amount'),
        data.get('project'), data.get('type'), data.get('pay_method'), data.get('note', '')
    )
    with get_conn() as conn:
        cur = conn.cursor()
        cur.execute(sql, vals)
        conn.commit()
    return {'ok': True}, 201

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8000)
