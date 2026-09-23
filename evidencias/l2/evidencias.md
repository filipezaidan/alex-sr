# Relatório de Evidências — Task 3: Bloqueio em L2 (MAC Address)

**Objetivo:** Identificar o endereço MAC do dispositivo comprometido (`pc2`), aplicar regra de bloqueio no firewall (`fw`) e comprovar o descarte e o comportamento do tráfego em Camada 2.

## 1. Identificação do MAC (`pc2`)

No host `pc2`, consultamos os detalhes da interface de rede `eth0`:

```
ip link show eth0

```

- **MAC do `pc2`:** `a2:a4:ee:d1:e3:b6`

- **IP do `pc2`:** `10.0.1.11`

## 2. Teste de Conectividade Antes do Bloqueio

Validamos o acesso prévio de `pc1` (`10.0.1.10`) e `pc2` (`10.0.1.11`) para a DMZ (`10.0.2.10`):

```
# Executado em pc1 e pc2
ping -c 4 10.0.2.10

```

- **Resultado:** Ambas as máquinas obtiveram 0% de perda de pacotes, confirmando que a política base do firewall permitia o tráfego da LAN.

## 3. Aplicação da Regra no Firewall (`fw`)

Para garantir que o bloqueio por MAC seja avaliado antes de qualquer regra de permissão (`ACCEPT`), inserimos a regra no topo da tabela (`-I FORWARD 1`):

```
iptables -I FORWARD 1 -m mac --mac-source a2:a4:ee:d1:e3:b6 -j DROP

```

Conferência da tabela de regras:

```
iptables -L FORWARD -n -v --line-numbers

```

**Saída observada:**

```
Chain FORWARD (policy DROP 0 packets, 0 bytes)
num   pkts bytes target     prot opt in     out     source               destination
1        0     0 DROP       0    --  *      *       0.0.0.0/0            0.0.0.0/0            MAC a2:a4:ee:d1:e3:b6
2       14  1176 ACCEPT     0    --  *      *       0.0.0.0/0            0.0.0.0/0            ctstate RELATED,ESTABLISHED
3        0     0 ACCEPT     0    --  eth0   eth3    0.0.0.0/0            0.0.0.0/0            ctstate NEW
4        2   168 ACCEPT     0    --  eth0   eth1    0.0.0.0/0            0.0.0.0/0            ctstate NEW

```

## 4. Validação do Bloqueio

Após a inserção da regra, executamos novos testes de conectividade:

- **No `pc2` (`10.0.1.11`):**

  ```
  ping -c 4 10.0.2.10
  ping -c 4 8.8.8.8

  ```

  **Resultado:** Bloqueado (100% packet loss).

- **No `pc1` (`10.0.1.10`):**

  ```
  ping -c 4 10.0.2.10
  ping -c 4 8.8.8.8

  ```

  **Resultado:** Conectividade mantida com sucesso (0% packet loss).

- **Contadores do Firewall (`fw`):**
  Ao checar novamente com `iptables -L FORWARD -n -v --line-numbers`, a regra 1 registrou a captura do tráfego do `pc2`:

  ```
  1    4  336 DROP       0    --  *      *       0.0.0.0/0            0.0.0.0/0            MAC a2:a4:ee:d1:e3:b6

  ```

## 5. Análise de Tráfego (`tcpdump`)

Capturamos o tráfego ICMP com a opção `-e` para exibir o cabeçalho Ethernet (L2):

1. **Na interface LAN (`eth0`):** `tcpdump -eni eth0 icmp`
   - Capturou as requisições de eco vindas do MAC `a2:a4:ee:d1:e3:b6` (`10.0.1.11`) com destino a `10.0.2.10`. Os pacotes chegaram à interface, mas foram descartados antes de serem encaminhados.

2. **Na interface WAN (`eth3`):** `tcpdump -eni eth3 icmp`
   - **Nenhum** pacote do `pc2` foi registrado saindo por `eth3`.

   - Registrou os pacotes do `pc1` (`10.0.1.10`) direcionados a `8.8.8.8`. O quadro L2 no lado WAN apresentou o MAC de origem `b6:c2:fb:73:29:77` (interface `eth3` do firewall) e destino `9a:55:89:49:7e:89` (próximo salto/roteador).

## 6. Resposta às Questões de Investigação

- **O endereço MAC acompanha um pacote durante todo o seu percurso pela Internet?**
  **Não.** O endereço MAC atua apenas no enlace local (L2). Ao passar por um dispositivo roteador/firewall (L3), o quadro Ethernet original é descartado e um novo quadro é montado com o MAC do próprio firewall como origem e o MAC do próximo salto (_next hop_) como destino.

- **Em quais condições o firewall consegue enxergar o MAC original de `pc2`?**
  O firewall enxerga o MAC original do `pc2` exclusivamente porque ambos pertencem ao mesmo domínio de broadcast (mesma rede local física/VLAN conectada à interface `eth0`). Se houvesse um roteador intermediário entre o `pc2` e o `fw`, o firewall veria apenas o endereço MAC desse roteador intermediário.
