"""Ejecuta un archivo .sql sobre SQLite e imprime el resultado de cada SELECT."""
import sqlite3, sys
con = sqlite3.connect(sys.argv[1]); buf = ''
for line in open(sys.argv[2], encoding='utf-8'):
    buf += line
    if sqlite3.complete_statement(buf):
        stmt = buf.strip(); buf = ''
        title = [l for l in stmt.splitlines() if l.startswith('--')]
        cur = con.execute(stmt)
        if cur.description:
            print('\n' + ('\n'.join(title) if title else stmt[:80]))
            cols = [d[0] for d in cur.description]; rows = cur.fetchall()
            w = [max(len(str(c)), *(len(str(r[i])) for r in rows)) if rows else len(str(c)) for i, c in enumerate(cols)]
            print(' | '.join(str(c).ljust(w[i]) for i, c in enumerate(cols)))
            for r in rows: print(' | '.join(str(x).ljust(w[i]) for i, x in enumerate(r)))
con.commit()
