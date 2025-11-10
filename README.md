# Clareza Diária - App Flutter

Aplicativo móvel desenvolvido em Flutter para o projeto Clareza Diária, com telas de cadastro e login.

## Funcionalidades

- ✅ Tela de Login com integração com API Flask
- ✅ Tela de Cadastro em 2 passos
- ✅ Banco de dados SQLite local para armazenamento
- ✅ Interface moderna e responsiva

## Estrutura do Projeto

```
lib/
├── main.dart                 # Arquivo principal com rotas
├── models/
│   └── user.dart            # Modelo de dados do usuário
├── services/
│   ├── database_service.dart # Serviço SQLite
│   └── api_service.dart     # Serviço de comunicação com API Flask
└── screens/
    ├── login_screen.dart           # Tela de login
    ├── cadastro_step1_screen.dart  # Tela de cadastro - Passo 1
    └── cadastro_step2_screen.dart  # Tela de cadastro - Passo 2
```

## Configuração da API

Para conectar o app com sua API Flask no PythonAnywhere, você precisa editar o arquivo `lib/services/api_service.dart` e atualizar a URL:

```dart
static const String baseUrl = 'https://seuusuario.pythonanywhere.com';
```

Substitua `seuusuario` pelo seu usuário do PythonAnywhere.

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

## Banco de Dados SQLite

O aplicativo usa SQLite para armazenar os dados dos usuários localmente. O banco de dados é criado automaticamente na primeira execução.

### Schema da Tabela `users`

- `id` (INTEGER PRIMARY KEY AUTOINCREMENT)
- `nomeCompleto` (TEXT NOT NULL)
- `email` (TEXT NOT NULL UNIQUE)
- `senha` (TEXT NOT NULL)
- `quemE` (TEXT)
- `preferenciasSensoriais` (TEXT)

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

- `sqflite: ^2.3.0` - Banco de dados SQLite
- `path: ^1.8.3` - Gerenciamento de caminhos
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
- Botão "Criar Conta" que salva no SQLite local
- Link "Voltar para login"

## Observações

- As senhas são armazenadas em texto plano no SQLite local (não recomendado para produção)
- Para produção, considere implementar hash de senhas (bcrypt, argon2, etc.)
- A comunicação com a API é feita apenas na tela de login
- O cadastro é salvo apenas localmente no SQLite
