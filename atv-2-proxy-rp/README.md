# Atividade 2 — Squid na saída, NGINX na entrada

Mesma topologia da atividade 1, com dois nós a mais: `proxy` (`10.0.1.20`) na LAN e `rp` (`10.0.2.20`) na DMZ. O Squid fica no caminho de quem sai; o NGINX fica no caminho de quem entra.

| Etapa | O que foi testado | Evidência |
| --- | --- | --- |
| 1 | tráfego direto antes de qualquer proxy | [baseline](steps/01-baseline/evidencias.md) |
| 2 | `proxy` na LAN e `rp` na DMZ | [topologia](steps/02-topologia/evidencias.md) |
| 3 | Squid e NGINX instalados na imagem | [imagens](steps/03-imagens/evidencias.md) |
| 4 | LAN só sai para a Internet pelo Squid | [squid](steps/04-squid/evidencias.md) |
| 5 | bloqueio por domínio e leitura do `access.log` | [acls](steps/05-acls-dominio/evidencias.md) |
| 6 | `TCP_MISS` e `TCP_MEM_HIT` no cache | [cache](steps/06-cache/evidencias.md) |
| 7 | `web` publicado só pelo NGINX | [reverse proxy](steps/07-nginx-reverse/evidencias.md) |
| 8 | `/admin` negado e método limitado | [controles](steps/08-nginx-controles/evidencias.md) |

## As três barreiras não fazem a mesma coisa

| | Onde está | Tráfego que observa | Informação que usa | Se for retirado |
| --- | --- | --- | --- | --- |
| Firewall `fw` | roteador entre as quatro redes, na `FORWARD` | tudo que cruza de uma zona para outra | endereço IP, porta, estado da conexão | as zonas deixam de existir: LAN, DMZ e borda passam a se enxergar |
| Squid (forward) | `10.0.1.20`, na LAN, porta 3128 | só o que os clientes da LAN pedem a ele, e só o que ele mesmo busca lá fora | URL, cabeçalho `Host`, método, nome no `CONNECT` | a LAN volta a sair sozinha: sem política por domínio, sem cache, sem log por estação |
| NGINX (reverse) | `10.0.2.20`, na DMZ, porta 80 | só o que chega ao serviço publicado, do lado de fora | caminho (`/admin`), método, cabeçalhos da requisição | o `web` vira o endereço público, cru, com o que estiver no disco |

Cada uma decide com um tipo diferente de informação. O firewall decide com endereço e porta porque é onde o pacote é encaminhado. O Squid decide com nome de domínio porque o cliente entrega a URL na requisição. O NGINX decide com caminho e método porque recebe a requisição inteira antes de encaminhar.

Os três continuam no lugar porque nenhum cobre o trabalho do outro. Trocar o firewall por um proxy deixaria sem dono o que não é requisição HTTP: o roteamento entre as redes, a separação de zonas e o bloqueio de sessão nova da DMZ para a LAN — que hoje existe porque a `FORWARD` do `fw` não tem nenhuma regra `eth1 → eth0` e a política é `DROP`. Proxy nenhum substitui isso sem virar ele próprio o roteador, e aí passa a ser o ponto único por onde tudo passa.

## Cenário 1 — o firewall reabre o HTTP para a DMZ

Se a regra `eth3 → eth1` voltar a aceitar porta 80 sem destino fixo, o que muda depende de duas coisas separadas.

Quem entrar pelo `rp` continua passando pelos mesmos controles. A etapa 8 mostra `GET /admin` devolvendo `403` e `POST /` devolvendo `405`, gerados pelo NGINX antes de qualquer encaminhamento — o log do `web` registrou só o `GET /` permitido. Reabrir o firewall não afeta isso: o `rp` continua sendo o único processo que fala com o `web` em nome de quem está fora.

Acesso direto ao `web` é outra falha, e precisa de duas condições juntas: a regra larga do firewall, que aceite pacote novo para qualquer endereço da DMZ, e o endereço `10.0.2.10` alcançável pelo atacante. Com a regra restrita a `-d 10.0.2.20`, o pacote para `10.0.2.10` cai no `DROP` e o `curl` do `r0` estoura o tempo (etapa 7). Reestabelecida a regra larga, o `web` responde cru: `python3 -m http.server` serve o que está no disco, inclusive `/admin`, que dentro da DMZ responde `200`. Todo o controle de aplicação do NGINX fica para trás nesse caminho, porque ele não está no caminho.

## Cenário 2 — o `web` foi comprometido

Aqui o atacante já está dentro da DMZ, com um shell no servidor. O que continua valendo é o que o firewall faz com sessão nova: não existe regra `eth1 → eth0`, então qualquer conexão iniciada do `web` para `10.0.1.0/24` cai no `DROP` da política. O `pc1` não recebe.

O Squid não aparece nesse caminho. Ele atende clientes da LAN que pedem um destino externo; nada no tráfego `web → LAN` passa por ele, e o Squid não tem como negar o que não lhe foi pedido.

O NGINX também não salva nada aqui. Ele protege a exposição do serviço — quem entra, por qual endereço, por qual caminho e com qual método. Contra um servidor já dominado, o que ele controla já está do lado errado: o atacante não precisa passar pelo `rp` para ler o que o `web` serve, ele está no `web`. O que sobra do NGINX nesse cenário é ter limitado o que o `web` publica, o que reduz o que o atacante encontrou antes de dominar a máquina.

Uma ressalva: `LAN → DMZ` tem regra nova aceita em qualquer porta, então o `pc1` pode chamar o `web`. Nessa sessão o retorno está liberado por estado, e um `web` dominado conversa com o `pc1` respondendo a um pedido que o próprio `pc1` fez. O que ele não consegue é iniciar a conexão.

O que ainda não está coberto dentro da própria DMZ: `web`, `dns` e `rp` estão no mesmo cabo B, sem nada entre eles, e a `FORWARD` permite ao `web` sair para a Internet na porta 53. Movimento lateral dentro da DMZ e exfiltração por DNS seguem possíveis.

## Limites de cada camada

O firewall não distingue domínio nem URL. Os três pedidos da etapa 8 — `GET /`, `GET /admin`, `POST /` — são idênticos em L3/L4: TCP/80, mesma origem, mesmo destino. Uma regra `--dport 80` não tem como separá-los.

O Squid não separa zonas. Ele é um host a mais na LAN, com um endereço `10.0.1.x`; se o firewall for retirado, o Squid continua existindo e as zonas deixam de existir junto com ele.

O NGINX não impede o `web` de iniciar conexão própria. Ele responde a requisições que chegam à porta 80; um processo rodando no `web` que abre uma conexão de saída não passa por ele.

A barreira útil depende de onde o atacante está. Fora da rede, quem decide é firewall e NGINX. Na DMZ, quem decide é firewall. Na LAN, quem decide é firewall e Squid, e o Squid só decide o que for pedido a ele.
