- Após colar, sempre verifique se `import sys` está no início absoluto da linha

---

## ⚠️ Problema: "E-mail ou senha inválidos" após cadastrar

### Por que isso acontece?

O app Flutter tem **dois bancos de dados diferentes**:

1. **Cadastro (SQLite local):** Quando você se cadastra no app, os dados são salvos no banco SQLite local do seu dispositivo (Windows/Android/iOS)
2. **Login (API Flask):** Quando você tenta fazer login, o app consulta o banco de dados do Flask no PythonAnywhere (servidor remoto)

Como são bancos diferentes, o usuário que você cadastrou localmente **não existe** no servidor Flask!

### Solução 1: Criar um usuário de teste diretamente no banco do Flask

Para testar o login, você precisa criar um usuário diretamente no banco do servidor Flask:

1. **Acesse o Console do PythonAnywhere:**
   - Faça login no PythonAnywhere
   - Clique em **"Consoles"** → **"Bash"** ou **"Python 3.10"**

2. **Execute este código Python no console:**
   ```python
   import sqlite3
   import os
   
   # Caminho do banco de dados (mesmo que no app.py)
   DATABASE = os.path.join(os.path.expanduser('~'), 'database.db')
   
   # Criar conexão
   conn = sqlite3.connect(DATABASE)
   
   # Criar tabela se não existir
   conn.execute('''
       CREATE TABLE IF NOT EXISTS users (
           id INTEGER PRIMARY KEY AUTOINCREMENT,
           nomeCompleto TEXT NOT NULL,
           email TEXT NOT NULL UNIQUE,
           senha TEXT NOT NULL,
           quemE TEXT,
           preferenciasSensoriais TEXT
       )
   ''')
   
   # Inserir usuário de teste
   conn.execute('''
       INSERT OR REPLACE INTO users (nomeCompleto, email, senha, quemE, preferenciasSensoriais)
       VALUES (?, ?, ?, ?, ?)
   ''', ('Admin Teste', 'admin@gmail.com', '123456', 'Usuário', 'Nenhuma'))
   
   # Salvar alterações
   conn.commit()
   
   # Verificar se foi inserido
   cursor = conn.execute('SELECT * FROM users WHERE email = ?', ('admin@gmail.com',))
   user = cursor.fetchone()
   if user:
       print(f"✅ Usuário criado com sucesso!")
       print(f"   Email: {user[2]}")
       print(f"   Senha: {user[3]}")
   else:
       print("❌ Erro ao criar usuário")
   
   conn.close()
   ```

3. **Teste o login no Flutter:**
   - Email: `admin@gmail.com`
   - Senha: `123456`

### Solução 2: Fazer o cadastro enviar para a API também (Recomendado)

Para que o cadastro funcione completamente, você precisa fazer o Flutter enviar os dados também para a API Flask ao se cadastrar. Isso requer modificar o código do `cadastro_step2_screen.dart`.

**Nota:** Atualmente, o cadastro só salva localmente. Se quiser, posso ajudar a modificar para também enviar para a API.

### Solução 3: Usar o endpoint /api/register

Se você já tem o endpoint `/api/register` configurado no Flask, você pode:

1. Usar uma ferramenta como Postman ou curl para criar o usuário via API
2. Ou modificar o código do Flutter para chamar a API no cadastro

### Qual solução usar?

- **Para teste rápido:** Use a Solução 1 (criar usuário direto no banco)
- **Para uso completo:** Implemente a Solução 2 (cadastro também envia para API)

Me diga qual você prefere que eu ajude a implementar!
