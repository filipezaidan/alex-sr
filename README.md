# 🛡️ Cyber Range — Firewall + DMZ + Defense in Depth

> Laboratório experimental em Kathará para conceitos fundamentais de Cibersegurança: Segurança de Perímetro, DMZ, filtragem de tráfego, controles em L2/L3/L4 e Defense in Depth.

**Instituto Federal de Alagoas — Segurança de Redes**  
*Atividade de laboratório (base `firewall-dmz/` + plano executável em `firewall-dmz/docs/plan.md`).*

---

## 📋 Sobre o projeto

Este repositório monta uma topologia completa de rede com **borda, firewall, LAN, DMZ e gerenciamento** usando o simulador **Kathará** (Docker-based). A ideia é transformar o laboratório-base em um pequeno **Cyber Range**: primeiro estabelecer conectividade (baseline), depois aplicar uma política de **Default Deny / Menor Privilégio** no nó `fw`, e finalmente experimentar como decisões de segurança podem usar informações de **diferentes camadas TCP/IP**.

> **Nota:** O plano executável está em `firewall-dmz/docs/plan.md` (todas as 7 tarefas, evidências e respostas). Este README é o guia de entrada.

---

## 🏗️ Arquitetura (topologia simplificada)

```text
Internet ───(WAN 198.51.100.0/30)───▶ r0 (NAT / Bordas)
                                      │
                                      ▼
                              fw (Firewall / Middlebox)
                         ┌──────┬──────┬──────┐
                         │      │      │      │
                      eth0    eth1   eth2    eth3
                      LAN     DMZ   MGMT     WAN
                  (10.0.1/24)(10.0.2/24)(10.0.3/24)(198.51.100/30)
                         │      │
                         ▼      ▼
                        pc1    web  (DMZ 10.0.2.10)
                        pc2    dns  (DMZ 10.0.2.11)
                  (LAN 10.0.1.10/11)
```

| Nó | Rede / Função | IP (ex.) | Observação |
|---|---|---|---|
| `r0` | Borda / NAT | `198.51.100.2/30` | `bridged=true`, roteia para Internet |
| `fw` | Firewall / Middlebox | `10.0.1.1`, `10.0.2.1`, `10.0.3.1`, `198.51.100.1` | `iptables`/`nftables` com filtragem stateful |
| `pc1`, `pc2` | LAN | `10.0.1.10` / `.11` | Clientes internos |
| `web` | DMZ — HTTP/HTTPS | `10.0.2.10` | Servidor público |
| `dns` | DMZ — DNS | `10.0.2.11` | Resolver de nomes |
| `adm` *(opcional)* | Gestão / MGMT | `10.0.3.10` | Acesso restrito ao `fw` |

> **Configuração:** `firewall-dmz/lab.conf` + arquivos `.startup` (endereçamento + rotas default via `gw`).

---

## 🚀 Quick Start

```bash
# 1. Subir o laboratório (do diretório do repo)
kathara lstart firewall-dmz

# 2. Acessar um nó
kathara lenter firewall-dmz fw

# 3. Verificar conectividade (baseline)
ping -c 3 8.8.8.8      # LAN → Internet
ping -c 3 10.0.2.10    # LAN → DMZ (web)
curl -I http://10.0.2.10
```

Para parar: `kathara lstop firewall-dmz`

---

## 🔐 Segurança de Perímetro (política implementável)

| Comunicação | Política | Como testar |
|---|---|---|
| LAN → Internet | ✅ Permitir | `ping 8.8.8.8` |
| LAN → DMZ (Web/DNS) | ✅ Permitir | `curl http://10.0.2.10` |
| Internet → Web (DMZ) | ✅ Permitir | `curl http://198.51.100.1` (via `r0`) |
| Internet → LAN | ❌ Bloquear | `ping 10.0.1.10` de fora |
| DMZ → LAN (nova) | ❌ Bloquear | `ssh 10.0.1.10` a partir de `web` |
| Respostas | ✅ Permitir | `ESTABLISHED,RELATED` (stateful) |

A implementação está prevista no arquivo `firewall-dmz/regras/perimetro.sh` (não ainda aplicada no `fw.startup` — ver plano para sequência).

---

## 🔬 Experimentos por Camada (ciclo: tráfego → observa → regra → retesta → explica)

| Camada | Controle | Como funciona | Evidência |
|---|---|---|---|
| **L2 — Enlace** | MAC (`pc2`) | `iptables -m mac --mac-source <MAC>` no `fw` | `tcpdump` + `ping` antes/depois |
| **L3 — Rede** | ICMP | Bloqueio `-p icmp`; destino proibido `-d <IP>` | `ping` + `tcpdump`; discussão sobre IP dinâmico/CDN |
| **L4 — Transporte** | P2P / portas | `-p tcp --dport 6881:6889 -j DROP` | `nc -vz <alvo> 6881`; discussão sobre portas dinâmicas |
| **L7 — Aplicação** | *Pesquisa* (não implementado) | DNS Filtering / Proxy ACL / WAF / NGFW | Explicação breve para discussão em aula |

> Todos os testes geram evidências simples em `evidencias/`. Veja `firewall-dmz/docs/plan.md` para detalhes completos.

---

## 🧱 Defense in Depth

Se o servidor `web` (DMZ) for comprometido, **o atacante não acessa `pc1`/`pc2` diretamente** se o `fw` estiver operando com `DMZ → LAN (NEW) = DENY`. Mesmo se `fw` falhar:

- **Segmentação física:** `DMZ` e `LAN` estão em interfaces separadas (`fw eth1` / `eth2`).
- **NAT no `r0`:** IPs internos não são expostos diretamente à Internet.
- **Controles nos serviços:** `web` pode restringir conexões internas; `dns` só responde à porta 53.
- **Gestão isolada:** `adm` está em `MGMT` (`10.0.3.0/24`), limitando acesso ao `fw`.

> **Princípio:** nenhuma barreira única é suficiente. Se uma camada falha, outras ainda limitam o ataque.

---

## ❓ Três perguntas finais (respostas resumidas)

1. **Quem pode se comunicar com quem?**  
   LAN ↔ Internet (sim, via `fw`); LAN ↔ DMZ (sim); Internet → DMZ Web (sim, 80/443); Internet → LAN (não); DMZ → LAN (novo: não); DMZ ↔ DMZ (sim, interno); LAN ↔ LAN (sim, L2).

2. **Quais comunicações são permitidas / bloqueadas?**  
   Permitido: HTTP/HTTPS (LAN→Internet, Internet→DMZ), DNS, respostas stateful (`ESTABLISHED`). Bloqueado: novas conexões DMZ→LAN, ICMP inter-rede (opcional), BitTorrent (L4), tráfego de MAC de `pc2` (L2), acesso a IP proibido (L3).

3. **Se uma camada de segurança falhar?**  
   `fw` falha → `r0` ainda faz NAT; `DMZ` ainda é rede separada; hosts `web`/`dns` podem ter ACLs locais; `adm` isolado limita gestão; segmentação impede acesso direto sem `fw`.

---

## 📂 Arquivos principais

| Caminho | Descrição |
|---|---|
| `firewall-dmz/lab.conf` | Topologia Kathará (LAN A, DMZ B, MGMT C, WAN D) |
| `firewall-dmz/*.startup` | Configuração de rede (IP, rotas default) por nó |
| `firewall-dmz/docs/plan.md` | Plano executável (tarefas 1–7, evidências, respostas) |
| `README.md` | Este arquivo — guia de entrada |

---

## 📊 Status do laboratório

- [x] Base de topologia (`lab.conf` + `.startup`) montada  
- [x] Plano executável documentado (`docs/plan.md`)  
- [ ] Regras de firewall aplicadas (Tarefa 2)  
- [ ] Experimentos L2 / L3 / L4 executados (Tarefas 3–5)  
- [ ] Proposta L7 pesquisada (Tarefa 6)  
- [ ] Defense in Depth documentado (Tarefa 7)  
- [ ] `README.md` atualizado (este arquivo)  

> **Contribuição:** Se você está executando a Task, siga as tarefas do `plan.md` em ordem, crie evidências simples (`tcpdump`, `ping`, `curl`) e atualize os checkboxes acima.

---

*Criado como parte da atividade de Segurança de Redes — IFAL / Maceió. Não contém implementações de firewall ainda (baseline + plano); a execução é intencionalmente separada para que cada experimento tenha sua evidência.*
