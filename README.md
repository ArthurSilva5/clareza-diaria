# Clareza Diária - App Flutter

Aplicativo móvel desenvolvido em Flutter para o projeto Clareza Diária, com telas de cadastro e login.

## Funcionalidades

- ✅ Tela de Login com integração com API Flask
- ✅ Tela de Cadastro em 2 passos
- ✅ Banco de dados MySQL para armazenamento
- ✅ Interface moderna e responsiva

## Estrutura do Projeto

```
lib/
├── main.dart                 # Arquivo principal com rotas
├── models/
│   └── user.dart            # Modelo de dados do usuário
├── services/
│   └── api_service.dart     # Serviço de comunicação com API Flask
└── screens/
    ├── login_screen.dart           # Tela de login
    ├── cadastro_step1_screen.dart  # Tela de cadastro - Passo 1
    └── cadastro_step2_screen.dart  # Tela de cadastro - Passo 2
```

## Configuração da API

Para conectar o app com sua API, edite o arquivo `lib/services/api_service.dart` e ajuste a URL:

```dart
static const String baseUrl = 'http://127.0.0.1:5000';
```

Em produção, substitua pela URL pública (por exemplo, `https://seuusuario.pythonanywhere.com`).

> **Novo backend Flask completo**: agora o repositório traz uma API com MySQL e JWT em `backend/`. Veja as instruções detalhadas em `backend/README.md`. Os endpoints implementados cobrem autenticação, rotinas, diário, CAA, relatórios e compartilhamento.

### Endpoint Esperado

A API deve ter um endpoint `/api/login` que aceita POST requests com o seguinte formato:

**Request:**
```json
{
  "email": "usuario@email.com",
  "senha": "senha123"
}
```

**Response de Sucesso (200):**
```json
{
  "success": true,
  "message": "Login realizado com sucesso",
  "data": {
    // dados do usuário
  }
}
```

**Response de Erro (400/401):**
```json
{
  "success": false,
  "message": "Email ou senha inválidos"
}
```

## Backend Flask + MySQL

O aplicativo Flutter não acessa mais o banco diretamente. Toda a persistência é feita pela API Flask disponível em `backend/`.  
Passos rápidos:

1. Configure o arquivo `backend/.env` (copie `env.example`) com a `DATABASE_URL` do seu MySQL.
2. Dentro de `backend/`, ative a virtualenv e rode `python -m flask --app app db upgrade` para aplicar o schema.
3. Suba a API com `python -m flask --app app run --debug`.
4. Atualize `lib/services/api_service.dart` (já configurado para `http://127.0.0.1:5000`) se mudar o host/porta.

Todas as instruções detalhadas estão em `backend/README.md`.

## Como Executar

1. Certifique-se de ter o Flutter instalado:
   ```bash
   flutter --version
   ```

2. Instale as dependências:
   ```bash
   flutter pub get
   ```

3. Execute o aplicativo:
   ```bash
   flutter run
   ```

## Dependências

- `http: ^1.1.0` - Requisições HTTP

## Telas

### 1. Tela de Login
- Campos: E-mail e Senha
- Checkbox "Lembrar-me"
- Botão "Entrar" que comunica com a API Flask
- Link para cadastro e recuperação de senha

### 2. Tela de Cadastro - Passo 1
- Campos: Nome Completo, E-mail, Senha
- Botão "Próximo" para avançar ao passo 2
- Link "Voltar para login"

### 3. Tela de Cadastro - Passo 2
- Campo dropdown "Quem é você?"
- Campo de texto multiline "Preferências sensoriais (opcional)"
- Botão "Criar Conta" que envia os dados para a API Flask/MySQL
- Link "Voltar para login"

## Observações

- As senhas ainda são enviadas e gravadas em texto plano (não recomendado para produção)
- Para produção, considere implementar hash de senhas (bcrypt, argon2, etc.)
- A API Flask cuida de todo o acesso ao banco MySQL; o app consome apenas os endpoints HTTP

## 

- cd backend
- .\.venv\Scripts\Activate.ps1
- pip install -r requirements.txt
- flask --app app run --debug

flutter run -d web-server