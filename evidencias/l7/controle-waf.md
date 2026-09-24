### L7 — WAF (Web Application Firewall)

Escolhemos o **WAF** como controle de L7 porque ele consegue analisar as requisições da aplicação web, indo além de IP, protocolo e porta.

Ele fica entre o cliente e o servidor e pode aplicar regras com base na própria requisição HTTP/HTTPS. Por exemplo:

```text
/public → permitir
/admin  → bloquear
```

Também pode identificar padrões de ataques, como **SQL Injection** e **XSS**.

A diferença para as camadas anteriores é:

```text
L2 → MAC
L3 → IP
L4 → TCP/UDP e portas
L7 → requisição e comportamento da aplicação
```
