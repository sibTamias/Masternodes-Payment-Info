#!/bin/bash
# set -x

echo "update!"
echo $1
if [[ $1 -gt 400 ]]; then
		count=$(( $1 - 400 ))
		sleep $count
fi
MY_MASTERNODES=($8)
all_mns_list=$(dash-cli protx list registered 1)
> ./tmp/block_ip_$7
> ./tmp/poseban_ip_$7
> ./tmp/my_up_payoutAddress_$7
> ./tmp/myMN_up_num_$7
# A function to print out each MN (protx) in order of next to the be paid (first) to last to be paid at the bottom.
# First column is the line number, the second column is the protxhash, ....
while read proTxHash registeredHeight PoSeBanHeight lastPaidHeight PoSeRevivedHeight payoutAddress service PoSePenalty junk;do
	proTxHash=$proTxHash				# protx info текущей MN
	registeredHeight=$registeredHeight	#  registeredHeight
	PoSeBanHeight=$PoSeBanHeight			# PoSeBan
	PoSeRevivedHeight=$PoSeRevivedHeight	# перерегистрация MN
	lastPaidHeight=$lastPaidHeight	#  последней выплаты
	payoutAddress=$payoutAddress
	ipPort=$(awk -F: '{print $1}' <<< "$service")	# ip 
	PoSePenalty=$PoSePenalty
	if [ "$PoSeBanHeight" -eq -1 ];then
		if [ "$PoSeRevivedHeight"  -lt "$lastPaidHeight" ];then
				if (( "$lastPaidHeight" > 0 )); then
					block=$(echo "$lastPaidHeight")
				else
					block=$(echo "$registeredHeight")
				fi
		else 
			block=$(echo "$PoSeRevivedHeight")
		fi
	echo "$block $proTxHash $payoutAddress $ipPort $lastPaidHeight" >> ./tmp/block_ip_$7
	else 
		echo $proTxHash $ipPort >> ./tmp/poseban_ip_$7		
	fi
done < <(jq -r '.[]|"\(.proTxHash) \(.state.registeredHeight) \(.state.PoSeBanHeight) \(.state.lastPaidHeight) \(.state.PoSeRevivedHeight) \(.state.payoutAddress) \(.state.service) \(.state.PoSePenalty)"' <<< "$all_mns_list") | sort -n -k2 | awk '{print NR " " $0}'

block_ip=$(cat ./tmp/block_ip_$7)
totalAmountMN=$(echo "$block_ip" | wc -l)
endLastPaidHeight=$(echo "$(sort -k1 ./tmp/block_ip_$7)" | (awk 'NR == 1{print $1}'))
firstLastPaidHeight=$(echo "$(sort -k1 ./tmp/block_ip_$7)"  | sed '$!d' | awk '{ print $1 }')
no_blocks_in_queue=$(( $echo $firstLastPaidHeight - $endLastPaidHeight + 1 ))	
echo "$(sort -k1 ./tmp/block_ip_$7)" | awk '{ print $_ " " ( '$endLastPaidHeight' + '$no_blocks_in_queue' + 'i++') }' > ./tmp/sorted_up_block_ip

ARRAY_POSEBAN_IP=()
while IFS= read -r line; do
	ARRAY_POSEBAN_IP+=( "$line" )
done <  ./tmp/poseban_ip_$7

MN_FILTERED=($(dash-cli protx list|jq -r '.[]'|grep $(sed 's/ /\\|/g'<<<"${MY_MASTERNODES[@]}" )))
sorted_block_ip=$(cat ./tmp/sorted_up_block_ip)
for (( n=0; n < ${#MY_MASTERNODES[*]}; n++ ))
do	
	m=$(( $n+1 ))
	##### попутно присваиваем моим мастернодам номер в списке.
	echo  "${MY_MASTERNODES[n]}" | awk '{ print $_ " " ( '$n'+1 ) }' >> ./tmp/myMN_up_num_$7
	myMN_cutProTxHash=$(echo ${MY_MASTERNODES[$n]} | cut -c1-4 )
	#####
	if [[ " ${ARRAY_POSEBAN_IP[@]} " =~ " ${MY_MASTERNODES[$n]} " ]]; then
		myMN_PoSeBanIP=$(echo "${ARRAY_POSEBAN_IP[n]}" | awk '{ print $2 }')
		BODY+="MN($m) $myMN_PoSeBanIP ProTx($myMN_cutProTxHash***) PoSeBanned!\n" 
	else
		if [[ " ${MN_FILTERED[@]} " =~ " ${MY_MASTERNODES[$n]} " ]]; then
			echo "$sorted_block_ip" | grep ${MY_MASTERNODES[$n]} | awk '{ print $3 }' >> ./tmp/my_up_payoutAddress_$7
		else
			BODY+="MN($m) ProTx($myMN_cutProTxHash***) не найдена! Проверь ProTxHash !\n"
		fi
	fi
done
myMN_num=$(cat ./tmp/myMN_up_num_$7)
for i in "${MN_FILTERED[@]}"; do
    skip=
    for j in "${ARRAY_POSEBAN_IP[@]}"; do
   s=$(echo $j | awk '{ print $1 }')
        [[ $i == $s ]] && { skip=1; break; }
    done
    [[ -n $skip ]] || MN_FILTERED_w_BAN+=("$i")
done
MN_FILTERED=("${MN_FILTERED_w_BAN[@]}")
unset MN_FILTERED_w_BAN
######
cat ./tmp/my_up_payoutAddress_$7 | sort -u > ./tmp/sort_up_my_payoutAddress
ARRAY_PAYOUT_ADDRESS=()
while IFS= read -r line; do
	ARRAY_PAYOUT_ADDRESS+=( "$line" )
done <  ./tmp/sort_up_my_payoutAddress
#
height=$(dash-cli getblockcount)
for (( n=0; n < ${#MN_FILTERED[*]}; n++ ))
do
	pass_myMN_num=$(echo "$myMN_num" | grep ${MN_FILTERED[$n]} | awk '{ print $2 }')
	infoMyMN_QeuePositionToPayment=$(echo "$sorted_block_ip" | grep ${MN_FILTERED[$n]}  | awk '{ print $_ " " ( $6 - '$height' ) }')
echo "infoMyMN_QeuePositionToPayment=$infoMyMN_QeuePositionToPayment"
	ip=$(echo $infoMyMN_QeuePositionToPayment | awk '{ print $4 }')
	myMN_NewPaidHeigh=$(echo $infoMyMN_QeuePositionToPayment | awk '{ print $6 }') # echo "Update_myMN_NewPaidHeigh=$myMN_NewPaidHeigh"
	myMN_payoutAddress=$(echo $infoMyMN_QeuePositionToPayment | awk '{ print $3 }')
	myMN_cutProTxHash=$(echo ${MN_FILTERED[$n]} | cut -c1-4 )
	rateDashUSD=$(echo "scale=1;$(curl -Ls "https://chainz.cryptoid.info/dash/api.dws?q=ticker.usd")/1" | bc -l  )
# 	myMN_LastPaidTime=$(echo "$(dash-cli getblock $( dash-cli getblockhash $myMN_LastPaidHeigh) | jq -r  .time)")
done
warning=$(printf "$BODY")
curl -s \
  --form-string "token=af3ktr7qch93wws14b6pxy6tyvfvfh" \
  --form-string "user=u69uin39geyd7w4244sfbws6abd1wn" \
  --form-string "sound=bike" \
  --form-string "title=Warning!" \
  --form-string "message=$warning" \
https://api.pushover.net/1/messages.json &> /dev/null 
sleep 1
a=($(dash-cli masternode winners 1))
echo "winners=${a[@]}"
b=$(dash-cli getblockcount)
echo "getblockcount=$b"
echo "myMN_NewPaidHeigh=$myMN_NewPaidHeigh"
echo "myMN_payoutAddress=$myMN_payoutAddress"
if [[ ${a[@]} =~ $myMN_payoutAddress ]]; then 
echo "проверяем наличие адреса в списке winners"
# пока myMN_payoutAddress не появится в текущем блоке
# следим за текущим блоком и предыдущим , где уже бвла оплата , т к за <15 сек может пройти еще один блок и скрипт его пропустит )
		until [[ $(echo ${a[@]} | awk '{print$2$3$4$5$6}') =~ $myMN_NewPaidHeigh'":"'$myMN_payoutAddress ]]
		do
		echo "sleep10 $(dash-cli getblockcount)"
			sleep 10
			a=($(dash-cli masternode winners 1))
		done
		echo "найден!"
else
	echo "myMN_payoutAddress не найден"
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
 	b=$(dash-cli getblockcount) #текущий блок
 	c=$(dash-cli getblockhash $b) #protx блока
	dataPayments=$(dash-cli masternode payments $c) 
	echo "dataPayments=$dataPayments"
while read LINE; do
echo "читаем информацию о выплате"
  	height=$(echo -e "$LINE"  | awk '{print $1}') # номер блока
 	blockhash=$(echo -e "$LINE"  | awk '{print $2}') # protx блока	 
	proTxHash=$(echo -e "$LINE"  | awk '{print $3}') # protx мастерноды зарегитрировавшей блок в блокчейне
	address=$(echo -e "$LINE"  | awk '{print $4}') # адрес выплаты
	amount=$(echo -e "$LINE"  | awk '{print $5}') # величина выплаты  
# \(.masternodes[] | .payees[0] | .amount Пример блок: 1505190 - в случае двух адресов на выплату , выбираем первый.
done < <(jq -r '.[]|"\(.height) \(.blockhash) \(.masternodes[] | .proTxHash) \(.masternodes[] | .payees[0] | .address) \(.masternodes[] | .payees[0] | .amount)"' <<< "$dataPayments")
    title=$(echo -e "MN$pass_myMN_num $ip\nProTx-$myMN_cutProTxHash*")
	pymentAmountDash=$(echo "scale=1;$amount/100000000" | bc  )  
	totalBalance=$(echo "( $3 + $pymentAmountDash)" | bc )
# 	echo "totalBalance_2_162=$totalBalance"
	mnBalance=$(echo "( $3 + $pymentAmountDash )" | bc )
	message=$(echo -e "Зачислено $pymentAmountDash Dash в текущем блоке $height\nБаланс $mnBalance/$totalBalance Dash  1Dash=$rateDashUSD$")
	curl -s \
	  --form-string "token=af3ktr7qch93wws14b6pxy6tyvfvfh" \
	  --form-string "user=u69uin39geyd7w4244sfbws6abd1wn" \
	  --form-string "sound=bike" \
	  --form-string "title=$title" \
	  --form-string "message=$message" \
	 https://api.pushover.net/1/messages.json &> /dev/null 





