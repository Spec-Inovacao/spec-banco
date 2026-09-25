# Modelo de Dados Relacional — Agenda Fácil

Este repositório documenta a camada de persistência de dados do sistema **Agenda Fácil**, estruturado em PostgreSQL. O modelo foi projetado para suportar o fluxo completo de agendamento online com verificação de disponibilidade, controle de expediente e bloqueios administrativos.

---

## 1. Visão Geral da Arquitetura

O modelo é composto por 5 tabelas centrais:

- **`PUSUARIOS`**: Cadastro unificado de clientes e administradores/proprietários.
- **`PSERVICOS`**: Catálogo de serviços oferecidos com duração e precificação.
- **`PCONFIGEXP`**: Definições parametrizáveis do negócio (expediente, dias letivos e política de cancelamento).
- **`PAGENDAMENTOS`**: Transações de reserva de horários efetuadas por clientes ou adicionadas pelo proprietário.
- **`PBLOQAGENDA`**: Períodos de indisponibilidade cadastrados administrativamente (intervalos de almoço, imprevistos ou manutenções).

---

## 2. Diagrama Entidade-Relacionamento (Conceitual)

```text
+----------------+          +-------------------+          +----------------+
|   PUSUARIOS    |<--------*|   PAGENDAMENTOS   |*-------->|   PSERVICOS    |
+----------------+          +-------------------+          +----------------+
| ID (PK)        |          | ID (PK)           |          | ID (PK)        |
| ADMIN (BOOL)   |          | CLIENTEID (FK)    |          | TEMPOMIN       |
+----------------+          | SERVICOID (FK)    |          | PRECO          |
        ^                   | DTINICIO          |          +----------------+
        |                   | DTFIM             |
        |                   | STATUS            |
        |                   +-------------------+
        |
        | 1                 +-------------------+
        +------------------*|   PBLOQAGENDA     |
                            +-------------------+
                            | ID (PK)           |
                            | ADMINID (FK)      |
                            | MOTIVO            |
                            | REPDIAUTIL (BOOL) |
                            +-------------------+

+-------------------------------------------------------+
|                      PCONFIGEXP                       |
| (Tabela de Parâmetros Globais: Expediente / Políticas)|
+-------------------------------------------------------+
```

---

## 3. Dicionário de Dados e Regras de Negócio

### 3.1. `PUSUARIOS`
Centraliza tanto clientes quanto operadores do sistema.

| Coluna | Tipo | Modificadores | Descrição |
| :--- | :--- | :--- | :--- |
| `ID` | `SERIAL` | `PRIMARY KEY` | Identificador único do usuário |
| `NOME` | `VARCHAR(150)` | `NOT NULL` | Nome completo do usuário |
| `EMAIL` | `VARCHAR(150)` | `UNIQUE` | E-mail corporativo ou pessoal |
| `TELEFONE` | `VARCHAR(20)` | | Telefone para contato/confirmação |
| `ADMIN` | `BOOLEAN` | `NOT NULL DEFAULT FALSE` | Flag que define permissões de proprietário/administrador |
| `RECCREATEDON` | `TIMESTAMPTZ` | `NOT NULL DEFAULT CURRENT_TIMESTAMP` | Data/hora de inserção do registro |

---

### 3.2. `PSERVICOS`
Catálogo de procedimentos com controle de precificação e tempo de execução.

| Coluna | Tipo | Modificadores | Descrição |
| :--- | :--- | :--- | :--- |
| `ID` | `SERIAL` | `PRIMARY KEY` | Identificador único do serviço |
| `NOME` | `VARCHAR(100)` | `NOT NULL` | Título do serviço (ex: *Consulta*, *Avaliação*) |
| `DESCRICAO` | `TEXT` | | Detalhamento do atendimento |
| `TEMPOMIN` | `INTEGER` | `NOT NULL` | Duração em minutos (`CHECK: TEMPOMIN > 0`) |
| `PRECO` | `NUMERIC(10, 2)` | `NOT NULL` | Valor cobrado (`CHECK: PRECO >= 0`) |
| `ATIVO` | `BOOLEAN` | `NOT NULL DEFAULT TRUE` | Controle de exibição no catálogo público |

---

### 3.3. `PCONFIGEXP`
Configuração de regras operacionais de atendimento. Projetada para armazenar o perfil ativo de atendimento da empresa.

| Coluna | Tipo | Modificadores | Descrição |
| :--- | :--- | :--- | :--- |
| `ID` | `SERIAL` | `PRIMARY KEY` | Identificador único da configuração |
| `HORAINICIO` | `TIME` | `NOT NULL DEFAULT '09:00:00'` | Início da jornada de trabalho |
| `HORAFIM` | `TIME` | `NOT NULL DEFAULT '18:00:00'` | Término da jornada de trabalho |
| `CANCELAMENTOMINHORA` | `INTEGER` | `NOT NULL DEFAULT 2` | Prazo mínimo em horas para permitir auto-cancelamento |
| `DIASATENDIMENTO` | `INTEGER[]` | `NOT NULL DEFAULT ARRAY[1,2,3,4,5,6]` | Array contendo os dias da semana com expediente (0 = Dom, 1 = Seg, ..., 6 = Sáb) |

**Constraints de validação:**
- `CHK_HORARIO_CONFIG_VALIDO`: Garante que `HORAFIM > HORAINICIO`.
- `CHK_DIAS_ATENDIMENTO_VALIDOS`: Garante via operador `<@` que o array só contenha dígitos de 0 a 6.

---

### 3.4. `PAGENDAMENTOS`
Registros das reservas efetuadas.

| Coluna | Tipo | Modificadores | Descrição |
| :--- | :--- | :--- | :--- |
| `ID` | `SERIAL` | `PRIMARY KEY` | Identificador do agendamento |
| `CLIENTEID` | `INTEGER` | `REFERENCES PUSUARIOS(ID) ON DELETE SET NULL` | Chave estrangeira do cliente (preserva histórico se o usuário for removido) |
| `SERVICOID` | `INTEGER` | `NOT NULL REFERENCES PSERVICOS(ID)` | Serviço contratado |
| `DTINICIO` | `TIMESTAMPTZ` | `NOT NULL` | Início exato com fuso horário |
| `DTFIM` | `TIMESTAMPTZ` | `NOT NULL` | Fim exato calculado a partir do `TEMPOMIN` do serviço |
| `STATUS` | `VARCHAR(20)` | `NOT NULL DEFAULT 'agendado'` | Estado da reserva |
| `RECCREATEDON` | `TIMESTAMPTZ` | `NOT NULL DEFAULT CURRENT_TIMESTAMP` | Log de criação |

**Constraints de validação:**
- `CHK_STATUS_AGENDAMENTO`: Restringe o status a `'agendado'`, `'cancelado'` ou `'concluido'`.
- `CHK_PERIODO_VALIDO`: Impede intervalos invertidos (`DTFIM > DTINICIO`).

---

### 3.5. `PBLOQAGENDA`
Reserva de períodos para indisponibilidade administrativa (almoço, ausências pontuais ou bloqueios técnicos).

| Coluna | Tipo | Modificadores | Descrição |
| :--- | :--- | :--- | :--- |
| `ID` | `SERIAL` | `PRIMARY KEY` | Identificador do bloqueio |
| `ADMINID` | `INTEGER` | `REFERENCES PUSUARIOS(ID) ON DELETE SET NULL` | Usuário administrador responsável pelo bloqueio |
| `MOTIVO` | `VARCHAR(150)` | `NOT NULL` | Razão do bloqueio (ex: "Almoço", "Manutenção") |
| `DTINICIO` | `TIMESTAMPTZ` | `NOT NULL` | Data/hora de início da indisponibilidade |
| `DTFIM` | `TIMESTAMPTZ` | `NOT NULL` | Data/hora final da indisponibilidade |
| `REPDIAUTIL` | `BOOLEAN` | `NOT NULL DEFAULT FALSE` | Flag para repetição sistemática em dias úteis |
| `RECCREATEDON` | `TIMESTAMPTZ` | `NOT NULL DEFAULT CURRENT_TIMESTAMP` | Log de registro do bloqueio |

**Constraints de validação:**
- `CHK_BLOQUEIO_VALIDO`: Garante consistência temporal (`DTFIM > DTINICIO`).

---

## 4. Lógica de Validação e Conflito de Horários

Para garantir a regra fundamental de **sem conflito** e **respeito ao expediente**, as consultas de disponibilidade e as regras de inserção devem verificar:

1. **Dentro do Expediente:**
   ```sql
   (DTINICIO::time >= PCONFIGEXP.HORAINICIO) 
   AND (DTFIM::time <= PCONFIGEXP.HORAFIM)
   AND (EXTRACT(DOW FROM DTINICIO) = ANY(PCONFIGEXP.DIASATENDIMENTO))
   ```

2. **Detecção de Sobreposição (Anti-Conflito):**
   Um novo agendamento ou bloqueio não pode cruzar com agendamentos ativos (`STATUS = 'agendado'`) ou bloqueios existentes:
   ```sql
   -- Intervalo proposto: [NovoInicio, NovoFim]
   NOT (NovoFim <= DTINICIO OR NovoInicio >= DTFIM)
   ```

3. **Política de Cancelamento:**
   O auto-cancelamento pelo cliente só é autorizado caso:
   ```sql
   CURRENT_TIMESTAMP + (PCONFIGEXP.CANCELAMENTOMINHORA * INTERVAL '1 hour') <= PAGENDAMENTOS.DTINICIO
   ```
