import sqlite3

conn = sqlite3.connect('config/db.sqlite3')
cursor = conn.cursor()
cursor.execute('SELECT seat_id, is_diseased, disease_name, disease_confidence FROM seats WHERE seat_id LIKE "T%" LIMIT 10')
print('Seats with disease data:')
for row in cursor.fetchall():
    print(f'  seat_id={row[0]}, is_diseased={row[1]}, disease_name={row[2]}, confidence={row[3]}')
conn.close()
