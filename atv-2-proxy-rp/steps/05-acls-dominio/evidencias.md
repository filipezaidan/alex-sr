# Evidências — ACLs, Cliente e Bloqueio por Domínio

Nesta etapa, implementamos no Squid (`10.0.1.20`) o controle de acesso baseado em **nome de domínio** (Camada 7) e identificação de clientes por endereço IP de origem (ACLs de clientes).

Configuramos:
- Domínio proibido: `example.com` (e subdomínios `.example.com`).
- Domínio permitido: `info.cern.ch` (site HTTP clássico e estável).
- Identificação dos clientes `pc1` (`10.0.1.10`) e `pc2` (`10.0.1.11`).

---

## 1. Configuração do Squid (`squid.conf`)

No arquivo `proxy/etc/squid/squid.conf`:

```squid
# Quem pode usar o proxy. Primeira regra que casa decide.
acl lan src 10.0.1.0/24
acl pc1 src 10.0.1.10/32
acl pc2 src 10.0.1.11/32

# ACL de destino por domínio (o ponto inicial casa com o domínio e subdomínios)
acl sites_bloqueados dstdomain .example.com

# Destinos que o encaminhamento aceita.
acl SSL_ports port 443
acl Safe_ports port 80
acl Safe_ports port 443
acl CONNECT method CONNECT

# Fora dessas portas, nega. CONNECT (HTTPS) só na 443.
http_access deny !Safe_ports
http_access deny CONNECT !SSL_ports

# Bloqueio por domínio (deve vir ANTES de liberar a LAN)
http_access deny sites_bloqueados

# A LAN passa para os demais destinos. Qualquer outra origem para aqui.
http_access allow lan
http_access deny all
```

> **Atenção à ordem das regras:** O Squid avalia as diretivas `http_access` sequencialmente (de cima para baixo). A regra `http_access deny sites_bloqueados` precisa obrigatoriamente estar posicionada **antes** de `http_access allow lan`, caso contrário a requisição seria aceita imediatamente pela regra permissiva da rede local e o bloqueio jamais seria alcançado.

---

## 2. Teste do Domínio Proibido (`pc1` e `pc2`)

No cliente `pc1`:

```bash
curl -I -x http://10.0.1.20:3128 http://example.com
```

Saída observada:

```http
HTTP/1.1 403 Forbidden
Server: squid/5.7
Mime-Version: 1.0
Date: Fri, 23 Oct 2026 20:21:38 GMT
Content-Type: text/html;charset=utf-8
Content-Length: 3059
X-Squid-Error: ERR_ACCESS_DENIED 0
Vary: Accept-Language
Content-Language: en
X-Cache: MISS from proxy
X-Cache-Lookup: NONE from proxy:3128
Via: 1.1 proxy (squid/5.7)
Connection: keep-alive
```

No cliente `pc2`:

```bash
curl -I -x http://10.0.1.20:3128 http://example.com
```

Saída observada: `HTTP/1.1 403 Forbidden` com `X-Squid-Error: ERR_ACCESS_DENIED 0`.

O Squid interceptou a requisição e devolveu a página padrão de negação (código 403), sem sequer repassar os pacotes para a Internet.

---

## 3. Teste do Domínio Permitido (`pc1` e `pc2`)

No cliente `pc1`:

```bash
curl -I -x http://10.0.1.20:3128 http://info.cern.ch
```

Saída observada:

```http
HTTP/1.1 200 OK
Date: Fri, 23 Oct 2026 20:20:48 GMT
Server: Apache
Last-Modified: Wed, 05 Feb 2014 16:00:31 GMT
ETag: "286-4f1aadb3105c0"
Accept-Ranges: bytes
Content-Length: 646
Content-Type: text/html
Via: 1.1 proxy (squid/5.7)
Connection: keep-alive
```

No cliente `pc2`:

```bash
curl -I -x http://10.0.1.20:3128 http://info.cern.ch
```

Saída observada: `HTTP/1.1 200 OK`, com `X-Cache: HIT from proxy`, provando que o domínio permitido foi consultado e armazenado com sucesso para os clientes.

---

## 4. Teste com HTTPS e o Método CONNECT

Para avaliar o comportamento com tráfego HTTPS:

```bash
curl -k -I -x http://10.0.1.20:3128 https://example.com
```

Saída observada:

```text
curl: (56) CONNECT tunnel failed, response 403
HTTP/1.1 403 Forbidden
Server: squid/5.7
X-Squid-Error: ERR_ACCESS_DENIED 0
Via: 1.1 proxy (squid/5.7)
```

O cliente tentou estabelecer um túnel TCP cego através de `CONNECT example.com:443`. O Squid leu o nome do host solicitado na linha de comando do método HTTP CONNECT e aplicou a ACL de bloqueio antes do túnel ser estabelecido.

---

## 5. Análise do `access.log` do Squid

No nó `proxy`, a inspeção do arquivo `/var/log/squid/access.log` gerou as seguintes entradas:

```text
1792786898.909      0 10.0.1.10 TCP_DENIED/403 359 HEAD http://example.com/ - HIER_NONE/- text/html
1792786905.565      0 10.0.1.10 TCP_MEM_HIT/200 336 HEAD http://info.cern.ch/ - HIER_NONE/- text/html
1792786909.263      0 10.0.1.11 TCP_DENIED/403 359 HEAD http://example.com/ - HIER_NONE/- text/html
1792786912.796      0 10.0.1.11 TCP_MEM_HIT/200 336 HEAD http://info.cern.ch/ - HIER_NONE/- text/html
1792786924.451      0 10.0.1.10 TCP_DENIED/403 3422 CONNECT example.com:443 - HIER_NONE/- text/html
```

### Como ler cada campo do log:

1. **`1792786898.909` (Timestamp Unix):** Momento exato em que a requisição foi completada.
2. **`0` (Tempo de resposta em ms):** 0 ms porque a requisição foi rejeitada imediatamente no proxy local sem consultar a rede externa.
3. **`10.0.1.10` / `10.0.1.11` (IP do Cliente):** Identifica qual máquina da LAN originou o pedido (permite auditoria granular por estação).
4. **`TCP_DENIED/403` vs `TCP_MEM_HIT/200` (Ação do Squid / Código HTTP retornado):**
   - `TCP_DENIED/403`: A requisição violou uma ACL e foi rejeitada pelo proxy com status HTTP 403.
   - `TCP_MEM_HIT/200`: A requisição foi permitida e o objeto foi entregue diretamente da memória cache.
5. **`359` (Bytes transferidos):** Tamanho do payload da resposta enviada ao cliente.
6. **`HEAD` / `CONNECT` (Método HTTP):** O verbo utilizado pelo cliente. Note a presença do método `CONNECT` no acesso HTTPS.
7. **`http://example.com/` / `example.com:443` (URL ou Host de destino):** O recurso solicitado.
8. **`HIER_NONE/-` (Hierarquia de servidores):** Indica que nenhum servidor de origem externo foi consultado (já que a requisição foi negada ou servida do cache local).

---

## 6. Comparação: Bloqueio L3/L4 (`iptables -d 8.8.8.8`) vs Bloqueio L7 (Squid)

| Critério | Firewall L3/L4 (`iptables`) | Proxy Explícito L7 (`Squid`) |
|---|---|---|
| **Camada TCP/IP** | Camadas 3 (Rede) e 4 (Transporte) | Camada 7 (Aplicação) |
| **Visibilidade** | Enxerga apenas IP de origem/destino e portas TCP/UDP. | Enxerga URL completa, cabeçalho `Host`, método HTTP e parâmetros da requisição. |
| **Comportamento com CDNs e IPs dinâmicos** | **Frágil:** Múltiplos sites compartilham o mesmo IP em CDNs (ex: Cloudflare). Bloquear o IP bloqueia sites inocentes. Se o site mudar de IP por DNS balanceado, a regra falha. | **Eficaz:** Bloqueia pelo nome de domínio (`example.com`), independentemente de quantos IPs o site possua ou se divide IP com outros. |
| **HTTPS sem inspeção TLS** | Vê apenas pacotes TCP direcionados à porta 443 do IP de destino. | Enxerga o nome do host solicitado no método `CONNECT` e nos metadados da negociação, permitindo bloquear o domínio mesmo sem quebrar a criptografia TLS. |
| **O que o proxy NÃO vê sem interceptação TLS** | Não vê conteúdo em nenhuma hipótese. | Sem descriptografia SSL Bump/MITM, o Squid **não vê o caminho (URI)** da requisição (ex: `/admin` vs `/publico`), nem os cabeçalhos internos ou o corpo criptografado. Ele vê apenas o domínio (`host:443`). |
| **Resposta ao usuário** | `DROP` gera *timeout* silencioso. `REJECT` gera TCP RST ou ICMP unreachable. | Retorna uma resposta HTTP estruturada (`403 Forbidden`), informando claramente ao usuário e ao navegador o motivo da recusa. |
