#!/bin/bash

LAB_DIR="$(cd "$(dirname "$0")" && pwd)"

lab_running() {
    kathara exec -d "$LAB_DIR" fw true >/dev/null 2>&1
}

start_lab() {
    if lab_running; then
        return 0
    fi

    echo
    echo "[+] Laboratorio nao esta rodando."
    echo "[+] Iniciando laboratorio..."

    if ! kathara lstart --noterminals -d "$LAB_DIR"; then
        echo "[ERRO] Nao foi possivel iniciar o laboratorio."
        return 1
    fi

    echo "[OK] Laboratorio iniciado."
}

reset_lab() {
    echo
    echo "[+] Reiniciando laboratorio..."

    if lab_running; then
        kathara lrestart --noterminals -d "$LAB_DIR"
    else
        kathara lstart --noterminals -d "$LAB_DIR"
    fi

    echo "[OK] Laboratorio voltou ao estado inicial."
}

while true; do

    echo
    echo "=========================================="
    echo "        KATHARA - DEMONSTRACAO"
    echo "=========================================="
    echo
    echo "1) Seguranca de Perimetro"
    echo "2) L2 - Bloqueio por MAC"
    echo "3) L3 - ICMP e bloqueio por IP"
    echo "4) L4 - Bloqueio de Portas"
    echo "5) L7 - WAF"
    echo "6) Defense in Depth"
    echo
    echo "r) Resetar laboratorio"
    echo "q) Sair"
    echo
    read -r -p "Escolha: " opcao

    case "$opcao" in

        1)
            if start_lab; then
                echo
                bash "$LAB_DIR/scenarios/01-perimetro.sh"
            fi
            ;;

        2)
            if start_lab; then
                echo
                bash "$LAB_DIR/scenarios/02-l2-mac.sh"
            fi
            ;;

        3)
            if start_lab; then
                echo
                bash "$LAB_DIR/scenarios/03-l3-rede.sh"
            fi
            ;;

        4)
            if start_lab; then
                echo
                bash "$LAB_DIR/scenarios/04-l4-portas.sh"
            fi
            ;;

        5)
            if start_lab; then
                echo
                bash "$LAB_DIR/scenarios/05-l7-waf.sh"
            fi
            ;;

        6)
            if start_lab; then
                echo
                bash "$LAB_DIR/scenarios/06-defense-in-depth.sh"
            fi
            ;;

        r|R)
            reset_lab
            ;;

        q|Q)
            echo
            echo "Demonstracao encerrada."
            exit 0
            ;;

        *)
            echo
            echo "[!] Opcao invalida."
            ;;

    esac

    echo
    read -r -p "Pressione ENTER para voltar ao menu..."

done