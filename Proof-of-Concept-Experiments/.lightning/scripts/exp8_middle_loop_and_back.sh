#!/bin/bash

# actors: Alice, Bob, Crol, Dave. Eve
# channels: Alice->Bob->Dave->Eve->Bob->Alice
# Use case: Normal (Everyone return secret), route with edge in both sides succeeds.

HOME='/home/ayelet'
. $HOME/.lightning/scripts/logger.sh

log_file="$HOME/.lightning/logs/exp8_middle_loop_and_back_$(date +'%d-%m-%Y-%H:%M:%S').log"

Alice_port=27592
Bob_port=27593
Crol_port=27594
Dave_port=27595
Eve_port=27596
amount_to_insert_lwallet=6
amount_to_insert_channel=16777215
payment_amount=1000000

. $HOME/.lightning/scripts/functions.sh -G $log_file

$HOME/.lightning/scripts/start_nodes.sh -G $log_file

create_channel Alice Bob $Bob_port $amount_to_insert_lwallet $amount_to_insert_channel

withdraw_remaining_amount Alice

create_channel Bob Dave $Dave_port $amount_to_insert_lwallet $amount_to_insert_channel

withdraw_remaining_amount Bob

create_channel Dave Eve $Eve_port $amount_to_insert_lwallet $amount_to_insert_channel

withdraw_remaining_amount Dave

create_channel Eve Bob $Bob_port $amount_to_insert_lwallet $amount_to_insert_channel

withdraw_remaining_amount Eve


alice_id=''
get_node_id Alice alice_id
bob_id=''
get_node_id Bob bob_id
crol_id=''
get_node_id Crol crol_id
dave_id=''
get_node_id Dave dave_id
eve_id=''
get_node_id Eve eve_id
sleep 2s

edebug "number of blocks: $(bitcoin-cli -datadir=$HOME/.bitcoin/Network getblockcount)" |& tee -a $log_file

inv=$($HOME/lightning/cli/lightning-cli --rpc-file=$HOME/.lightning/Bob/lightning-rpc invoice 200000000 "Alice_to_Crol-$(date +'%T:%N')" "$(date +'%T:%N') tx of 200000000 msat from Alice to Crol")

einfo "$inv" |& tee -a $log_file

bolt11=$(jq '.bolt11' <<< "$inv")

$HOME/lightning/cli/lightning-cli --rpc-file=$HOME/.lightning/Alice/lightning-rpc pay $bolt11

print_channel_balances Alice Bob
print_channel_balances Bob Dave
print_channel_balances Dave Eve
print_channel_balances Eve Bob

#### Alice pays Crol with loop #####

einfo "\n####### Alice transfers money to Alice through the lightning channel in a route with loop #######" |& tee -a $log_file

inv=$($HOME/lightning/cli/lightning-cli --rpc-file=$HOME/.lightning/Alice/lightning-rpc invoice $payment_amount "a-$(date +'%T:%N')" "$(date +'%T:%N') tx of $payment_amount msat a")

einfo "$inv" |& tee -a $log_file

payment_hash=$(jq '.payment_hash' <<< "$inv")

route="[
 {
    \"id\" : \"$bob_id\",
    \"channel\" : \"105x1x0\",
    \"direction\" : 0,
    \"msatoshi\" : $((payment_amount+4000)),
    \"amount_msat\" : \"$((payment_amount+4000))msat\",
    \"delay\" : 33
 },
{
    \"id\" : \"$dave_id\",
    \"channel\" : \"113x1x0\",
    \"direction\" : 0,
    \"msatoshi\" : $((payment_amount+3000)),
    \"amount_msat\" : \"$((payment_amount+3000))msat\",
    \"delay\" : 27
 },
{
    \"id\" : \"$eve_id\",
    \"channel\" : \"121x1x0\",
    \"direction\" : 0,
    \"msatoshi\" : $((payment_amount+2000)),
    \"amount_msat\" : \"$((payment_amount+2000))msat\",
    \"delay\" : 21
 },
{
    \"id\" : \"$bob_id\",
    \"channel\" : \"129x1x0\",
    \"direction\" : 0,
    \"msatoshi\" : $((payment_amount+1000)),
    \"amount_msat\" : \"$((payment_amount+1000))msat\",
    \"delay\" : 15
 },
{
    \"id\" : \"$alice_id\",
    \"channel\" : \"105x1x0\",
    \"direction\" : 0,
    \"msatoshi\" : $payment_amount,
    \"amount_msat\" : \"${payment_amount}msat\",
    \"delay\" : 9
 }
]"

echo "route=$route" |& tee -a $log_file

$HOME/lightning/cli/lightning-cli --rpc-file=$HOME/.lightning/Alice/lightning-rpc sendpay "$route" $payment_hash 

$HOME/lightning/cli/lightning-cli --rpc-file=$HOME/.lightning/Alice/lightning-rpc waitsendpay $payment_hash

print_channel_balances Alice Bob
print_channel_balances Bob Dave
print_channel_balances Dave Eve
print_channel_balances Eve Bob
