# Plano de Execução — Laboratório Firewall + DMZ + Internet

---

## 1. Preparação e Validação da Topologia

### Objetivo

Conhecer o laboratório disponibilizado pelo professor e garantir que a infraestrutura inicial está funcionando antes de implementar qualquer política de segurança.

### Atividades

- Iniciar o laboratório no Kathará.
- Identificar os dispositivos presentes na topologia:
  - `r0`
  - `fw`
  - `pc1`
  - `pc2`
  - `web`
  - `dns`
  - rede de gerenciamento, caso utilizada.

- Identificar as interfaces de cada dispositivo.
- Conferir os endereços IP e gateways.
- Conferir as rotas existentes.
- Verificar o funcionamento do encaminhamento pelo firewall.
- Confirmar que não existem regras restritivas implementadas pelo grupo.

### Validação da Baseline

Realizar os testes iniciais para registrar o comportamento da rede antes das alterações:

- LAN → Internet;
- LAN → DMZ;
- acesso ao servidor Web;
- acesso ao servidor DNS;
- comunicação entre os demais segmentos que forem relevantes para a topologia.

### Evidências

Registrar:

- estado inicial da topologia;
- endereçamento utilizado;
- resultados dos testes de conectividade;
- eventuais problemas encontrados antes da implementação do firewall.

### Entregável

**Baseline da rede funcionando e documentada.**

---

# 2. Planejamento da Política do Firewall

### Objetivo

Definir o comportamento esperado do firewall antes de começar a criar as regras.

### Atividades

Identificar:

- quais redes podem se comunicar;
- quais serviços precisam estar disponíveis;
- quais acessos devem ser bloqueados;
- quais conexões devem ser permitidas somente como resposta;
- quais comunicações não são necessárias.

### Política de Segurança

Organizar uma matriz de comunicação semelhante à proposta na atividade:

| Origem                           | Destino        | Política                |
| -------------------------------- | -------------- | ----------------------- |
| LAN                              | Internet       | Permitir                |
| LAN                              | Web/DNS da DMZ | Permitir                |
| Internet                         | Web da DMZ     | Permitir                |
| Internet                         | LAN            | Bloquear                |
| DMZ                              | LAN            | Bloquear novas conexões |
| Respostas de conexões permitidas | Origem         | Permitir                |

### Definições

Também deverá ser definido:

- política padrão do firewall;
- quais conexões serão tratadas de forma stateful;
- quais serviços precisam de exceções;
- quais regras serão necessárias para cada comunicação.

### Entregável

**Matriz de comunicação e política de segurança do firewall.**

---

# 3. Implementação e Validação do Firewall

### Objetivo

Transformar a política definida na etapa anterior em regras reais no `fw`.

### Atividades

- Escolher a ferramenta disponível no laboratório (`iptables`, `nftables` etc.).
- Organizar as regras de forma lógica.
- Implementar a política de bloqueio padrão.
- Implementar o tratamento das conexões estabelecidas.
- Criar as liberações necessárias para:
  - LAN → Internet;
  - LAN → DMZ;
  - Internet → Web;
  - demais comunicações previamente definidas.

- Criar os bloqueios necessários para:
  - Internet → LAN;
  - DMZ → LAN;
  - outros acessos não autorizados.

### Validação

Após cada conjunto de regras:

1. gerar o tráfego correspondente;
2. verificar o comportamento;
3. confirmar se a comunicação permitida continua funcionando;
4. confirmar se a comunicação bloqueada deixa de funcionar;
5. observar os contadores das regras quando necessário.

### Organização

As regras deverão ser organizadas e comentadas para permitir:

- leitura;
- manutenção;
- reprodução do laboratório;
- identificação da finalidade de cada regra.

### Entregável

**Conjunto de regras do firewall organizado, comentado e validado.**

---

# 4. Experimentos de Filtragem por Camadas

### Objetivo

Demonstrar, por meio de experimentos, como o firewall pode tomar decisões utilizando informações de diferentes camadas da comunicação.

Todos os experimentos deverão seguir o mesmo ciclo:

> **Antes da regra → Implementação da regra → Depois da regra → Análise**

Utilizar `tcpdump`, Wireshark ou outras ferramentas de observação quando necessário.

---

## 4.1 L2 — Bloqueio por MAC

### Atividades

- Identificar o endereço MAC de `pc2`.
- Testar a comunicação de `pc2` antes da regra.
- Criar uma regra para bloquear o tráfego associado ao MAC identificado.
- Repetir o teste depois da regra.
- Comparar o comportamento de `pc1` e `pc2`.

### Questão de investigação

Explicar:

- se o MAC acompanha um pacote durante todo o caminho pela Internet;
- em quais condições o firewall consegue visualizar o MAC original de `pc2`.

### Evidência

Registrar:

- MAC utilizado;
- teste antes;
- regra implementada;
- teste depois;
- explicação do resultado.

---

## 4.2 L3 — ICMP

### Atividades

- Testar `ping` antes da regra.
- Criar uma regra de bloqueio de ICMP.
- Repetir o `ping`.
- Utilizar captura de tráfego para observar o comportamento.

### Questão de investigação

Explicar:

- o que acontece com o pacote ICMP;
- em qual ponto o firewall interfere;
- diferença entre permitir e bloquear esse protocolo.

### Evidência

Registrar:

**Antes → Regra → Depois → Explicação**

---

## 4.3 L3 — Bloqueio por IP

### Atividades

- Escolher um endereço IP de destino para representar um recurso proibido.
- Testar o acesso antes da regra.
- Implementar o bloqueio do destino.
- Repetir o acesso.
- Registrar o resultado.

### Questão de investigação

Explicar por que o bloqueio de um único endereço IP pode não ser suficiente para controlar o acesso a um determinado site ou serviço.

Considerar:

- múltiplos endereços IP;
- mudança de endereços;
- CDNs;
- hospedagem de vários serviços no mesmo IP;
- outros fatores relevantes.

### Evidência

Registrar:

- destino escolhido;
- teste antes;
- regra;
- teste depois;
- análise das limitações.

---

## 4.4 L4 — Bloqueio por TCP/UDP

### Atividades

- Escolher um serviço/porta para representar o cenário proposto.
- Gerar tráfego antes da regra.
- Criar o bloqueio da porta/protocolo.
- Repetir o teste.
- Observar o tráfego quando necessário.

### Questão de investigação

Explicar se bloquear portas é suficiente para impedir uma aplicação como BitTorrent.

Considerar:

- portas alternativas;
- portas dinâmicas;
- múltiplos protocolos;
- possíveis mecanismos de evasão.

### Evidência

Registrar:

**Antes → Regra → Depois → Explicação**

---

# 5. Investigação L7 e Defense in Depth

## 5.1 Investigação L7

### Objetivo

Compreender mecanismos de segurança capazes de analisar informações da camada de aplicação.

### Atividades

Escolher **uma** tecnologia para pesquisa, por exemplo:

- DNS Filtering;
- Proxy;
- WAF;
- Application Firewall;
- NGFW.

### A pesquisa deverá apresentar

- o que é a tecnologia;
- como funciona;
- em que ponto da arquitetura pode ser utilizada;
- quais informações consegue analisar;
- que tipo de controle permite;
- diferença em relação ao controle baseado somente em IP e porta;
- limitações da abordagem.

### Importante

A implementação de L7 **não é obrigatória nesta Task**.

### Entregável

**Breve pesquisa documentada no README.**

---

## 5.2 Defense in Depth

### Objetivo

Analisar o funcionamento conjunto das diferentes camadas de segurança da arquitetura.

### Cenário

Considerar:

> O servidor Web da DMZ foi comprometido.

### Atividades

Analisar se esse comprometimento permitiria automaticamente acesso a:

- `pc1`;
- `pc2`;
- demais recursos da LAN.

Identificar quais controles ainda poderiam limitar o atacante:

- firewall;
- DMZ;
- segmentação de redes;
- regras de filtragem;
- controles dos próprios serviços.

### Entregável

**Explicação de como as diferentes camadas contribuem para o princípio de Defense in Depth.**

---

# 6. Organização e Entrega

### Objetivo

Consolidar todo o trabalho em um único repositório organizado.

### Estrutura sugerida

```text
laboratorio-firewall-dmz/
│
├── README.md
│
├── firewall/
│   ├── rules.sh
│   └── README.md
│
├── evidencias/
│   ├── baseline/
│   ├── l2/
│   ├── l3/
│   └── l4/
│
└── pesquisa/
    └── l7.md
```

> A estrutura pode ser adaptada conforme os arquivos que realmente forem necessários no laboratório.
