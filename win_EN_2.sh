#!/bin/bash
set -x 
#  	./tmp/win_RU.sh $secTillPayment $myMN_payoutAddress $myMN_balance $totalBalance $ip $myMN_cutProTxHash $7 ${MN_FILTERED[$n]} &
count=$1
# myMN_payoutAddress=$2
# myMN_balance=$3
# totalBalance=$4
# ip=$5
# myMN_cutProTxHash=$6
# pass_myMN_num=$7
# mnProTxHash=$8

echo "count=$1"
echo "myMN_payoutAddress=$2"
echo "myMN_balance=$3"
echo "totalBalance=$4"
echo "ip=$5"
echo "myMN_cutProTxHash=$6"
echo "pass_myMN_num=$7"
echo "myMN_NewPaidHeigh=$8"

sleep 15
# echo $count
# if [[ $count -gt 350 ]]; then
# 		count=$(( $count - 350 ))
# 		sleep $count
# fi
a=($(dash-cli masternode winners 1))
b=$(dash-cli getblockcount)
if [[ ${a[@]} =~ $2 ]]; then
# пока myMN_payoutAddress не появится в текущем блоке
# следим за текущим блоком и предыдущим , т к за <15 сек может пройти еще один блок и скрипт его пропустит )
		until [[ $(echo ${a[@]} | awk '{print$2$3$4$5}') =~ $8'":"'$2 ]]
		do
			sleep 15
			a=($(dash-cli masternode winners 1))
		done
else
   	title="error"
   	message="error"
   	curl -s \
	  --form-string "token=af3ktr7qch93wws14b6pxy6tyvfvfh" \
	  --form-string "user=u69uin39geyd7w4244sfbws6abd1wn" \
	  --form-string "sound=bike" \
	  --form-string "title=$title" \
	  --form-string "message=$message" \
	 https://api.pushover.net/1/messages.json &> /dev/null 
fi
 	b=$(dash-cli getblockcount)
 	c=$(dash-cli getblockhash $b)
	dataPayments=$(dash-cli masternode payments $c)
while read LINE; do
  	height=$(echo -e "$LINE"  | awk '{print $1}')
 	blockhash=$(echo -e "$LINE"  | awk '{print $2}')	
	proTxHash=$(echo -e "$LINE"  | awk '{print $3}')
	address=$(echo -e "$LINE"  | awk '{print $4}')
	amount=$(echo -e "$LINE"  | awk '{print $5}')
# \(.masternodes[] | .payees[0] | .amount Пример блок: 1505190 - в случае двух адресов на выплату , выбираем первый.
done < <(jq -r '.[]|"\(.height) \(.blockhash) \(.masternodes[] | .proTxHash) \(.masternodes[] | .payees[0] | .address) \(.masternodes[] | .payees[0] | .amount)"' <<< "$dataPayments")
echo -e "$height $blockhash $proTxHash $address $amount"
	block=$(echo ${a[@]} | awk '{print$4}')
echo $block
    title=$(echo -e "Выплата! Мн$7\n$5 ProTx-$6*")
	pymentAmountDash=$(echo "scale=1;$amount/100000000" | bc  )  
	mnBalance=$(echo "( $3 + $pymentAmountDash )" | bc ); echo $mnBalance
	totalBalance=$(echo "( $4 + $pymentAmountDash )" | bc ); echo $totalBalance
   	message=$(echo -e "в текущем блоке $8\nБаланс $mnBalance/$totalBalance")
	curl -s \
	  --form-string "token=af3ktr7qch93wws14b6pxy6tyvfvfh" \
	  --form-string "user=u69uin39geyd7w4244sfbws6abd1wn" \
	  --form-string "sound=bike" \
	  --form-string "title=$title" \
	  --form-string "message=$message" \
	 https://api.pushover.net/1/messages.json &> /dev/null 

 


