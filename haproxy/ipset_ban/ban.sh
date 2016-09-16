SOURCE="$1"
THRESHOLD=3
SIZE=20480

cat $SOURCE | awk '{print $4}' | awk -F':' '{print $1}' > hack.ip
sort hack.ip | uniq -cd | awk -v limit=$THRESHOLD '$1 > limit{print $2}' > ban.ip
wc -l ban.ip

#iptables -D INPUT 1
#ipset destroy blacklist
ipset create blacklist hash:ip hashsize $SIZE
cat ban.ip | xargs -I IP bash -c "echo IP; ipset add blacklist IP"
iptables -I INPUT  -m set --match-set blacklist src -p TCP --destination-port 443 -j REJECT
