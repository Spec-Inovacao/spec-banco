-- Usuários: 1 admin + 4 clientes
INSERT INTO PUSUARIOS (NOME, EMAIL, TELEFONE, ADMIN) VALUES
    ('Ana Prado',        'ana.prado@salao.com',      '11988880001', TRUE),
    ('Bruno Carvalho',   'bruno.carvalho@email.com', '11988880002', FALSE),
    ('Carla Menezes',    'carla.menezes@email.com',  '11988880003', FALSE),
    ('Diego Almeida',    'diego.almeida@email.com',  '11988880004', FALSE),
    ('Elaine Rocha',     'elaine.rocha@email.com',   '11988880005', FALSE);

-- Serviços (TEMPOMIN em minutos)
INSERT INTO PSERVICOS (NOME, DESCRICAO, TEMPOMIN, PRECO, ATIVO) VALUES
    ('Corte Masculino',  'Corte de cabelo masculino',              30,  45.00, TRUE),
    ('Corte Feminino',   'Corte de cabelo feminino',               60,  90.00, TRUE),
    ('Coloração',        'Coloração completa',                    120, 180.00, TRUE),
    ('Barba',            'Aparo e modelagem de barba',             30,  35.00, TRUE),
    ('Hidratação',       'Hidratação capilar profunda',            45,  70.00, TRUE),
    ('Escova',           'Escova modelada (serviço desativado)',   40,  50.00, FALSE);

-- Configuração de expediente (linha única)
-- 09:00–18:00, cancelamento com no mínimo 2h de antecedência,
-- atendimento de segunda (1) a sábado (6)
INSERT INTO PCONFIGEXP (HORAINICIO, HORAFIM, CANCELAMENTOMINHORA, DIASATENDIMENTO)
VALUES (TIME '09:00:00', TIME '18:00:00', 2, ARRAY[1,2,3,4,5,6]::INTEGER[]);

-- Agendamentos
-- DTFIM coerente com o TEMPOMIN do serviço.
-- Fusos em -03:00 (America/Sao_Paulo).
INSERT INTO PAGENDAMENTOS (CLIENTEID, SERVICOID, DTINICIO, DTFIM, STATUS) VALUES
    -- Segunda 28/09: dois agendamentos sequenciais, sem sobreposição
    (2, 1, TIMESTAMPTZ '2026-09-28 09:00:00-03', TIMESTAMPTZ '2026-09-28 09:30:00-03', 'agendado'),
    (3, 2, TIMESTAMPTZ '2026-09-28 10:00:00-03', TIMESTAMPTZ '2026-09-28 11:00:00-03', 'agendado'),
    -- Terça 29/09: serviço longo (coloração, 120 min)
    (4, 3, TIMESTAMPTZ '2026-09-29 14:00:00-03', TIMESTAMPTZ '2026-09-29 16:00:00-03', 'agendado'),
    -- Quarta 30/09: um cancelado e um concluído (cobre os três status)
    (5, 4, TIMESTAMPTZ '2026-09-30 09:00:00-03', TIMESTAMPTZ '2026-09-30 09:30:00-03', 'cancelado'),
    (2, 5, TIMESTAMPTZ '2026-09-30 11:00:00-03', TIMESTAMPTZ '2026-09-30 11:45:00-03', 'concluido'),
    -- Sábado 03/10: agendamento em dia de atendimento válido
    (3, 1, TIMESTAMPTZ '2026-10-03 15:00:00-03', TIMESTAMPTZ '2026-10-03 15:30:00-03', 'agendado');

-- Bloqueios de agenda (feito pela admin Ana, ID 1)
INSERT INTO PBLOQAGENDA (ADMINID, MOTIVO, DTINICIO, DTFIM, REPDIAUTIL) VALUES
    -- Almoço fixo de sexta 02/10
    (1, 'Horário de almoço', TIMESTAMPTZ '2026-10-02 12:00:00-03', TIMESTAMPTZ '2026-10-02 13:00:00-03', FALSE),
    -- Feriado / fechamento de um dia inteiro (quinta 01/10)
    (1, 'Manutenção do espaço', TIMESTAMPTZ '2026-10-01 09:00:00-03', TIMESTAMPTZ '2026-10-01 18:00:00-03', FALSE);
