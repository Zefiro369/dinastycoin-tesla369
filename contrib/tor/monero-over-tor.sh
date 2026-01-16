#!/bin/bash

DIR=$(realpath $(dirname $0))

echo "Checking dinastycoind..."
dinastycoind=""
for dir in \
  . \
  "$DIR" \
  "$DIR/../.." \
  "$DIR/build/release/bin" \
  "$DIR/../../build/release/bin" \
  "$DIR/build/Linux/master/release/bin" \
  "$DIR/../../build/Linux/master/release/bin" \
  "$DIR/build/Windows/master/release/bin" \
  "$DIR/../../build/Windows/master/release/bin"
do
  if test -x "$dir/dinastycoind"
  then
    dinastycoind="$dir/dinastycoind"
    break
  fi
  then
    dinastycoind="$dir/dinastycoind"
    break
  fi
done
if test -z "$dinastycoind"
then
  echo "dinastycoind not found"
  exit 1
fi
echo "Found: $dinastycoind"

TORDIR="$DIR/dinastycoin-over-tor"
TORRC="$TORDIR/torrc"
HOSTNAMEFILE="$TORDIR/hostname"
echo "Creating configuration..."
mkdir -p "$TORDIR"
chmod 700 "$TORDIR"
rm -f "$TORRC"
cat << EOF > "$TORRC"
ControlSocket $TORDIR/control
ControlSocketsGroupWritable 1
CookieAuthentication 1
CookieAuthFile $TORDIR/control.authcookie
CookieAuthFileGroupReadable 1
HiddenServiceDir $TORDIR
HiddenServicePort 18083 127.0.0.1:18083
EOF

echo "Starting Tor..."
nohup tor -f "$TORRC" 2> "$TORDIR/tor.stderr" 1> "$TORDIR/tor.stdout" &
ready=0
for i in `seq 10`
do
  sleep 1
  if test -f "$HOSTNAMEFILE"
  then
    ready=1
    break
  fi
done
if test "$ready" = 0
then
  echo "Error starting Tor"
  cat "$TORDIR/tor.stdout"
  exit 1
fi

echo "Starting dinastycoind..."
HOSTNAME=$(cat "$HOSTNAMEFILE")
"$dinastycoind" \
  --anonymous-inbound "$HOSTNAME":37175,127.0.0.1:37175,25 --tx-proxy tor,127.0.0.1:9050,10 \
  --add-priority-node 7mv6kgrmpxa6aiqp.onion:37175 \
  --add-priority-node 43bqd7gsafndmcmd.onion:37175 \
  --detach
ready=0
for i in `seq 10`
do
  sleep 1
  status=$("$dinastycoind" status)
  echo "$status" | grep -q "Height:"
  if test $? = 0
  then
    ready=1
    break
  fi
done
if test "$ready" = 0
then
  echo "Error starting dinastycoind"
  tail -n 400 "$HOME/.dinastycoin/dinsatycoin.log" | grep -Ev stacktrace\|"Error: Couldn't connect to daemon:"\|"src/daemon/main.cpp:.*Monero\ \'" | tail -n 20
  exit 1
fi

echo "Ready. Your Tor hidden service is $HOSTNAME"
