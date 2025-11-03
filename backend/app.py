from flask import Flask, request, jsonify
from flask_cors import CORS
import os
import mysql.connector as mysql
from mysql.connector import Error as MySQLError
from datetime import datetime
import logging
from decimal import Decimal, InvalidOperation

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

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
    """Get database connection with error handling"""
    try:
        conn = mysql.connect(**DB_CFG)
        return conn
    except MySQLError as e:
        logger.error(f"Database connection failed: {e}")
        raise

def validate_date(date_str):
    """Validate date format (YYYY-MM-DD)"""
    if not date_str:
        return False
    try:
        datetime.strptime(date_str, '%Y-%m-%d')
        return True
    except ValueError:
        return False

def validate_amount(amount):
    """Validate amount is positive number"""
    try:
        amt = Decimal(str(amount))
        return amt > 0
    except (InvalidOperation, ValueError, TypeError):
        return False

@app.get('/health')
def health():
    """Health check endpoint with database connectivity test"""
    db_status = 'ok'
    try:
        with get_conn() as conn:
            cur = conn.cursor()
            cur.execute("SELECT 1")
            cur.fetchone()
    except Exception as e:
        logger.error(f"Health check failed: {e}")
        db_status = 'error'
    
    return jsonify({
        'ok': db_status == 'ok',
        'time': datetime.utcnow().isoformat(),
        'database': db_status
    })

@app.get('/api/expenses')
def list_expenses():
    """List expenses with optional filtering"""
    try:
        kw = request.args.get('keyword', '')
        start = request.args.get('start_date')
        end = request.args.get('end_date')
        
        # Validate date parameters
        if start and not validate_date(start):
            return jsonify({'error': 'Invalid start_date format. Use YYYY-MM-DD'}), 400
        if end and not validate_date(end):
            return jsonify({'error': 'Invalid end_date format. Use YYYY-MM-DD'}), 400
        
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
        
        logger.info(f"Retrieved {len(rows)} expenses")
        return jsonify(rows)
    
    except MySQLError as e:
        logger.error(f"Database error in list_expenses: {e}")
        return jsonify({'error': 'Database error occurred'}), 500
    except Exception as e:
        logger.error(f"Unexpected error in list_expenses: {e}")
        return jsonify({'error': 'Internal server error'}), 500

@app.post('/api/expenses')
def add_expense():
    """Add a new expense with validation"""
    try:
        data = request.json or {}
        
        # Validate required fields
        required_fields = ['date', 'receiver', 'amount', 'project', 'type', 'pay_method']
        missing_fields = [f for f in required_fields if not data.get(f)]
        if missing_fields:
            return jsonify({
                'error': f'Missing required fields: {", ".join(missing_fields)}'
            }), 400
        
        # Validate date format
        if not validate_date(data['date']):
            return jsonify({'error': 'Invalid date format. Use YYYY-MM-DD'}), 400
        
        # Validate amount
        if not validate_amount(data['amount']):
            return jsonify({'error': 'Amount must be a positive number'}), 400
        
        # Validate string length
        if len(data['receiver']) > 100:
            return jsonify({'error': 'Receiver name too long (max 100 characters)'}), 400
        if len(data['project']) > 100:
            return jsonify({'error': 'Project name too long (max 100 characters)'}), 400
        if len(data['type']) > 50:
            return jsonify({'error': 'Type too long (max 50 characters)'}), 400
        if len(data['pay_method']) > 50:
            return jsonify({'error': 'Payment method too long (max 50 characters)'}), 400
        
        note = data.get('note', '')
        if len(note) > 1000:
            return jsonify({'error': 'Note too long (max 1000 characters)'}), 400
        
        sql = ("INSERT INTO expenses(date, receiver, amount, project, type, pay_method, note) "
               "VALUES(%s,%s,%s,%s,%s,%s,%s)")
        vals = (
            data['date'], 
            data['receiver'], 
            data['amount'],
            data['project'], 
            data['type'], 
            data['pay_method'], 
            note
        )
        
        with get_conn() as conn:
            cur = conn.cursor()
            cur.execute(sql, vals)
            conn.commit()
            expense_id = cur.lastrowid
        
        logger.info(f"Added expense with id {expense_id}")
        return jsonify({'ok': True, 'id': expense_id}), 201
    
    except MySQLError as e:
        logger.error(f"Database error in add_expense: {e}")
        return jsonify({'error': 'Database error occurred'}), 500
    except Exception as e:
        logger.error(f"Unexpected error in add_expense: {e}")
        return jsonify({'error': 'Internal server error'}), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8000)
