# Plano — Kathará (Firewall + DMZ + Defense in Depth)

**Objetivo:** Criar um plano executável para transformar o laboratório-base `firewall-dmz` no Cyber Range da Task (topologia com r0, fw, LAN, DMZ, Internet, gerenciamento opcional), implementar Segurança de Perímetro, experimentos de controle em L2/L3/L4, proposta L7 e evidências para Defense in Depth — sem alterar ainda o código/regras além do plano.

**Arquitetura:** O laboratório usa Kathará (Docker-based) com 6 nós (pc1, pc2, fw, r0, web, dns, adm opcional) interligados via `lab.conf` e `.startup`. A política de firewall será aplicada no nó `fw` (iptables/nftables) com filtragem stateful (New/Established/Related). A topologia já está parcialmente montada (`firewall-dmz/`); o plano mapeia as lacunas (regras de firewall ainda não configuradas) e define o ciclo de experimentos (antes → regra → depois).

**Stack técnico:** Kathará, Linux namespace/Docker, `iptables` (ou `nftables` se disponível em `fw`), `tcpdump`, `ping`, `curl`, `netcat`, `wireshark-cli` (opcional). Endereçamento já definido no `lab.conf` (LAN 10.0.1.0/24, DMZ 10.0.2.0/24, MGMT 10.0.3.0/24, WAN 198.51.100.0/30).

**Especificação de referência:** Documento da Task (figura de topologia + etapas de segurança, experimentos L2/L3/L4/L7, Defense in Depth, entregas, perguntas finais).

---

## Restrições globais

- Reutilizar `firewall-dmz/` como base; não renomear `lab.conf` sem necessidade.
- Endereços trazidos da figura: r0 = `198.51.100.2/30` (bridged), fw = `198.51.100.1/30` (eth3), LAN gw = `10.0.1.1`, DMZ gw = `10.0.2.1`, mgmt gw = `10.0.3.1`. Hosts: pc1 `10.0.1.10`, pc2 `10.0.1.11`, web `10.0.2.10`, dns `10.0.2.11`, adm `10.0.3.10`.
- Regra de primeiro princípio: **Default Deny** (bloquear por padrão) + **menor privilégio** (permitir apenas o necessário, com stateful).
- Todos os experimentos devem gerar evidência simples: `tcpdump` / `ping` / `curl` antes e depois da regra, com prints de saída capturados em `evidencias/` (a ser criado no repo).
- Não implementar L7 no laboratório (apenas pesquisar proposta e apresentar para discussão), conforme instrução da Task.

---

## Estrutura de arquivos a tocar (base existente → evolucionar)

- `firewall-dmz/lab.conf` → já existe; pode adicionar `adm` se necessário.
- `firewall-dmz/fw.startup` → já tem interfaces; precisa receber regras `iptables`/`nftables`.
- `firewall-dmz/r0.startup` → já tem rotas; validar acesso à Internet.
- `firewall-dmz/pc1.startup` / `pc2.startup` / `web.startup` / `dns.startup` / `adm.startup` → validar rotas default e serviços (DNS, HTTP).
- Criar `firewall-dmz/regras/` (ou `regras-iptables.md`) → organizar as regras com comentários por camada.
- Criar `evidencias/` → antes/depois por experimento.
- Criar `README.md` atualizado na raiz com política, experimentos e respostas.

---

## Tarefas (checklist por etapa)

### Tarefa 1 — Confirmação da topologia e baseline de conectividade

- [ ] Verificar `kathara lstart` roda sem falha com `lab.conf` atual.
- [ ] Confirmar que `pc1` e `pc2` atingem Internet via `r0` (ping 8.8.8.8, curl).
- [ ] Confirmar LAN → DMZ (`pc1` → `web` e `dns`) funciona.
- [ ] Confirmar `web` (HTTP) e `dns` (DNS resolver) respondem corretamente.
- [ ] Documentar baseline (`evidencias/01-baseline/`).

### Tarefa 2 — Política de Segurança de Perímetro no `fw`

- [ ] Criar arquivo `firewall-dmz/regras/perimetro.sh` com política stateful:
  - LAN → Internet ✅ (ALLOW NEW,ESTABLISHED,RELATED)
  - LAN → DMZ (Web/DNS) ✅
  - Internet → Web (DMZ) ✅ (apenas portas 80/443, NEW)
  - Internet → LAN ❌ DENY (NEW)
  - DMZ → LAN (novo) ❌ DENY (NEW)
  - Respostas de conexões já permitidas ✅ (ESTABLISHED,RELATED)
- [ ] Aplicar regras no `fw.startup` (ou via `kathara exec fw` após start) e validar com `iptables -L -v -n`.
- [ ] Testar cada fluxo e salvar prints `evidencias/02-perimetro/`.

### Tarefa 3 — Controle de camada L2 (Enlace / MAC)

- [ ] Identificar MAC de `pc2` (ex.: `ip link show eth0`).
- [ ] Criar regra `iptables -A INPUT -m mac --mac-source <MAC_pc2> -j DROP` (e/ou `FORWARD`) no `fw`.
- [ ] Comparar `pc1` (funciona) vs `pc2` (bloqueado) com `ping` e `tcpdump -i eth1` / `eth2`.
- [ ] Responder investigação: MAC acompanha pacote só no mesmo segmento L2; roteadores substituem MAC de origem. O firewall `fw` vê o MAC original de `pc2` apenas nas interfaces LAN/DMZ (`eth1`/`eth2`), não na WAN (`eth3`).
- [ ] Salvar `evidencias/03-l2/`.

### Tarefa 4 — Controle de camada L3 (Rede / IP e ICMP)

- **4A — ICMP:** Criar regra bloqueando ICMP (ex.: `-p icmp -j DROP` ou `-p icmp --icmp-type echo-request -j DROP` entre redes). Demonstrar com `ping` + `tcpdump`. Explicar que bloqueio de ICMP não impede tráfego TCP/UDP, apenas descoberta de rede.
- **4B — Destino IP proibido:** Escolher IP de controle no laboratório (ex.: criar `servidor-proibido` em outra rede ou usar IP fictício `10.99.99.99` via interface dummy). Criar regra `-d 10.99.99.99 -j DROP`. Demonstrar que acesso falha. Responder: bloquear IP é incompleto — domínios têm múltiplos IPs, um IP pode hospedar vários sites, CDNs alteram IPs; melhor combinar com filtros de domínio/proxy.
- [ ] Salvar `evidencias/04-l3/`.

### Tarefa 5 — Controle de camada L4 (Transporte / Portas)

- [ ] Definir política anti-P2P: bloquear portas comuns de BitTorrent (ex.: TCP 6881-6889, UDP 6881-6889) e/ou 6969, 443 (opcional, mas cuidado com HTTPS legítimo — para demonstração usar portas de teste como 6881-6889).
- [ ] Criar `regras/bitTorrent.sh` com `-p tcp --dport 6881:6889 -j DROP` e equivalente UDP.
- [ ] Gerar tráfego de teste com `nc -vz <alvo> 6881` (antes e depois) para demonstrar bloqueio.
- [ ] Responder investigação: bloquear portas não é suficiente — BitTorrent usa portas dinâmicas (DHT, uTP) e pode usar portas comuns (802, 443); precisa de inspeção de protocolo/stream ou NGFW.
- [ ] Salvar `evidencias/05-l4/`.

### Tarefa 6 — Proposta de controle L7 (Aplicação)

- [ ] Pesquisar: DNS Filtering (OpenDNS/NextDNS), Proxy HTTP(S) com filtragem de URL (`squid`/`tinyproxy` + listas ACL), WAF (`modsecurity`/`nginx`), NGFW (com inspeção de aplicação, ex.: `Suricata` + `Snort` com regras de conteúdo, ou `pfSense`/`OPNsense` com layer-7).
- [ ] Escolher uma proposta (recomendado: **DNS Filtering + Proxy com ACL por domínio/categoria**, como controle simples que pode ser simulado com `dnsmasq` + `squid` no `fw` ou `web`). Explicar brevemente como funciona (intercepta resolução DNS ou HTTP e compara contra lista de bloqueios/categorias).
- [ ] Documentar proposta no `README.md` (seção L7) e preparar slides/note para discussão em aula; NÃO implementar no lab.
- [ ] Salvar `evidencias/06-l7/` (pesquisa + explicação).

### Tarefa 7 — Defense in Depth (análise arquitetural)

- [ ] Revisar topologia completa: `fw` (perímetro) + `r0` (NAT/roteamento) + `DMZ` (segmentação) + `LAN` (isolada) + `regras` (filtragem) + `controles nos serviços` (ex.: `web` apenas HTTP/HTTPS, `dns` apenas 53, `adm` restrito).
- [ ] Cenario: `web` (DMZ) comprometido → atacante acessa `pc1`/`pc2`?
  - **Não diretamente** se `fw` bloqueia DMZ→LAN (NEW) e LAN→DMZ é permitido apenas para respostas.
  - Mas se `fw` falhar (ex.: regra removida), ainda há: segmentação física (diferentes interfaces/bridges), NAT no `r0` (IP privado não exposto), controle nos serviços (ex.: `web` não tem shell aberto), possivelmente `adm` isolado.
- [ ] Responder as 3 perguntas finais:
  1. Quem pode se comunicar com quem? LAN ↔ Internet (sim, via fw); LAN ↔ DMZ (sim, para serviços públicos); Internet → DMZ Web (sim, para 80/443); Internet → LAN (não); DMZ → LAN (não, novas conexões); DMZ ↔ DMZ (sim, interno); LAN → LAN (sim, L2); MGMT → fw (sim, para gestão, restrito).
  2. Que tipos permitidos/bloqueados? Estado de conexão (stateful) -> new/established/related. Permitido: HTTP/HTTPS da LAN para Internet; HTTP/HTTPS da Internet para DMZ; DNS; respostas. Bloqueado: ICMP inter-rede (opcional); BitTorrent (L4); MAC de `pc2`; IP proibido; novas conexões DMZ→LAN.
  3. Se uma camada falhar? Se `fw` falhar: `r0` ainda faz NAT (não expõe LAN diretamente); `DMZ` ainda é rede separada (não há rota direta LAN↔DMZ sem `fw`); serviços `web`/`dns` podem ter ACLs locais; `adm` isolado pode limitar acesso; regras do host `web`/`dns` podem restringir conexões internas.
- [ ] Documentar no `README.md`.

---

## Entregáveis do plano (para quando o usuário aprovar execução)

- Repositório Git com `firewall-dmz/` evoluído.
- `regras/` organizadas e comentadas (`perimetro.sh`, `l2-mac.sh`, `l3-icmp.sh`, `l3-ip-proibido.sh`, `l4-p2p.sh`).
- `README.md` atualizado (política, experimentos, evidências, respostas às 3 perguntas, proposta L7, Defense in Depth).
- `evidencias/` com antes/depois para L2, L3-A, L3-B, L4, baseline.
- Se necessário, `docs/superpowers/plans/` (este arquivo) atualizado conforme avanços.

---

## Observações / Riscos

- A base `firewall-dmz/` já tem interfaces configuradas; a regra de firewall deve ser aplicada no `fw.startup` para persistir entre `lstart`.
- Captura de tráfego (`tcpdump`) deve ser feita no nó correto (`fw` para entre redes; `pc2` para origem). Em containers, `tcpdump` pode exigir privilégios (`--privileged` no Kathará, já comum).
- L7 não será implementado, apenas pesquisado; manter documentação clara para discussão.

---
