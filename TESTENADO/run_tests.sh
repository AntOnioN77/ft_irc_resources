#!/bin/bash
# run_tests.sh - Suite de tests para ft_irc
#
# Requiere:
#   - ./irc_test_client (compilado a partir de irc_test_client.cpp)
#   - ./ircserv corriendo en HOST:PORT con PASSWORD
#
# Uso: ./run_tests.sh [host] [port] [password]

HOST="${1:-127.0.0.1}"
PORT="${2:-6667}"
PASSWORD="${3:-abc}"
TIMEOUT_MS=400

CLIENT="./irc_test_client $HOST $PORT $TIMEOUT_MS"

PASS_COUNT=0
FAIL_COUNT=0
BOT_PIDS=()

# ============================================================
# Funciones auxiliares
# ============================================================

cleanup_bots() {
    local pid
    for pid in "${BOT_PIDS[@]}"; do
        kill "$pid" 2>/dev/null
    done
    wait 2>/dev/null
    sleep 0.3
    rm -f /tmp/ircbot_$$_*.log
    BOT_PIDS=()
}

trap 'cleanup_bots; exit 130' INT TERM
trap cleanup_bots EXIT

print_header() {
    echo ""
    echo "########################################"
    echo "# $1"
    echo "########################################"
}

print_test() {
    echo "----------------------------------------"
    echo "TEST: $1"
}

show_result() {
    echo "  Recibido:"
    echo "$1" | sed 's/^/    /'
}

mark_pass() {
    echo "  -> PASS"
    PASS_COUNT=$((PASS_COUNT + 1))
}

mark_fail() {
    echo "  -> FAIL: $1"
    FAIL_COUNT=$((FAIL_COUNT + 1))
}

# test_case <nombre> <comandos> <patron_grep_esperado>
test_case() {
    local name="$1"
    local cmds="$2"
    local expected="$3"

    print_test "$name"
    local result
    result=$(printf "%b" "$cmds" | $CLIENT)

    echo "  Esperado (grep): $expected"
    show_result "$result"

    if echo "$result" | grep -q -- "$expected"; then
        mark_pass
    else
        mark_fail "patron no encontrado"
    fi
}

# start_bot <nick> <channel> [key] [lifetime_seconds]
# Bot que se registra, hace JOIN y se queda vivo.
start_bot() {
    local nick="$1"
    local channel="$2"
    local key="$3"
    local lifetime="${4:-20}"
    local join_args="$channel"
    [ -n "$key" ] && join_args="$channel $key"

    {
        printf "PASS %s\nNICK %s\nUSER %s 0 * :bot %s\nJOIN %s\n" \
            "$PASSWORD" "$nick" "$nick" "$nick" "$join_args"
        sleep "$lifetime"
    } | $CLIENT > "/tmp/ircbot_$$_${nick}.log" 2>&1 &
    BOT_PIDS+=($!)
}

# start_bot_cmd <nick> <comandos_extra> [lifetime]
# Bot que se registra y ejecuta comandos arbitrarios despues.
start_bot_cmd() {
    local nick="$1"
    local extra_cmds="$2"
    local lifetime="${3:-20}"

    {
        printf "PASS %s\nNICK %s\nUSER %s 0 * :bot %s\n" \
            "$PASSWORD" "$nick" "$nick" "$nick"
        printf "%b" "$extra_cmds"
        sleep "$lifetime"
    } | $CLIENT > "/tmp/ircbot_$$_${nick}.log" 2>&1 &
    BOT_PIDS+=($!)
}

settle() {
    sleep "${1:-1.2}"
}

# ============================================================
# SECCION 1: REGISTRO
# ============================================================

print_header "SECCION 1: REGISTRO"

# TEST1: PASS -> USER -> NICK
test_case "TEST1: registro PASS->USER->NICK" \
    "PASS $PASSWORD\nUSER foo 0 * :foo real name\nNICK antofoo1\n" \
    " 001 antofoo1"

# TEST2: PASS -> NICK -> USER
test_case "TEST2: registro PASS->NICK->USER" \
    "PASS $PASSWORD\nNICK antofoo2\nUSER foo 0 * :foo real name\n" \
    " 001 antofoo2"

# TEST3: PASS tras registro completo -> ERR_ALREADYREGISTRED (462)
test_case "TEST3: PASS tras registro completo -> 462" \
    "PASS $PASSWORD\nUSER foo 0 * :foo\nNICK antofoo3\nPASS $PASSWORD\n" \
    " 462 "

# TEST6: PASS incorrecto -> ERR_PASSWDMISMATCH (464)
test_case "TEST6: PASS incorrecto -> 464" \
    "PASS wrongpass\nUSER foo 0 * :foo\nNICK antofoo6\n" \
    " 464 "

# TEST7a: PASS doble pre-registro: el segundo (correcto) sobreescribe al primero (wrong)
test_case "TEST7a: PASS wrong + PASS correcto -> 001" \
    "PASS wrongpass\nPASS $PASSWORD\nUSER foo 0 * :foo\nNICK antofoo7a\n" \
    " 001 antofoo7a"

# TEST7b: PASS doble pre-registro: el segundo (wrong) sobreescribe al primero (correcto)
test_case "TEST7b: PASS correcto + PASS wrong -> 464" \
    "PASS $PASSWORD\nPASS wrongpass\nUSER foo 0 * :foo\nNICK antofoo7b\n" \
    " 464 "

# TEST8: JOIN antes de registrar -> ERR_NOTREGISTERED (451)
test_case "TEST8: JOIN antes de registrar -> 451" \
    "JOIN #foo\n" \
    " 451 "

# TEST9: registro sin PASS -> ERR_PASSWDMISMATCH (464)
test_case "TEST9: registro sin PASS -> 464" \
    "USER foo 0 * :foo\nNICK antofoo9\n" \
    " 464 "

# ============================================================
# SECCION 2: JOIN BASICO
# ============================================================

print_header "SECCION 2: JOIN BASICO"

# TEST15: JOIN canal nuevo (0 previos) -> @nick en RPL_NAMREPLY
test_case "TEST15: JOIN canal nuevo (0 previos) -> @alice" \
    "PASS $PASSWORD\nNICK alice15\nUSER alice 0 * :alice\nJOIN #test15\n" \
    " 353 .*@alice15"

# TEST16: JOIN con key correcta
print_test "TEST16: JOIN con key correcta"
start_bot_cmd bot16 "JOIN #test16\nMODE #test16 +k mykey\n"
settle 1.5
result=$(printf "PASS %s\nNICK alice16\nUSER alice 0 * :alice\nJOIN #test16 mykey\n" "$PASSWORD" | $CLIENT)
echo "  Esperado: JOIN al canal + 366"
show_result "$result"
if echo "$result" | grep -q "JOIN.*#test16" && echo "$result" | grep -q " 366 "; then
    mark_pass
else
    mark_fail "no se completo JOIN con key"
fi
cleanup_bots

# TEST17: JOIN con key incorrecta -> ERR_BADCHANNELKEY (475)
print_test "TEST17: JOIN con key incorrecta -> 475"
start_bot_cmd bot17 "JOIN #test17\nMODE #test17 +k mykey\n"
settle 1.5
result=$(printf "PASS %s\nNICK alice17\nUSER alice 0 * :alice\nJOIN #test17 wrongkey\n" "$PASSWORD" | $CLIENT)
echo "  Esperado (grep):  475 "
show_result "$result"
if echo "$result" | grep -q " 475 "; then
    mark_pass
else
    mark_fail "no se observo 475"
fi
cleanup_bots

# TEST18: JOIN invite-only sin INVITE -> ERR_INVITEONLYCHAN (473)
print_test "TEST18: JOIN invite-only sin INVITE -> 473"
start_bot_cmd bot18 "JOIN #test18\nMODE #test18 +i\n"
settle 1.5
result=$(printf "PASS %s\nNICK alice18\nUSER alice 0 * :alice\nJOIN #test18\n" "$PASSWORD" | $CLIENT)
echo "  Esperado (grep):  473 "
show_result "$result"
if echo "$result" | grep -q " 473 "; then
    mark_pass
else
    mark_fail "no se observo 473"
fi
cleanup_bots

# TEST19: JOIN invite-only tras recibir INVITE -> OK
# Timing critico: bot19 entra, pone +i, espera 2s, invita a alice19.
# alice19 se registra de inmediato y espera 1.8s antes de hacer JOIN.
print_test "TEST19: JOIN invite-only tras INVITE"
{
    printf "PASS %s\nNICK bot19\nUSER bot19 0 * :bot\nJOIN #test19\nMODE #test19 +i\n" "$PASSWORD"
    sleep 2
    printf "INVITE alice19 #test19\n"
    sleep 3
} | $CLIENT > "/tmp/ircbot_$$_bot19.log" 2>&1 &
BOT_PIDS+=($!)

sleep 1  # bot19 ya esta en el canal y +i aplicado

result=$( { \
    printf "PASS %s\nNICK alice19\nUSER alice 0 * :alice\n" "$PASSWORD"; \
    sleep 1.8; \
    printf "JOIN #test19\n"; \
} | $CLIENT )

echo "  Esperado: JOIN al canal y ausencia de 473"
show_result "$result"
if echo "$result" | grep -q "JOIN.*#test19" && ! echo "$result" | grep -q " 473 "; then
    mark_pass
else
    mark_fail "no se completo el JOIN tras INVITE"
fi
cleanup_bots

# TEST20: JOIN canal lleno (+l) -> ERR_CHANNELISFULL (471)
print_test "TEST20: JOIN canal lleno (+l 2 con 2 dentro) -> 471"
start_bot_cmd bot20a "JOIN #test20\nMODE #test20 +l 2\n"
settle 1.2
start_bot bot20b "#test20"
settle 1.2
result=$(printf "PASS %s\nNICK alice20\nUSER alice 0 * :alice\nJOIN #test20\n" "$PASSWORD" | $CLIENT)
echo "  Esperado (grep):  471 "
show_result "$result"
if echo "$result" | grep -q " 471 "; then
    mark_pass
else
    mark_fail "no se observo 471"
fi
cleanup_bots

# TEST21: JOIN multiples canales (JOIN #a,#b)
print_test "TEST21: JOIN multiples canales (#test21a,#test21b)"
result=$(printf "PASS %s\nNICK alice21\nUSER alice 0 * :alice\nJOIN #test21a,#test21b\n" "$PASSWORD" | $CLIENT)
count_366=$(echo "$result" | grep -c " 366 ")
has_a=$(echo "$result" | grep -c " 366 alice21 #test21a")
has_b=$(echo "$result" | grep -c " 366 alice21 #test21b")
echo "  RPL_ENDOFNAMES totales: $count_366 (#test21a: $has_a, #test21b: $has_b)"
show_result "$result"
if [ "$count_366" -ge 2 ] && [ "$has_a" -ge 1 ] && [ "$has_b" -ge 1 ]; then
    mark_pass
else
    mark_fail "no se completo JOIN a ambos canales"
fi

# ============================================================
# SECCION 3: NAMREPLY CHUNKING
# Verifica los tres flujos: <, ==, > 35 miembros.
# El test cuenta nicks y RPL_NAMREPLY recibidos; muestra el conteo
# para que valides si tu chunking se comporta como esperas.
# ============================================================

print_header "SECCION 3: NAMREPLY CHUNKING"

# test_chunk <nombre> <n_clientes_previos> <canal>
test_chunk() {
    local name="$1"
    local n_prev="$2"
    local channel="$3"

    print_test "$name (previos: $n_prev, total esperado: $((n_prev + 1)))"

    local i
    if [ "$n_prev" -gt 0 ]; then
        for i in $(seq 1 "$n_prev"); do
            start_bot "cbot$i" "$channel" "" 30
        done
        # Tiempo proporcional al numero de bots
        local wait_t
        wait_t=$(awk "BEGIN{print 1 + $n_prev * 0.08}")
        sleep "$wait_t"
    fi

    local result
    result=$(printf "PASS %s\nNICK testchk\nUSER testchk 0 * :test\nJOIN %s\n" "$PASSWORD" "$channel" | $CLIENT)

    local count_353
    count_353=$(echo "$result" | grep -c " 353 ")
    local total_nicks
    total_nicks=$(echo "$result" | grep " 353 " | awk -F' :' '{print $NF}' | tr ' ' '\n' | grep -cv '^$')
    local has_366
    has_366=$(echo "$result" | grep -c " 366 ")
    local expected_total=$((n_prev + 1))

    echo "  RPL_NAMREPLY (353) recibidas: $count_353"
    echo "  Nicks sumados en todas las 353: $total_nicks (esperado: $expected_total)"
    echo "  RPL_ENDOFNAMES (366) recibido: $has_366"
    show_result "$result"

    if [ "$total_nicks" -eq "$expected_total" ] && [ "$has_366" -ge 1 ] && [ "$count_353" -ge 1 ]; then
        mark_pass
    else
        mark_fail "conteo de nicks o numericos no coincide"
    fi

    cleanup_bots
}

test_chunk "CHUNK-LT: 0 previos (1 total, < 35)"  0  "#chunklt"
test_chunk "CHUNK-EQ: 34 previos (35 totales)"    34 "#chunkeq"
test_chunk "CHUNK-GT: 35 previos (36 totales)"    35 "#chunkgt"

# ============================================================
# RESUMEN
# ============================================================

echo ""
echo "########################################"
echo "# Resultado: $PASS_COUNT pass, $FAIL_COUNT fail"
echo "########################################"

[ $FAIL_COUNT -eq 0 ] && exit 0 || exit 1
