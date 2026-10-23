# 4. Defense in Depth

O comprometimento do servidor Web da DMZ **não significa que o atacante terá acesso direto a `pc1` e `pc2`**. A DMZ e a LAN são redes separadas, e o firewall controla o tráfego entre elas.

## Controles que ainda limitam o acesso à LAN

- **Firewall:** bloqueia novas conexões iniciadas da DMZ para a LAN. No `fw`, a cadeia `FORWARD` possui política padrão `DROP`:

```text
Chain FORWARD (policy DROP)
```

Além disso, **não existe uma regra `ACCEPT` para `NEW` de `eth1` (DMZ) para `eth0` (LAN)**. Portanto, uma nova conexão iniciada pelo `web` em direção à LAN é bloqueada.

- **Segmentação de redes:** o servidor `web` está na DMZ (`10.0.2.0/24`), enquanto `pc1` e `pc2` estão na LAN (`10.0.1.0/24`). As duas redes não estão diretamente conectadas.

- **Regras de filtragem:** o firewall permite apenas os fluxos definidos. Não existe regra permitindo:

```text
eth1 → eth0
ctstate NEW
```

- **Controle stateful:** a **linha 1** da cadeia `FORWARD`:

```text
1  ACCEPT  ...  ctstate RELATED,ESTABLISHED
```

permite somente respostas de conexões que já foram autorizadas e estabelecidas. Ela não permite que o `web` inicie uma nova conexão contra `pc1` ou `pc2`.

- **Controles nos próprios hosts:** mesmo que o atacante consiga passar pelo firewall, `pc1` e `pc2` ainda podem possuir firewall local, autenticação e outras restrições.

## Exemplo

Se o servidor Web for comprometido, o atacante pode tentar:

```text
web → pc1
web → pc2
```

Essas novas conexões não possuem uma regra de `ACCEPT` e serão descartadas pela política `DROP` do `FORWARD`.

```text
Internet
   ↓
Firewall
   ↓
DMZ
   ↓
web comprometido
   ↓
   X  ← nova conexão DMZ → LAN bloqueada
   ↓
LAN
pc1 / pc2
```

## Conclusão

Esse cenário representa o princípio de **Defense in Depth** porque a segurança não depende de uma única barreira. Mesmo que o servidor Web seja comprometido, a **segmentação da rede, o firewall, as regras de filtragem, o controle stateful e os controles nos próprios hosts** continuam funcionando como camadas adicionais de proteção.
