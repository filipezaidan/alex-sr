# 01 — Baseline de conectividade (Tarefa 1)

**Data:** 2026-09-23 · **Lab:** `firewall-dmz` (Kathara 3.8.3, Docker)
**Método:** `kathara lclean` + `kathara lstart` (partida fria) → testes via `docker exec`.

## Checklist

| # | Verificação | Resultado | Evidência |
|---|---|---|---|
| 1 | `kathara lstart` roda sem falha com o `lab.conf` atual | ✅ exit=0, 7/7 devices, 0 errors | `01-lstart.log` |
| 2a | `pc1` → Internet (ping 8.8.8.8) | ✅ 0% loss, ~68 ms | `02-pc1-internet.txt` |
| 2b | `pc1` → Internet (curl example.com) | ✅ HTTP/1.1 200 OK | `02-pc1-internet.txt` |
| 2c | `pc2` → Internet (ping + curl) | ✅ 0% loss + HTTP 200 | `03-pc2-internet.txt` |
| 3 | LAN → DMZ (`pc1` → `web`) | ✅ ping 0% loss + HTTP 200 (index.html do lab) | `04-pc1-dmz-web-dns.txt` |
| 4a | `web` responde HTTP | ✅ página servida em 10.0.2.10:80 | `04-pc1-dmz-web-dns.txt` |
| 4b | `dns` responde como resolver | ✅ `dig @10.0.2.11 google.com` → 142.250.78.110; resolver default do pc1 também resolve | `04-pc1-dmz-web-dns.txt` |
| + | Sanity: fw e r0 → Internet (fixes de rota/NAT persistem após `lstart`) | ✅ 0% loss; `default via 198.51.100.2` no fw; `MASQUERADE -o eth1` no r0 | `05-fw-r0-sanity.txt` |

## Correções feitas para o baseline ficar verde

O baseline original **não** passaria; faltavam 3 coisas (corrigidas nos `.startup`, persistentes no `lstart`):

1. **Sem HTTP no `web`** — o container só tinha bash.
   → `web.startup`: `python3 -m http.server 80 --directory /www` + página em `web/www/index.html`.
2. **Sem resolver no `dns`** — nada escutando na porta 53.
   → `dns.startup`: `dnsmasq --listen-address=10.0.2.11 --port=53 --server=8.8.8.8 --server=1.1.1.1`.
3. **`/etc/resolv.conf` vazio em todos os hosts** — `curl` falhava com "Could not resolve host" (ping a IP puro funcionava).
   → `pc1/pc2/adm .startup`: `nameserver 10.0.2.11` (resolver da DMZ) + fallback `8.8.8.8`.
   - Desenho intencional: a LAN usa o resolver da DMZ (tráfego 53 atravessa o fw) — será filtrável nas Tarefas 2/4.

## Observações para as próximas tarefas

- **Estado do fw no baseline: sem filtragem** — ip_forward=1, FORWARD policy ACCEPT (defaults do Docker). É o estado "antes" dos experimentos.
- `tcpdump` disponível nos containers para as capturas das Tarefas 3–5.
- Contêineres seguem o padrão `kathara_<labid>_<device>_<hash>`; re-derivar nomes após cada `lstart`.
