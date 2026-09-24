# 🛡️ Firewall + DMZ: Segurança de Perímetro e Defense in Depth

> Laboratório Kathará que implementa um Cyber Range para experimentar conceitos fundamentais de Cibersegurança: Segurança de Perímetro, Firewall, DMZ, segmentação de redes, Default Deny, controles em diferentes camadas TCP/IP e Defense in Depth.

**Instituto Federal de Alagoas — Segurança de Redes**

---

## Índice

1. [Topologia e Endereçamento](#1-topologia-e-endereçamento)
2. [Como executar](#2-como-executar)
3. [Segurança de Perímetro](#3-segurança-de-perímetro)
4. [Experimentos por Camada](#4-experimentos-por-camada)
   - [L2 — Enlace (bloqueio por MAC)](#l2--enlace-bloqueio-por-mac)
   - [L3 — Rede (ICMP e bloqueio por IP)](#l3--rede-icmp-e-bloqueio-por-ip)
   - [L4 — Transporte (bloqueio de portas)](#l4--transporte-bloqueio-de-portas)
   - [L7 — Aplicação (proposta WAF)](#l7--aplicação-proposta-waf)
5. [Defense in Depth](#5-defense-in-depth)
6. [Três perguntas finais](#6-três-perguntas-finais)
7. [Estrutura do repositório](#7-estrutura-do-repositório)

---

## 1. Topologia e Endereçamento

```
                         ┌──────────────┐
                         │   Internet   │
                         └──────┬───────┘
                                │  eth1 (bridged)
                         ┌──────┴───────┐
                         │      r0      │
                         │  (NAT/Borda) │
                         └──────┬───────┘
                                │  eth0  198.51.100.2/30
                                │
                                │  198.51.100.0/30
                                │
                                │  eth3  198.51.100.1/30
                     ┌──────────┴──────────┐
                     │         fw          │
                     │  (Firewall/iptables) │
                     ├─────┬───────┬───────┤
                     │eth0 │ eth1  │ eth2  │
                     └──┬──┴───┬───┴───┬───┘
                        │      │       │
           10.0.1.0/24  │      │       │  10.0.3.0/24
              (LAN)     │      │       │    (MGMT)
                        │      │       │
                   ┌────┤      │       └────┐
                   │    │      │            │
                ┌──┴──┐┌┴──┐   │         ┌──┴──┐
                │ pc1 ││pc2│   │         │ adm │
                │ .10 ││.11│   │         │ .10 │
                └─────┘└───┘   │         └─────┘
                               │
                          10.0.2.0/24
                             (DMZ)
                               │
                          ┌────┴────┐
                          │         │
                       ┌──┴──┐  ┌──┴──┐
                       │ web │  │ dns │
                       │ .10 │  │ .11 │
                       └─────┘  └─────┘
```

### Plano de Endereçamento

| Dispositivo | Interface | Rede | Endereço IP | Função |
|---|---|---|---|---|
| `r0` | `eth0` | WAN (D) | `198.51.100.2/30` | Roteador de borda / NAT |
| `r0` | `eth1` | — | bridged | Acesso à Internet real |
| `fw` | `eth0` | LAN (A) | `10.0.1.1/24` | Gateway da LAN |
| `fw` | `eth1` | DMZ (B) | `10.0.2.1/24` | Gateway da DMZ |
| `fw` | `eth2` | MGMT (C) | `10.0.3.1/24` | Gateway de gerenciamento |
| `fw` | `eth3` | WAN (D) | `198.51.100.1/30` | Link com o roteador de borda |
| `pc1` | `eth0` | LAN (A) | `10.0.1.10/24` | Estação de trabalho |
| `pc2` | `eth0` | LAN (A) | `10.0.1.11/24` | Estação de trabalho |
| `web` | `eth0` | DMZ (B) | `10.0.2.10/24` | Servidor Web |
| `dns` | `eth0` | DMZ (B) | `10.0.2.11/24` | Servidor DNS |
| `adm` | `eth0` | MGMT (C) | `10.0.3.10/24` | Estação de gerenciamento |

### Roteamento

- **`r0`**: faz NAT (`MASQUERADE`) na interface `eth1` e possui rotas estáticas para as redes internas via `198.51.100.1` (o firewall).
- **`fw`**: gateway padrão apontando para `198.51.100.2` (o `r0`). Encaminha pacotes entre todas as interfaces.
- **Demais hosts**: gateway padrão apontando para a interface correspondente do `fw`.

---

## 2. Como executar

```bash
# Subir o laboratório
kathara lstart

# Acessar um nó específico
kathara connect fw
kathara connect pc1

# Parar o laboratório
kathara lclean
```

### Validação inicial (baseline)

Após subir o laboratório, os seguintes testes devem funcionar:

```bash
# No pc1 — LAN → Internet
ping -c 3 8.8.8.8
curl https://example.com

# No pc1 — LAN → DMZ
ping -c 3 10.0.2.10    # web
ping -c 3 10.0.2.11    # dns

# No web — iniciar servidor HTTP temporário
python3 -m http.server 80

# No r0 — Internet → Web da DMZ
curl -I --max-time 5 http://10.0.2.10
```

---

## 3. Segurança de Perímetro

O firewall `fw` implementa a política de perímetro na cadeia `FORWARD` do `iptables`, adotando o princípio **Default Deny** (bloquear por padrão, permitir explicitamente).

### Política implementada

| Comunicação | Política | Justificativa |
|---|---|---|
| LAN → Internet | ✅ Permitir | Estações precisam acessar recursos externos |
| LAN → Web/DNS da DMZ | ✅ Permitir | Estações precisam acessar serviços internos da DMZ |
| Internet → Web da DMZ (TCP/80) | ✅ Permitir | O servidor Web deve ser acessível externamente |
| Internet → LAN | ❌ Bloquear | Hosts internos não devem ser acessíveis da Internet |
| DMZ → LAN (novas conexões) | ❌ Bloquear | A DMZ não deve iniciar conexões para a rede interna |
| Respostas de conexões permitidas | ✅ Permitir | Filtragem stateful via `conntrack` |

### Regras do iptables (`fw.startup`)

```bash
# 1. Respostas de conexões já estabelecidas (stateful)
iptables -A FORWARD -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# 2. Novas conexões da LAN para a Internet
iptables -A FORWARD -i eth0 -o eth3 -m conntrack --ctstate NEW -j ACCEPT

# 3. Novas conexões da LAN para a DMZ
iptables -A FORWARD -i eth0 -o eth1 -m conntrack --ctstate NEW -j ACCEPT

# 4. Novas conexões da Internet para o Web da DMZ (somente HTTP)
iptables -A FORWARD -i eth3 -o eth1 -p tcp --dport 80 -m conntrack --ctstate NEW -j ACCEPT

# 5. Política padrão: bloquear todo o resto
iptables -P FORWARD DROP
```

### Mapeamento de interfaces

| Interface | Rede | Sub-rede |
|---|---|---|
| `eth0` | LAN | `10.0.1.0/24` |
| `eth1` | DMZ | `10.0.2.0/24` |
| `eth2` | MGMT | `10.0.3.0/24` |
| `eth3` | WAN | `198.51.100.0/30` |

### Evidências

Todos os fluxos foram testados e validados. Estado final da cadeia `FORWARD`:

```
Chain FORWARD (policy DROP 8 packets, 672 bytes)
num   pkts bytes target   prot  in    out    observação
1       31  2522 ACCEPT   all   *     *      ctstate RELATED,ESTABLISHED
2        1    84 ACCEPT   all   eth0  eth3   ctstate NEW
3        2   168 ACCEPT   all   eth0  eth1   ctstate NEW
4        1    60 ACCEPT   tcp   eth3  eth1   tcp dpt:80 ctstate NEW
```

- **8 pacotes DROP**: correspondem a dois pings bloqueados (Internet → LAN e DMZ → LAN), 4 pacotes cada.
- **Regra 1**: respostas stateful passaram com sucesso.
- **Regra 2**: LAN → Internet (`ping 8.8.8.8` e `curl example.com`).
- **Regra 3**: LAN → DMZ (`ping` para `web` e `dns`).
- **Regra 4**: Internet → Web na porta 80 (`curl` do `r0` retornou `HTTP 200`).

> Evidências detalhadas com capturas de tela em [`steps/firewall/evidencias.md`](steps/firewall/evidencias.md).

---

## 4. Experimentos por Camada

Cada experimento segue o ciclo: **Gerar tráfego → Observar → Aplicar regra → Testar novamente → Explicar**.

As regras dos experimentos foram inseridas ao vivo com `iptables -I` e **não fazem parte do `fw.startup`** (são temporárias para demonstração).

---

### L2 — Enlace: bloqueio por MAC

**Cenário**: `pc2` foi identificado como dispositivo comprometido.

**MAC do `pc2`**: `a2:a4:ee:d1:e3:b6`

#### Antes da regra

`pc1` e `pc2` acessam a DMZ normalmente:

```bash
# Em pc1 e pc2
ping -c 4 10.0.2.10   # 0% perda em ambos
```

#### Regra aplicada

```bash
# No fw — inserida no topo da cadeia para ser avaliada antes dos ACCEPT
iptables -I FORWARD 1 -m mac --mac-source a2:a4:ee:d1:e3:b6 -j DROP
```

#### Depois da regra

| Host | Destino | Resultado |
|---|---|---|
| `pc2` | `10.0.2.10` (DMZ) | ❌ 100% perda |
| `pc2` | `8.8.8.8` (Internet) | ❌ 100% perda |
| `pc1` | `10.0.2.10` (DMZ) | ✅ 0% perda |
| `pc1` | `8.8.8.8` (Internet) | ✅ 0% perda |

O `tcpdump -eni eth0 icmp` capturou os pacotes do `pc2` chegando ao `fw`, mas o `tcpdump -eni eth3 icmp` não mostrou nenhum pacote do `pc2` saindo — confirmando o descarte.

#### Questões de investigação

**O endereço MAC acompanha um pacote durante todo o percurso pela Internet?**
**Não.** O MAC opera na camada de enlace (L2) e é válido apenas no enlace local. Ao atravessar um roteador ou firewall (L3), o quadro Ethernet original é descartado e um novo é montado, com o MAC do próprio dispositivo como origem e o MAC do próximo salto como destino.

**Em quais condições o firewall enxerga o MAC original de `pc2`?**
Apenas quando `pc2` e `fw` pertencem ao mesmo domínio de broadcast (mesma rede local / VLAN conectada à `eth0`). Se houvesse um roteador intermediário, o `fw` veria apenas o MAC desse roteador.

> Evidências detalhadas em [`steps/l2/evidencias.md`](steps/l2/evidencias.md).

---

### L3 — Rede: ICMP e bloqueio por IP

#### Experimento A — Bloqueio de ICMP

**Antes da regra**: `pc1` pinga `10.0.2.10` com 0% de perda.

**Regra aplicada**:

```bash
iptables -I FORWARD 1 -i eth0 -o eth1 -p icmp -j DROP
```

**Depois da regra**: `ping` do `pc1` para `10.0.2.10` → 100% de perda.

**Observação com `tcpdump`**:
- `tcpdump -ni eth0 icmp` → capturou os echo requests chegando da LAN.
- `tcpdump -ni eth1 icmp` → **nenhum pacote** saiu para a DMZ.

O pacote ICMP entra no `fw` pela `eth0`, casa com a regra de DROP e é descartado antes de ser encaminhado. A DMZ nem toma conhecimento da requisição.

#### Experimento B — Bloqueio por IP de destino

**Destino proibido**: `8.8.8.8` (representando um recurso externo proibido pela organização).

**Antes da regra**: `ping -c 4 8.8.8.8` → 0% de perda.

**Regra aplicada**:

```bash
iptables -I FORWARD 1 -i eth0 -d 8.8.8.8 -j DROP
```

**Depois da regra**: `ping -c 4 8.8.8.8` → 100% de perda.

**Isolamento**: com a regra ativa, `ping -c 4 10.0.2.10` (DMZ) continua funcionando normalmente — o bloqueio é seletivo para o destino `8.8.8.8`.

#### Questão de investigação

**Bloquear o IP é uma boa solução para impedir o acesso a um site?**
**Não é suficiente.** Motivos:

- Um domínio pode resolver para **múltiplos endereços IP** (DNS round robin, anycast).
- Os endereços **mudam com o tempo**; uma alteração no DNS torna a regra obsoleta.
- Sites em **CDNs** (Cloudflare, Akamai) compartilham IPs com muitos outros serviços.
- Um mesmo IP pode hospedar **diversos sites** (virtual hosting via HTTP Host/TLS SNI); bloquear o IP bloqueia todos.

Para controlar o acesso por nome de domínio, é necessário inspeção na camada de aplicação (filtro DNS, proxy HTTP/HTTPS ou NGFW).

> Evidências detalhadas em [`steps/l3/evidencias.md`](steps/l3/evidencias.md).

---

### L4 — Transporte: bloqueio de portas (BitTorrent)

**Cenário**: a organização proíbe serviços P2P como BitTorrent. A faixa de portas TCP padrão do BitTorrent é `6881–6889`.

#### Antes da regra

No `web`, dois servidores HTTP temporários para validação:

```bash
python3 -m http.server 6881   # dentro da faixa bloqueada
python3 -m http.server 8080   # fora da faixa (controle)
```

No `pc1`:

```bash
curl -I --max-time 5 http://10.0.2.10:6881   # HTTP 200 OK
curl -I --max-time 5 http://10.0.2.10:8080   # HTTP 200 OK
```

#### Regra aplicada

```bash
iptables -I FORWARD 1 -p tcp --dport 6881:6889 -j DROP
```

#### Depois da regra

| Porta | Resultado |
|---|---|
| `6881` | ❌ Tempo esgotado (SYN descartado pelo `fw`) |
| `8080` | ✅ `HTTP 200 OK` |

O contadores no `fw` confirmaram que a regra capturou os pacotes destinados à faixa bloqueada.

#### Questão de investigação

**Bloquear portas é suficiente para impedir o BitTorrent?**
**Não.** Motivos:

- O cliente pode usar **qualquer porta TCP**, não apenas a faixa 6881–6889 (que é apenas o padrão antigo).
- As portas de dados são **dinâmicas** — cada par negocia portas altas na conexão.
- O BitTorrent também usa **UDP** (protocolo uTP); uma regra `-p tcp` não afeta UDP.
- O tráfego pode sair pelas **portas 80 ou 443**, que a política de perímetro permite, ou usar **ofuscação** para não parecer BitTorrent.

Bloquear portas identifica o transporte, não a aplicação. Conter o BitTorrent pelo comportamento exige inspeção de camada de aplicação (NGFW, DPI).

> Evidências detalhadas em [`steps/l4/evidencias.md`](steps/l4/evidencias.md).

---

### L7 — Aplicação: proposta WAF

**Tecnologia pesquisada**: **WAF (Web Application Firewall)**

O WAF opera na camada de aplicação (L7), posicionando-se entre o cliente e o servidor Web. Diferente das camadas anteriores, ele analisa o **conteúdo da requisição HTTP/HTTPS**.

**O que consegue fazer**:

| Capacidade | Exemplo |
|---|---|
| Controle por URL | Permitir `/public`, bloquear `/admin` |
| Detecção de ataques | Identificar SQL Injection, XSS, CSRF |
| Filtro por método HTTP | Bloquear `DELETE` ou `PUT` em endpoints públicos |
| Inspeção de payload | Analisar o corpo da requisição |

**Diferença em relação às camadas anteriores**:

```
L2 → decide com base no MAC
L3 → decide com base no IP
L4 → decide com base no protocolo e porta
L7 → decide com base na requisição e no comportamento da aplicação
```

**Limitações**: o WAF precisa compreender o protocolo da aplicação; tráfego criptografado (HTTPS) requer terminação TLS no WAF; pode gerar falsos positivos em aplicações complexas.

> Pesquisa completa em [`steps/l7/controle-waf.md`](steps/l7/controle-waf.md).

---

## 5. Defense in Depth

### Cenário: o servidor Web da DMZ foi comprometido

**O atacante consegue acessar diretamente `pc1` e `pc2`?**

**Não.** A DMZ e a LAN são redes segmentadas, e múltiplas camadas de proteção continuam operando:

| Camada de proteção | Como limita o atacante |
|---|---|
| **Firewall (iptables)** | Política `DROP` no `FORWARD`. Não existe regra `ACCEPT` para novas conexões de `eth1` (DMZ) para `eth0` (LAN). |
| **Segmentação de redes** | `web` está em `10.0.2.0/24` (DMZ), `pc1`/`pc2` estão em `10.0.1.0/24` (LAN). Redes separadas, sem conectividade direta. |
| **Filtragem stateful** | A regra `ESTABLISHED,RELATED` permite apenas respostas de conexões já autorizadas. Não permite ao `web` iniciar uma conexão contra a LAN. |
| **Controles nos hosts** | `pc1` e `pc2` podem ter firewall local, autenticação e outras restrições independentes. |
| **Rede de gerenciamento isolada** | `adm` está em `10.0.3.0/24` (MGMT), limitando o acesso administrativo ao `fw`. |

### Fluxo do ataque (bloqueado)

```
Internet
   ↓
   r0 (NAT)
   ↓
   fw (Firewall)
   ↓
   DMZ
   ↓
   web comprometido
   ↓
   ✖  ← nova conexão DMZ → LAN bloqueada pelo fw (policy DROP)
   ↓
   LAN (pc1 / pc2) — protegida
```

### Princípio

**Defense in Depth** significa **não depender de uma única barreira**. Mesmo que o servidor Web seja comprometido, a **segmentação da rede**, o **firewall**, as **regras de filtragem stateful** e os **controles nos próprios hosts** continuam funcionando como camadas adicionais de proteção. Se uma camada falha, as outras ainda limitam o ataque.

> Análise completa em [`steps/defense-in-depth/doc.md`](steps/defense-in-depth/doc.md).

---

## 6. Três perguntas finais

### 1. Quem pode se comunicar com quem?

| Origem | Destino | Permitido? |
|---|---|---|
| LAN (`pc1`, `pc2`) | Internet | ✅ Sim |
| LAN (`pc1`, `pc2`) | DMZ (`web`, `dns`) | ✅ Sim |
| Internet | Web da DMZ (TCP/80) | ✅ Sim |
| Internet | LAN | ❌ Não |
| DMZ | LAN (novas conexões) | ❌ Não |
| LAN ↔ LAN | `pc1` ↔ `pc2` | ✅ Sim (mesmo segmento L2) |

### 2. Que tipos de comunicação são permitidos ou bloqueados?

**Permitidos**:
- HTTP/HTTPS da LAN para a Internet
- Qualquer protocolo da LAN para a DMZ
- HTTP (TCP/80) da Internet para o `web` da DMZ
- Respostas stateful (`ESTABLISHED`, `RELATED`) de qualquer conexão autorizada

**Bloqueados**:
- Novas conexões da Internet para a LAN
- Novas conexões da DMZ para a LAN
- Todo tráfego não explicitamente autorizado (política `DROP`)
- MAC do `pc2` (quando regra L2 ativa)
- ICMP LAN → DMZ (quando regra L3 ativa)
- Destino `8.8.8.8` (quando regra L3 ativa)
- Portas TCP 6881–6889 (quando regra L4 ativa)

### 3. Se uma camada de segurança falhar, quais outras ainda protegem?

| Se falhar... | Ainda protege... |
|---|---|
| Firewall (`fw`) | NAT no `r0`, segmentação física das redes, controles locais nos hosts |
| Regra de filtragem específica | Política padrão `DROP` continua bloqueando tudo que não tem regra |
| Servidor Web comprometido | Firewall bloqueia DMZ → LAN, segmentação impede acesso direto, hosts têm autenticação |
| Bloqueio por IP (L3) | Bloqueio por porta (L4) e controle por MAC (L2) continuam independentes |
| Controle de porta (L4) | WAF/Proxy (L7) pode identificar a aplicação independentemente da porta |

---

## 7. Estrutura do repositório

```
.
├── README.md                    # Este documento
├── lab.conf                     # Topologia Kathará
├── fw.startup                   # Configuração do firewall (IP + iptables)
├── r0.startup                   # Configuração do roteador de borda (IP + NAT)
├── pc1.startup                  # Configuração do pc1
├── pc2.startup                  # Configuração do pc2
├── web.startup                  # Configuração do servidor web
├── dns.startup                  # Configuração do servidor DNS
├── adm.startup                  # Configuração da estação de gerenciamento
├── docs/
│   ├── plan.md                  # Plano de execução das tarefas
│   └── topologia.png            # Imagem da topologia
└── steps/
    ├── firewall/
    │   ├── evidencias.md        # Evidências do firewall de perímetro
    │   └── *.png                # Capturas de tela
    ├── l2/
    │   └── evidencias.md        # Evidências do bloqueio por MAC
    ├── l3/
    │   ├── evidencias.md        # Evidências de ICMP e bloqueio por IP
    │   └── *.png                # Capturas de tela
    ├── l4/
    │   ├── evidencias.md        # Evidências do bloqueio por porta
    │   └── *.png                # Capturas de tela
    ├── l7/
    │   └── controle-waf.md      # Pesquisa sobre WAF (L7)
    └── defense-in-depth/
        └── doc.md               # Análise de Defense in Depth
```

---

*Laboratório desenvolvido como parte da atividade de Segurança de Redes — IFAL. Executável com `kathara lstart`.*
