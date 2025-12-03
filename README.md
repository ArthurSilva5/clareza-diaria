# Clareza Diária - Aplicativo móvel desenvolvido em Flutter


1. Copie o env.example, e mude a `DATABASE_URL` do seu MySQL:
  - Nos campos (SEU USUARIO) e (SUA SENHA), coloque seu usuario e senha da conexão que tu irá criar no MYSQL.
  - Entre nessa conexão e crie um schema com o nome: clareza_diaria



2. Separe dois terminais, no primeiro execute esses comandos:
  - cd backend
  - python -m venv .venv
  - .\.venv\Scripts\Activate.ps1
  - pip install -r requirements.txt

  * Inicialize o banco:
  - flask --app app db init      # primeiro uso
  - flask --app app db migrate   # gerar migrações
  - flask --app app db upgrade   # aplicar schema
  - flask --app app run --debug  # executa a api



3. No segundo terminal, execute esses comandos:

  Certifique-se de ter o Flutter instalado:

   flutter --version

  Instale as dependências:

   flutter pub get

   Execute o aplicativo:

   flutter run -d web-server

4. No segundo terminal, irá aparecer uma mensagem assim como do exemplo: "http://localhost:58557/"
5. Copie o que aparecer, e cole no seu navegador para rodar o programa.



# Resumo: Funcionamento Offline

1. Armazenamento local:
  Quando o usuário cria um registro (diário, rotina, etc.), salvo primeiro no dispositivo usando Hive (banco de dados local).

2. Tentativa de sincronização:
  Tento enviar para o servidor.
  Se estiver online: envia e marca como sincronizado.
  Se estiver offline: mantém salvo localmente e marca como pendente.

3. Sincronização automática
  Quando a internet volta, o app detecta e envia automaticamente os registros pendentes para o servidor.

4. Exibição dos dados
  As telas mostram primeiro os dados salvos localmente.
  Depois, atualiza com os dados do servidor quando possível.

Tecnologias usadas:
  Hive: banco de dados local no dispositivo
  connectivity_plus: detecta se há internet
  Fila de sincronização: guarda o que precisa ser enviado
