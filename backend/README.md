# Backend API - Family Work Ledger

Flask REST API for the Family Work Ledger application.

## Features

- ✅ RESTful API endpoints for expense management
- ✅ MySQL database integration
- ✅ Input validation and error handling
- ✅ CORS support for cross-origin requests
- ✅ Logging for debugging and monitoring
- ✅ Health check endpoint with DB connectivity test

## Prerequisites

- Python 3.8+
- MySQL 5.7+ or MariaDB 10.3+
- pip (Python package manager)

## Installation

1. Install dependencies:
```bash
pip install -r requirements.txt
```

2. Set up database:
```bash
# Login to MySQL
mysql -u root -p

# Run the schema
mysql -u root -p < schema.sql
```

3. Configure environment variables:
```bash
# Copy example config
cp .env.example .env

# Edit .env with your database credentials
nano .env
```

## Running the Server

### Development
```bash
python app.py
```

The server will start on `http://0.0.0.0:8000`

### Production
For production, use a WSGI server like Gunicorn:
```bash
pip install gunicorn
gunicorn -w 4 -b 0.0.0.0:8000 app:app
```

## API Endpoints

### Health Check
```http
GET /health
```
Returns server status and database connectivity.

**Response:**
```json
{
  "ok": true,
  "time": "2025-11-03T13:30:00.000Z",
  "database": "ok"
}
```

### List Expenses
```http
GET /api/expenses?keyword=&start_date=&end_date=
```

**Query Parameters:**
- `keyword` (optional): Search in receiver, project, or note
- `start_date` (optional): Filter by start date (YYYY-MM-DD)
- `end_date` (optional): Filter by end date (YYYY-MM-DD)

**Response:**
```json
[
  {
    "id": 1,
    "date": "2025-01-15",
    "receiver": "张三",
    "amount": 500.00,
    "project": "办公用品",
    "type": "采购",
    "pay_method": "微信",
    "note": "购买文具"
  }
]
```

### Add Expense
```http
POST /api/expenses
Content-Type: application/json
```

**Request Body:**
```json
{
  "date": "2025-01-15",
  "receiver": "张三",
  "amount": 500.00,
  "project": "办公用品",
  "type": "采购",
  "pay_method": "微信",
  "note": "购买文具"
}
```

**Response:**
```json
{
  "ok": true,
  "id": 1
}
```

**Validation Rules:**
- All fields except `note` are required
- `date`: Must be in YYYY-MM-DD format
- `amount`: Must be a positive number
- `receiver`: Max 100 characters
- `project`: Max 100 characters
- `type`: Max 50 characters
- `pay_method`: Max 50 characters
- `note`: Max 1000 characters (optional)

## Error Handling

All errors return appropriate HTTP status codes with JSON responses:

```json
{
  "error": "Error message description"
}
```

**Common Status Codes:**
- `200`: Success
- `201`: Created
- `400`: Bad Request (validation error)
- `500`: Internal Server Error

## Database Schema

See `schema.sql` for the complete database schema definition.

**Main Table: expenses**
- `id`: Primary key (auto-increment)
- `date`: Expense date
- `receiver`: Recipient name
- `amount`: Amount (decimal)
- `project`: Project name
- `type`: Expense type
- `pay_method`: Payment method
- `note`: Additional notes
- `created_at`: Record creation timestamp
- `updated_at`: Last update timestamp

## Logging

The application logs important events:
- API requests and responses
- Database operations
- Errors and exceptions

Logs are output to stdout in the format:
```
2025-11-03 13:30:00,123 - app - INFO - Retrieved 10 expenses
```

## Security Notes

⚠️ **Important Security Considerations:**

1. **Authentication**: This API currently has no authentication. Consider adding:
   - API key authentication
   - JWT tokens
   - OAuth 2.0

2. **CORS**: Currently allows all origins. In production, configure specific origins:
   ```python
   CORS(app, origins=['https://yourdomain.com'])
   ```

3. **Database Credentials**: Never commit `.env` file. Use environment variables in production.

4. **HTTPS**: Always use HTTPS in production to encrypt data in transit.

5. **Rate Limiting**: Consider adding rate limiting to prevent abuse.

## Testing

To test the API manually:

```bash
# Health check
curl http://localhost:8000/health

# List expenses
curl http://localhost:8000/api/expenses

# Add expense
curl -X POST http://localhost:8000/api/expenses \
  -H "Content-Type: application/json" \
  -d '{
    "date": "2025-01-15",
    "receiver": "Test",
    "amount": 100.00,
    "project": "Test Project",
    "type": "Test",
    "pay_method": "Cash",
    "note": "Test note"
  }'
```

## Troubleshooting

### Database Connection Issues
- Verify MySQL is running: `systemctl status mysql`
- Check credentials in `.env` file
- Ensure database exists: `mysql -u root -p -e "SHOW DATABASES;"`

### Port Already in Use
Change the port in `app.py`:
```python
app.run(host='0.0.0.0', port=8001)  # Use different port
```

### Module Import Errors
Reinstall dependencies:
```bash
pip install -r requirements.txt --force-reinstall
```

## License

AGPL v3.0 - See LICENSE file for details.
