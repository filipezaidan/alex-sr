# Relatório de Evidências — Task 3: Controles em Camada 3 (L3)

**Objetivo:** Implementar e validar regras de firewall baseadas em protocolos da camada de rede (ICMP) e endereçamento IP de destino, demonstrando o efeito com `ping` e `tcpdump`.

---

## Experimento A — Bloqueio de Tráfego ICMP

### 1. Teste Prévia (Antes da Regra)

No host `pc1` (`10.0.1.10`), validamos a conectividade ICMP para a DMZ (`10.0.2.10`):

```bash
ping -c 4 10.0.2.10
```

- **Resultado esperado:** 0% de perda de pacotes.

### 2. Aplicação da Regra no Firewall (`fw`)

Bloqueamos o tráfego ICMP vindo da LAN (`eth0`) com destino à DMZ (`eth1`):

```bash
iptables -I FORWARD 1 -i eth0 -o eth1 -p icmp -j DROP
```

Verificação no firewall:

```bash
iptables -L FORWARD -n -v --line-numbers
```

### 3. Validação com `tcpdump` e `ping`

- **No `fw` (Terminal 1 - Escuta na interface de entrada `eth0`):**
  ```bash
  tcpdump -ni eth0 icmp
  ```
- **No `fw` (Terminal 2 - Escuta na interface de saída `eth1`):**
  ```bash
  tcpdump -ni eth1 icmp
  ```
- **No `pc1` (Geração de tráfego):**
  ```bash
  ping -c 4 10.0.2.10
  ```

**Resultado Observado:**

- **`pc1`:** 100% de perda de pacotes (`packet loss`).
- **`tcpdump` na `eth0`:** Exibe as requisições `ICMP echo request` chegando da LAN.
- **`tcpdump` na `eth1`:** Nenhum pacote é registrado, comprovando o descarte no firewall antes do encaminhamento.

---

## Experimento B — Bloqueio por IP de Destino

### 1. Seleção do Destino e Teste Prévio

Selecionamos o IP de destino de teste (exemplo: `8.8.8.8` representando um destino externo restrito).

No host `pc1`:

```bash
ping -c 4 8.8.8.8
```

- **Resultado esperado:** Resposta normal (0% packet loss).

### 2. Aplicação da Regra no Firewall (`fw`)

Inserimos a regra para descartar qualquer pacote vindo da LAN (`eth0`) direcionado ao IP restrito:

```bash
iptables -I FORWARD 1 -i eth0 -d 8.8.8.8 -j DROP
```

Conferência das regras ativas:

```bash
iptables -L FORWARD -n -v --line-numbers
```

### 3. Teste Posterior e Análise de Contadores

- **No `pc1` (Tentativa de acesso ao IP bloqueado):**

  ```bash
  ping -c 4 8.8.8.8
  ```

  - **Resultado:** Bloqueado (100% packet loss).

- **No `pc1` (Teste de acesso a outro IP permitido para isolamento do teste):**

  ```bash
  ping -c 4 10.0.2.10
  ```

  - **Resultado:** Conectividade normal.

- **No `fw` (Checagem de contadores):**
  ```bash
  iptables -L FORWARD -n -v --line-numbers
  ```

  - **Resultado:** O contador da regra de bloqueio do IP `8.8.8.8` incrementa os pacotes descartados.

---

## Resposta à Investigação L3

**Pergunta:** Bloquear o endereço IP é uma boa solução para impedir o acesso a determinado site?

**Resposta:**
**Não é uma solução definitiva nem suficiente para a web moderna.** O bloqueio por IP apresenta limitações críticas:

1. **Múltiplos IPs por Domínio:** Grandes sites usam DNS Round Robin, Anycast ou múltiplos servidores. Um único domínio (ex: `google.com`) possui dezenas de endereços IP alternativos.
2. **Hospedagem Compartilhada (Multi-tenant):** Vários sites diferentes podem compartilhar o mesmo endereço IP público (através de suporte a Virtual Hosts / TLS SNI). Bloquear o IP de um site malicioso pode derrubar dezenas de sites legítimos hospedados no mesmo servidor.
3. **Redes de Distribuição de Conteúdo (CDNs):** Serviços como Cloudflare e Akamai alteram e alternam dinamicamente os endereços IP dos servidores de borda.
4. **Fácil Contorno:** Mudanças na infraestrutura do serviço ou alteração de registros DNS tornam a regra de IP obsoleta rapidamente.

Por essas razões, o controle eficiente de acesso a sites exige mecanismos de **Camada 7 (Aplicação)**, como **DNS Filtering**, **Proxy HTTP/HTTPS** ou **Next-Generation Firewalls (NGFW)**.
