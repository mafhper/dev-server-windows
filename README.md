# Painel de Controle para Servidor de Desenvolvimento Local (Windows)

## Visão Geral

Este script para PowerShell transforma a maneira como desenvolvedores gerenciam múltiplos projetos web em um ambiente Windows. Ele oferece um painel de controle interativo para copiar, iniciar, parar e gerenciar projetos de diferentes tecnologias (React, Vue, Next.js, Node.js, PHP, sites estáticos) sem a necessidade de configuração manual para cada um.

É a ferramenta ideal para desenvolvedores, freelancers que trabalham com diversas stacks e precisam de uma forma rápida e organizada para rodar ambientes de desenvolvimento e produção locais.

---

## Principais Funcionalidades

- **Painel de Controle Centralizado:** Uma interface limpa que exibe em tempo real todos os servidores ativos e projetos disponíveis.
- **Suporte Multi-Stack:** Detecta e gerencia automaticamente projetos baseados em Node.js (React, Vue, Next, Express) e PHP.
- **Isolamento de Processos:** Cada servidor (frontend e backend) é executado em sua própria janela do PowerShell, facilitando a visualização de logs e a depuração.
- **Gerenciamento de Estado:** Mantém um registro dos processos em execução, permitindo que o painel seja fechado e reaberto sem perder o estado dos servidores.
- **Sincronização Automática:** Detecta e remove automaticamente servidores "fantasma" cujo processo foi encerrado inesperadamente.
- **Modos de Execução Flexíveis:**
  - **dev:** Inicia o servidor de desenvolvimento com hot-reload.
  - **build:** Compila o projeto para produção e serve os arquivos estáticos.
  - **serve:** Inicia um servidor com a última compilação existente, sem a necessidade de recompilar.
- **Integração com Backend:** Detecta automaticamente uma pasta `backend`, carrega suas variáveis de ambiente de arquivos `.env` e pode testar a conexão com o banco de dados (Postgres).
- **Checagem de Dependências:** Verifica se as ferramentas necessárias (Node, npm, PHP, etc.) estão instaladas antes de executar um projeto.

---

## Requisitos

- Windows 10 ou superior
- PowerShell 5.1 ou superior
- Dependências de projeto (instaladas separadamente):
  - Node.js e npm (para projetos JavaScript)
  - PHP e Composer (para projetos PHP)
  - Cliente `psql` (se o projeto usar backend com Postgres)

---

## Instalação e Uso

1.  **Salvar o Script:** Salve o arquivo `dev-server.ps1` em um diretório de sua preferência.
2.  **Definir Política de Execução:** Se for a primeira vez, abra o PowerShell e execute o comando abaixo para permitir a execução de scripts locais:
    ```powershell
    Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
    ```
3.  **Executar o Script:** Navegue até a pasta onde salvou o arquivo e execute-o:
    ```powershell
    .\dev-server.ps1
    ```

---

## Interface e Opções do Menu

O script apresenta um painel de controle que é atualizado a cada ação:

```
================= PAINEL DE CONTROLE DO SERVIDOR LOCAL =================

----- SERVIDORES ATIVOS -----

Servidor: meu-projeto-frontend
  PID:     12345
  Porta:   3000
  Modo:    dev
  URL:     http://localhost:3000

----- PROJETOS DISPONIVEIS -----

1. meu-projeto
   Tipo: react
   Caminho: C:\LocalServer\projects\meu-projeto
   Modificado em: 21/09/2025 10:30:00

------------------- MENU -------------------
[1] Copiar e Iniciar Novo Projeto
[2] Listar Servidores (Atualizar Painel)
[3] Parar Servidor
[4] Sair do Painel
[5] Iniciar Servidor de Projeto Existente
[6] Remover Projeto Copiado
```

---

## Casos de Uso e Exemplos

### Iniciar um novo projeto em modo de desenvolvimento

1.  Escolha a opção **[1]**.
2.  Informe o caminho de **origem** do seu projeto (ex: `C:\Users\SeuNome\Documents\meu-app-react`).
3.  O script irá copiar os arquivos, instalar as dependências e perguntar o modo de execução.
4.  Escolha `dev`.
5.  Uma nova janela do PowerShell será aberta com o servidor de desenvolvimento.

### Simular um ambiente de produção local

1.  Escolha a opção **[5]** e selecione um projeto já copiado.
2.  Quando perguntado, escolha o modo `build`.
3.  O script irá compilar o projeto e, em seguida, abrir uma nova janela servindo os arquivos estáticos gerados.

### Iniciar rapidamente um servidor com a última compilação

1.  Escolha a opção **[5]** e selecione um projeto que já foi compilado.
2.  Quando perguntado, escolha o modo `serve`.
3.  O script irá pular a etapa de compilação e servirá imediatamente os arquivos existentes na pasta `build` ou `dist`.

### Parar um servidor específico

1.  Escolha a opção **[3]**.
2.  O script listará todos os servidores ativos com um número.
3.  Digite o número do servidor que deseja parar.

### Encerrar o trabalho e desligar todos os servidores

1.  Escolha a opção **[4] Sair do Painel**.
2.  O script perguntará se você deseja parar todos os servidores ativos.
3.  Responda `s` para encerrar todos os processos antes de fechar o painel.

---

## Estrutura de Diretórios

O script gerencia todos os projetos e logs dentro de `C:\LocalServer`:

```
C:\LocalServer\
├── projects\              # Cópias dos seus projetos de desenvolvimento.
│   ├── meu-app-react\
│   └── minha-api-node\
├── logs\                  # Arquivos de log para cada processo de servidor.
└── running-processes.json # Arquivo de estado que armazena os processos ativos.
```
