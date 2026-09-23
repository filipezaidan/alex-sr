# Evidências — Firewall de Perímetro

## 1. Objetivo

Implementar a segurança de perímetro no nó `fw` da topologia Kathará utilizando
`iptables`, adotando filtragem stateful e o princípio de bloqueio por padrão.

A política aplicada foi:

- LAN → Internet: permitir
- LAN → DMZ: permitir
- Internet → Web da DMZ permitir
- Internet → LAN: bloquear
- DMZ → LAN: bloquear novas conexões
- Respostas de conexões permitidas: permitir
- Demais tráfegos encaminhados: bloquear pela política padrão `DROP`

---

## 2. Configuração verificada

No firewall `fw`, foi utilizada a cadeia `FORWARD`, pois os tráfegos entre
LAN, DMZ e WAN são encaminhados pelo firewall.

A política padrão foi configurada como:

```bash
iptables -P FORWARD DROP
```

Regra para permitir respostas de conexões já estabelecidas:

```bash
iptables -A FORWARD -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
```

Essa regra permite que respostas retornem para conexões que foram iniciadas
por uma rede autorizada, sem permitir novas conexões arbitrárias no sentido
contrário.

Regras de acesso:

```bash
iptables -A FORWARD -i eth0 -o eth3   -m conntrack --ctstate NEW -j ACCEPT

iptables -A FORWARD -i eth0 -o eth1   -m conntrack --ctstate NEW -j ACCEPT

iptables -A FORWARD -i eth3 -o eth1   -p tcp --dport 80   -m conntrack --ctstate NEW -j ACCEPT
```

Mapeamento das interfaces:

- `eth0` → LAN (`10.0.1.0/24`)
- `eth1` → DMZ (`10.0.2.0/24`)
- `eth2` → MGMT (`10.0.3.0/24`)
- `eth3` → WAN (`198.51.100.0/30`)

---

## 3. Evidência da política padrão

Comando utilizado:

```bash
iptables -L FORWARD -n -v --line-numbers
```

Saída observada:

```text
Chain FORWARD (policy DROP 0 packets, 0 bytes)
```

Isso comprova que o firewall utiliza uma política de bloqueio por padrão.
Somente os tráfegos explicitamente autorizados pelas regras podem atravessar
a cadeia `FORWARD`.

---

## 4. Evidência — LAN → DMZ

Foi realizada uma tentativa de comunicação do `pc1` (LAN) para o servidor
`web` da DMZ (`10.0.2.10`).

Teste utilizado:

```bash
ping -c 4 10.0.2.10
```

A comunicação foi permitida.

A regra correspondente no firewall:

```text
eth0 → eth1   ctstate NEW
```

registrou tráfego.

Na verificação dos contadores:

```text
3        1    84  ACCEPT  ... eth0  eth1 ... ctstate NEW
```

Isso demonstra que uma nova conexão originada na LAN foi aceita em direção
à DMZ.

> Observação: como o serviço Web ainda não havia sido configurado nesta
> etapa, o teste de conectividade foi realizado com `ping`. O teste HTTP
> (`curl http://10.0.2.10`) pode ser realizado posteriormente quando o
> serviço Web estiver configurado.

---

## 5. Evidência — Respostas de conexões permitidas

Foi comparada a contagem de pacotes antes e depois do teste.

### Antes

```text
1        0     0  ACCEPT  ... ctstate RELATED,ESTABLISHED
3        0     0  ACCEPT  ... eth0  eth1 ... ctstate NEW
```

### Depois

```text
1        7   588  ACCEPT  ... ctstate RELATED,ESTABLISHED
3        1    84  ACCEPT  ... eth0  eth1 ... ctstate NEW
```

A regra `ESTABLISHED,RELATED` passou de `0` para `7` pacotes e `588` bytes.

Isso demonstra o funcionamento do filtro stateful: depois que uma conexão
permitida é iniciada pela LAN, os pacotes de resposta pertencentes àquela
conexão são reconhecidos pelo `conntrack` como `ESTABLISHED` ou `RELATED` e
são aceitos.

A evidência também mostra que não foi necessária uma regra genérica
permitindo novas conexões da DMZ para a LAN.

---

## 6. Evidência — Internet → Web da DMZ

A política permite conexões novas vindas da WAN somente para TCP/80:

```text
eth3 → eth1   tcp dpt:80   ctstate NEW
```

Regra correspondente:

```bash
iptables -A FORWARD -i eth3 -o eth1   -p tcp --dport 80   -m conntrack --ctstate NEW -j ACCEPT
```

O contador dessa regra deve aumentar quando uma conexão HTTP for iniciada
a partir da rede externa.

---

## 7. Evidência — Internet → LAN

Não existe uma regra `NEW` permitindo:

```text
eth3 → eth0
```

Portanto, novas conexões originadas na WAN com destino à LAN não possuem
regra de aceitação e são descartadas pela política padrão:

```text
FORWARD (policy DROP)
```

Teste previsto:

```bash
ping -c 4 10.0.1.10
```

ou, caso exista um serviço TCP no `pc1`:

```bash
nc -vz -w 3 10.0.1.10 <porta>
```

O resultado esperado é falha/bloqueio da conexão.

---

## 8. Evidência — DMZ → LAN

Também não existe uma regra `NEW` permitindo:

```text
eth1 → eth0
```

Assim, novas conexões iniciadas por servidores da DMZ em direção à LAN
são bloqueadas pela política padrão `DROP`.

A regra `ESTABLISHED,RELATED` não contradiz essa proteção: ela permite
somente tráfego pertencente a conexões que já foram autorizadas e
estabelecidas, como respostas a conexões iniciadas pela LAN.

---

## 9. Estado final do firewall

A verificação final foi realizada com:

```bash
iptables -L FORWARD -n -v --line-numbers
```

Estado observado:

```text
Chain FORWARD (policy DROP 0 packets, 0 bytes)
num   pkts bytes target     prot opt in     out     source      destination
1       7    588 ACCEPT     0    --  *      *       ...         ...  ctstate RELATED,ESTABLISHED
2       0      0 ACCEPT     0    --  eth0   eth3     ...         ...  ctstate NEW
3       1     84 ACCEPT     0    --  eth0   eth1     ...         ...  ctstate NEW
4       0      0 ACCEPT     6    --  eth3   eth1     ...         ...  tcp dpt:80 ctstate NEW
```

Os contadores confirmam que houve tráfego pela regra de respostas
`ESTABLISHED,RELATED` e pela regra LAN → DMZ.

---

## 10. Conclusão

A configuração implementa um firewall de perímetro com política padrão
`DROP` na cadeia `FORWARD` e libera explicitamente os fluxos necessários.

Os testes e contadores do `iptables` demonstram principalmente:

1. A política padrão de bloqueio está ativa.
2. O tráfego LAN → DMZ foi permitido.
3. As respostas de conexões permitidas foram aceitas por
   `ESTABLISHED,RELATED`.
4. O acesso externo ao Web da DMZ é limitado à porta TCP/80.
5. Não há regras permitindo novas conexões Internet → LAN.
6. Não há regras permitindo novas conexões DMZ → LAN.

As capturas de tela dos comandos e testes devem ser associadas às respectivas
seções deste documento como evidências da implementação.
