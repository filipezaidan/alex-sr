# Plano de Execução — Defense in Depth II: Proxy, Reverse Proxy e Segurança em Camadas

A Task anterior deixou o perímetro `Internet → Firewall → DMZ / LAN` funcionando. Esta Task acrescenta duas barreiras independentes:

- `proxy` — Squid na LAN, no caminho de saída dos usuários;
- `rp` — NGINX na DMZ, na frente do servidor Web.

O fluxo alvo é:

```text
Saída:    pc1/pc2 → Squid → Firewall → Internet
Entrada:  Internet → Firewall → NGINX → Web
```

O `web` continua na DMZ e deixa de ser acessível direto da Internet. O `fw.startup` atual ainda libera `eth3 → eth1` na porta TCP/80 para qualquer host da DMZ. Essa regra é o que a etapa do NGINX vai restringir.

Endereços novos, no plano que já existe:

| Nó | Zona | Interface | Endereço | Gateway |
| --- | --- | --- | --- | --- |
| `proxy` | LAN (cabo A) | `eth0` | `10.0.1.20/24` | `10.0.1.1` |
| `rp` | DMZ (cabo B) | `eth0` | `10.0.2.20/24` | `10.0.2.1` |

Dois controles do NGINX ficam definidos neste plano, para a execução não parar na escolha: bloquear `/admin` e limitar os métodos HTTP a `GET` e `HEAD`. A atividade aceita outro par. Se a dupla mudar, os prints e o README mudam junto.

---

## 1. Baseline da Task anterior

### Objetivo

Subir o laboratório como ele está e confirmar o perímetro antes de acrescentar nós.

### Atividades

- `kathara lstart` na raiz do repositório.
- Confirmar IPs e a cadeia `FORWARD` do `fw`.
- Registrar o comportamento que esta Task vai mudar:
  - `pc1` alcança a Internet sem proxy;
  - a Internet (`r0`) alcança `http://10.0.2.10` direto no `web`.

### Saberes

- Kathará: `lab.conf`, `.startup`, `kathara lstart`, `kathara connect`, `kathara lclean`.
- O que a cadeia `FORWARD` filtra: pacote que entra por uma interface e sai por outra.
- Leitura de `iptables -L FORWARD -n -v --line-numbers` e da regra atual `eth3 → eth1` TCP/80.

### Evidência

Print da `FORWARD` e dos dois acessos que ainda funcionam direto.

### Entregável

Baseline anotada, para comparar com os testes do Squid e do NGINX.

---

## 2. Topologia, zonas e fluxos

### Objetivo

Incluir `proxy` e `rp` no `lab.conf`, no endereçamento e na figura, antes de instalar serviço.

### Atividades

- Ligar `proxy[0]` no cabo A e `rp[0]` no cabo B.
- Criar `proxy.startup` e `rp.startup` só com IP e rota default.
- Subir os dois nós e testar `ping` até o gateway.
- Atualizar a figura da topologia com as zonas LAN, DMZ, gerência e borda, os nós novos e as setas de saída e de entrada.
- Escrever a matriz de fluxos desta Task:

| Origem | Destino | Política nesta Task |
| --- | --- | --- |
| `pc1` / `pc2` | Squid (`10.0.1.20:3128`) | Permitir. Os dois estão na mesma LAN, então o pacote não passa pelo firewall. |
| Squid | Internet (TCP/80 e TCP/443) | Permitir pelo firewall. |
| `pc1` / `pc2` | Internet em TCP/80 e TCP/443, sem passar pelo Squid | Bloquear, para o caminho desenhado ser o único. ICMP e o restante da LAN podem continuar como na Task anterior. |
| Internet | NGINX (`10.0.2.20:80`) | Permitir. |
| Internet | `web` (`10.0.2.10`) | Bloquear. |
| NGINX | `web` (`10.0.2.10:80`) | Permitir. Os dois estão na mesma DMZ, então esse trecho não atravessa o `fw`. |
| DMZ | LAN, sessão nova | Continua bloqueada. |

### Saberes

- Colisão no Kathará: a letra do `lab.conf` é o cabo. Mesma letra, mesma rede, o firewall não vê o tráfego interno.
- Diferença entre o pacote que o firewall encaminha e o pacote que só atravessa o switch da LAN ou da DMZ.
- Por que o plano de endereçamento precisa existir antes da configuração dos serviços.

### Evidência

Figura atualizada e `ping` de `proxy` e `rp` aos respectivos gateways.

### Entregável

Topologia nova sobe com `kathara lstart` e a figura mostra zonas e fluxos.

---

## 3. Instalar Squid e NGINX de forma que sobrevivam ao laboratório

### Objetivo

Ter os dois pacotes disponíveis dentro dos containers sem reinstalar à mão a cada teste.

### Atividades

- Decidir como o software persiste. O container criado pelo `lstart` perde o que foi instalado com `apt` quando o laboratório é recriado.
- Caminho previsto: um `Dockerfile` por serviço, imagem citada no `lab.conf`, e a configuração montada ou copiada no `.startup`.
- Confirmar, num `lclean` seguido de `lstart`, que `squid` e `nginx` sobem sem instalação manual.

### Saberes

- Imagem Kathará e a diretiva de imagem no `lab.conf`.
- Por que `apt install` só no terminal não entra na entrega.
- Diferença entre o processo instalado e o arquivo de configuração que a Task pede comentado.

### Evidência

Depois de recriar o laboratório, `squid -v` no `proxy` e `nginx -v` no `rp`.

### Entregável

`kathara lstart` deixa os dois serviços instalados.

---

## 4. Squid como forward proxy

### Objetivo

Fazer `pc1` e `pc2` navegarem pela Internet passando pelo Squid.

### Atividades

- Configurar o Squid para escutar em `10.0.1.20:3128`.
- Liberar a LAN `10.0.1.0/24` com ACL e `http_access`, e negar o resto.
- No `pc1` e no `pc2`, usar o proxy de forma explícita. O teste é `curl -x http://10.0.1.20:3128`.
- Validar um site HTTP. O cache e o bloqueio por domínio ficam mais visíveis em HTTP do que em HTTPS.
- Ajustar o `fw` para que TCP/80 e TCP/443 em direção à Internet saiam só do IP do Squid. Um `curl` direto do `pc1`, sem `-x`, deve falhar. O mesmo `curl` com `-x` deve funcionar.

### Saberes

- Forward proxy: o cliente sabe que o proxy existe e pede a ele para buscar o recurso.
- Proxy explícito e o método `CONNECT`, usado quando o destino é HTTPS.
- ACL e `http_access` do Squid: a primeira regra que casa decide, e a ordem importa.
- Por que o tráfego `pc → proxy` não aparece na `FORWARD` do firewall, e o tráfego `proxy → Internet` aparece com origem `10.0.1.20`.

### Evidência

Print do acesso `pc1 → Squid → Internet` e print do acesso direto `pc1 → Internet` na porta 80 bloqueado.

### Entregável

Saída web da LAN só pelo Squid.

---

## 5. ACLs, cliente e bloqueio por domínio

### Objetivo

Mostrar uma política por nome de domínio, e comparar com o bloqueio de IP feito na Task anterior.

### Atividades

- Escolher um domínio permitido e um proibido. O proibido pode ser um site HTTP estável, para o teste não depender de HTTPS.
- Criar uma ACL de destino por domínio e uma ACL de cliente, se fizer sentido separar `pc1` e `pc2`.
- Bloquear o domínio proibido e permitir o outro.
- Repetir o acesso dos dois lados e guardar o `access.log` do Squid, com a linha de negação.
- Escrever a comparação com a regra `-d 8.8.8.8` da Task anterior:
  - o firewall L3/L4 vê endereço e porta;
  - o mesmo site pode ter muitos IPs, CDN e IP compartilhado;
  - no proxy explícito, o Squid vê o nome pedido pelo cliente no HTTP e no `CONNECT`.

### Saberes

- O que é um domínio e em que campo o proxy explícito enxerga esse nome.
- O que o Squid não vê sem interceptação TLS: o caminho e o corpo de um site HTTPS.
- Como ler uma linha do `access.log` (cliente, URL ou host, ação, código).

### Evidência

Print do domínio bloqueado, do domínio permitido e do trecho de log correspondente.

### Entregável

Política por domínio funcionando e a comparação escrita no README.

---

## 6. Cache do Squid

### Objetivo

Servir um recurso a partir do cache e provar isso com o log, não só com a velocidade.

### Atividades

- Acessar o mesmo URL HTTP duas vezes pelo proxy.
- Na primeira vez, o log deve indicar busca na origem (`TCP_MISS` ou equivalente).
- Na segunda, o log deve indicar cache (`TCP_HIT` ou equivalente).
- Conferir também o cabeçalho que o Squid adiciona à resposta, como `X-Cache` ou `Via`, se estiver presente.
- Anotar por que um site só HTTPS não serve para este teste sem SSL Bump: o proxy não guarda o conteúdo que passou dentro do TLS.

### Saberes

- O que o cache guarda e o que faz um objeto ser revalidado ou ignorado (`Cache-Control`, conteúdo dinâmico).
- Diferença entre a conexão do cliente até o Squid e a conexão do Squid até a origem.
- Leitura de `TCP_HIT` e `TCP_MISS` no log.

### Evidência

Duas requisições seguidas e as duas linhas de log, uma de cada tipo.

### Entregável

Prova de que o conteúdo saiu do cache na repetição.

---

## 7. NGINX como reverse proxy

### Objetivo

Publicar o `web` só através do `rp`.

### Atividades

- Subir um HTTP simples no `web`, escutando em `10.0.2.10:80`. Pode ser o serviço que a imagem já tiver ou um servidor mínimo, desde que responda de forma estável.
- Configurar o NGINX em `10.0.2.20:80` com `proxy_pass` para `http://10.0.2.10`.
- Do `r0`, acessar `http://10.0.2.20` e confirmar que a resposta é a do `web`.
- No `fw`, trocar a liberação genérica de TCP/80 para a DMZ por uma liberação só até `10.0.2.20`.
- Do `r0`, repetir `http://10.0.2.10` e confirmar que a conexão direta não completa.
- Confirmar que o `rp` ainda alcança o `web`. Esse teste é local à DMZ.

### Saberes

- Reverse proxy: o cliente fala com o proxy e não precisa saber o endereço do servidor de aplicação.
- `proxy_pass`, `Host` e o que muda no endereço que o `web` enxerga.
- Por que a regra nova do firewall usa o IP do `rp` como destino, e por que não existe regra `rp → web` na `FORWARD`.
- Diferença entre timeout de `DROP` e conexão recusada.

### Evidência

Print de `r0 → rp → web` com resposta HTTP e print de `r0 → web` direto falhando. Print da `FORWARD` com a regra restrita ao `10.0.2.20`.

### Entregável

A Internet só entra no serviço pelo NGINX.

---

## 8. Dois controles no NGINX

### Objetivo

Usar o reverse proxy como barreira de aplicação, não só como encaminhador.

### Atividades

- Criar no `web` uma resposta em `/` e outra em `/admin`, para os dois resultados aparecerem no teste.
- No `rp`, negar `/admin` para qualquer cliente.
- No `rp`, aceitar só `GET` e `HEAD`. Um `POST` em `/` deve ser recusado pelo NGINX.
- Testar a partir do `r0`:
  - `GET /` permitido e ainda servido pelo `web`;
  - `GET /admin` bloqueado pelo NGINX;
  - `POST /` bloqueado pelo NGINX.
- Guardar o `access.log` do NGINX com os três pedidos.
- Comentar cada diretiva no arquivo de configuração.

### Saberes

- `location` do NGINX e a precedência entre prefixo e localização exata.
- Código que o cliente vê quando o proxy recusa (`403` ou `405`) e por que esse código não veio do `web`.
- Método HTTP e por que limitar método é um controle de aplicação, invisível para uma regra que só olha a porta 80.

### Evidência

Print dos três pedidos e do log do `rp`.

### Entregável

`/admin` negado e métodos fora de `GET`/`HEAD` negados, com a configuração comentada.

---

## 9. Defense in Depth e a pergunta dos três componentes

### Objetivo

Explicar o que cada barreira vê, o que ela não vê, e o que continua de pé quando uma falha.

### Atividades

Responder, com os testes já feitos, estes pontos no README:

- Firewall, forward proxy e reverse proxy não fazem a mesma coisa. Para cada um: onde está, qual tráfego observa, qual informação usa e o que acontece se ele for retirado.
- Por que os três permanecem. Trocar o firewall por um proxy deixaria roteamento, zonas e o bloqueio DMZ → LAN sem a barreira que os separa.
- Cenário 1. Se o firewall voltar a permitir HTTP externo até a DMZ, o NGINX ainda esconde o `web` e ainda aplica `/admin` e o limite de métodos em quem entra pelo `rp`. Um acesso direto ao `web` só voltaria se a regra do firewall e o endereço do `web` fossem ambos alcançáveis. O texto deve separar essas duas falhas.
- Cenário 2. Se o `web` for comprometido, o atacante já está na DMZ. A sessão nova DMZ → LAN continua caindo no `DROP` do firewall. O Squid não fica nesse caminho. O NGINX não protege a rede contra um servidor que já foi dominado. Ele protege a exposição do serviço.
- Limites de cada camada: o firewall não distingue domínio nem URL. O Squid não separa as zonas. O NGINX não impede o `web` de iniciar uma conexão própria.

### Saberes

- Defense in Depth: barreiras complementares, não três cópias da mesma regra.
- Que informação existe em L3/L4 e que informação só aparece na requisição HTTP.
- Posição do atacante: fora da rede, na DMZ, ou já na LAN. A barreira útil muda com essa posição.

### Evidência

A análise no README, apoiada nos prints das etapas 4, 5, 7 e 8.

### Entregável

Texto curto que responde qual problema cada camada resolve e qual camada segue protegendo quando outra falha.

---

## 10. README, figura e registro de aprendizagem

### Objetivo

Fechar a entrega que a atividade pede num único repositório.

### Atividades

- Deixar o lab executável com `kathara lstart`, incluindo `fw`, `proxy`, `rp` e os nós que já existiam.
- Comentários nas configurações do firewall, do Squid e do NGINX.
- Figura da topologia atualizada.
- README com as evidências, nesta ordem:
  - LAN → Squid → Internet;
  - bloqueio de domínio pelo Squid;
  - cache;
  - Internet → NGINX → Web;
  - bloqueio do acesso direto Internet → Web;
  - os dois controles do NGINX;
  - os dois cenários de Defense in Depth.
- Seção “Como aprendemos”, preenchida durante o trabalho e não só no fim. Cada linha segue: dúvida ou problema, fonte consultada, o que foi aprendido, como o laboratório validou.
- Incluir prompts de IA que tenham mudado uma decisão. Uma resposta de IA não substitui o teste.
- Fechar com as quatro reflexões pedidas: o que foi preciso aprender sozinho, qual fonte foi mais útil, qual solução encontrada falhou e como isso apareceu no laboratório, e o que seria feito diferente.

### Saberes

- O que conta como evidência nesta Task: comando, resultado observado e log, não o texto da configuração sozinho.
- Como registrar uma fonte de verdade: documentação do Squid, do NGINX e do Kathará, separada de tutorial e de resposta gerada.

### Evidência

O próprio README e um `kathara lstart` limpo, a partir do repositório, reproduzindo os serviços.

### Entregável

Repositório único com lab, figura, configurações comentadas, evidências e a seção “Como aprendemos”.
