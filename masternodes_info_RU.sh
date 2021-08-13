#!/bin/bash
#set -x

# MY_MASTERNODES=($1)
MY_MASTERNODES=(
25e195c12334573e6f19505155efd12f4c22535a504f78ab40770de99fc10126
a3cf9812bf59e07befe144e46dca847a2ca12e23360c8a8a4004323820003e9e
1779a6d273177531dd7fbb397b609ccffdbe391adae8f1bdcc4c7b002c29658a
d38fb2f9303b578b1d47d726581c83291c661bef7291eeb017f32390d160b640
4797d47cfffae5f0b200f4964f76d824f16fc8ff0569f248049e47ac67469ea7
4a450b8c0a2c4615cc9f6bf35689f534e4cc75335a443f85b5deb977af78919d
75d3bf6b4d6a5844bef4fd7dc21953ebaeddfac50a8c8d25ec8bb7aef4f0b72f
e5deb272685095cb4ce916337a86f4cf41ac3e747a1cf6294906a0821aaab5a3
b809e32118de93843bb2a2f0653590352328e8bcdbfa4d9ad62d3bb4258d5b7a
50dc85a3954b896724bfb67ee73076ce4db4d50d1055be77f172e23917d04d50
 )
# Checks that the required software is installed on this machine.
bc -v >/dev/null 2>&1 || progs+=" bc"
jq -V >/dev/null 2>&1 || progs+=" jq"

if [[ -n $progs ]];then
	text="Missing applications on your system, please run\n"
	text+="\tsudo apt install $progs\nbefore running this program again."
	message=$(echo -e "$text")
curl -s \
  --form-string "token=af3ktr7qch93wws14b6pxy6tyvfvfh" \
  --form-string "user=u69uin39geyd7w4244sfbws6abd1wn" \
  --form-string "sound=bike" \
  --form-string "title=Warning!" \
  --form-string "message=$message" \
https://api.pushover.net/1/messages.json &> /dev/null 

	exit 1
fi
all_mns_list=$(dash-cli protx list registered 1)
if (( $? != 0 ));then
	warning="Problem running dash-cli, make sure it is in your path and working..."
curl -s \
  --form-string "token=af3ktr7qch93wws14b6pxy6tyvfvfh" \
  --form-string "user=u69uin39geyd7w4244sfbws6abd1wn" \
  --form-string "sound=bike" \
  --form-string "title=Warning!" \
  --form-string "message=$warning" \
https://api.pushover.net/1/messages.json &> /dev/null 

	exit 1
fi

###### Code1

> ./tmp/block_ip
> ./tmp/poseban_ip
> ./tmp/my_payoutAddress
> ./tmp/myMN_num
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
	echo "$block $proTxHash $payoutAddress $ipPort $lastPaidHeight" >> ./tmp/block_ip
	else 
		echo $proTxHash $ipPort >> ./tmp/poseban_ip		
	fi
done < <(jq -r '.[]|"\(.proTxHash) \(.state.registeredHeight) \(.state.PoSeBanHeight) \(.state.lastPaidHeight) \(.state.PoSeRevivedHeight) \(.state.payoutAddress) \(.state.service) \(.state.PoSePenalty)"' <<< "$all_mns_list") | sort -n -k2 | awk '{print NR " " $0}'

block_ip=$(cat ./tmp/block_ip)
totalAmountMN=$(echo "$block_ip" | wc -l)
# queue_length=$(wc -l <<< "$orderedPaymentList")
endLastPaidHeight=$(echo "$(sort -k1 ./tmp/block_ip)" | (awk 'NR == 1{print $1}'))
firstLastPaidHeight=$(echo "$(sort -k1 ./tmp/block_ip)"  | sed '$!d' | awk '{ print $1 }')
no_blocks_in_queue=$(( $echo $firstLastPaidHeight - $endLastPaidHeight + 1 ))	
echo "$(sort -k1 ./tmp/block_ip)" | awk '{ print $_ " " ( '$endLastPaidHeight' + '$no_blocks_in_queue' + 'i++') }' > ./tmp/sorted_block_ip
# содаем массив мастернод сос статусом PoSeBanned (proTxHash ipPort)
ARRAY_POSEBAN_IP=()
while IFS= read -r line; do
	ARRAY_POSEBAN_IP+=( "$line" )
done <  ./tmp/poseban_ip
# из моих (MY_MASTERNODES) мастернод, удаляем которых нет в блокчейне , новый массив (MN_FILTERED)
MN_FILTERED=($(dash-cli protx list|jq -r '.[]'|grep $(sed 's/ /\\|/g'<<<"${MY_MASTERNODES[@]}" )))
# опять проверяем список MY_MASTERNODES на статус PoSeBann и отсутствие в блокчейне, 
# и в конце скрипта отправляем сообщение о мастернодах со станусом "не найдена!" и "PoSeBanned!"
sorted_block_ip=$(cat ./tmp/sorted_block_ip)
for (( n=0; n < ${#MY_MASTERNODES[*]}; n++ ))
do 
	m=$(( $n+1 ))
	##### попутно присваиваем моим мастернодам номер в списке.
	echo  "${MY_MASTERNODES[n]}" | awk '{ print $_ " " ( '$n'+1 ) }' >> ./tmp/myMN_num
	myMN_cutProTxHash=$(echo ${MY_MASTERNODES[$n]} | cut -c1-4 )
	##### 
	if [[ " ${ARRAY_POSEBAN_IP[@]} " =~ " ${MY_MASTERNODES[$n]} " ]]; then
		myMN_PoSeBanIP=$(echo "${ARRAY_POSEBAN_IP[n]}" | awk '{ print $2 }')
		BODY+="MN($m) $myMN_PoSeBanIP ProTx($myMN_cutProTxHash***) PoSeBanned!\n" 
	else
		if [[ " ${MN_FILTERED[@]} " =~ " ${MY_MASTERNODES[$n]} " ]]; then
			echo "$sorted_block_ip" | grep ${MY_MASTERNODES[$n]} | awk '{ print $3 }' >> ./tmp/my_payoutAddress
		else
			BODY+="MN($m) ProTx($myMN_cutProTxHash***) не найдена!. Проверь ProTxHash !.\n"
		fi
	fi
done
#
myMN_num=$(cat ./tmp/myMN_num)
# корректируем массив MN_FILTERED, удаляем масттерноды со статусом PoSeBan
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
cat ./tmp/my_payoutAddress | sort -u > ./tmp/sort_my_payoutAddress
ARRAY_PAYOUT_ADDRESS=()
while IFS= read -r line; do
	ARRAY_PAYOUT_ADDRESS+=( "$line" )
done <  ./tmp/sort_my_payoutAddress
totalBalance=0
# вычисляем суммарный баланс
for i in ${!ARRAY_PAYOUT_ADDRESS[@]}; 
do
	totalBalance=$(bc<<<"scale=1;$totalBalance+$(echo "$(curl -Ls "https://chainz.cryptoid.info/dash/api.dws?q=getbalance&a=${ARRAY_PAYOUT_ADDRESS[$i]}")/1" )")
done
######
height=$(dash-cli getblockcount)
for (( n=0; n < ${#MN_FILTERED[*]}; n++ ))
do
	pass_myMN_num=$(echo "$myMN_num" | grep ${MN_FILTERED[$n]} | awk '{ print $2 }')
	infoMyMN_QeuePositionToPayment=$(echo "$sorted_block_ip" | grep ${MN_FILTERED[$n]}  | awk '{ print $_ " " ( $6 - '$height' ) }')
echo "infoMyMN_QeuePositionToPayment=$infoMyMN_QeuePositionToPayment"
	position=$(echo $infoMyMN_QeuePositionToPayment | awk '{ print $7 }')
echo "position1=$position"
	percent=$(echo "scale=1;100*( $totalAmountMN - $position )/$totalAmountMN" | bc -l )
	percentInt=$(echo "$percent" | awk '{print int($1+0.5)}')
	ip=$(echo $infoMyMN_QeuePositionToPayment | awk '{ print $4 }')
	myMN_LastPaidHeigh=$(echo $infoMyMN_QeuePositionToPayment | awk '{ print $5 }')
	myMN_NewPaidHeigh=$(echo $infoMyMN_QeuePositionToPayment | awk '{ print $6 }') 
	myMN_payoutAddress=$(echo $infoMyMN_QeuePositionToPayment | awk '{ print $3 }')
	myMN_cutProTxHash=$(echo ${MN_FILTERED[$n]} | cut -c1-4 )
	nowEpoch=`date +%s`
	rateDashUSD=$(echo "scale=1;$(curl -Ls "https://chainz.cryptoid.info/dash/api.dws?q=ticker.usd")/1" | bc -l  )
	myMN_balance=$(echo "scale=1;$(curl -Ls "https://chainz.cryptoid.info/dash/api.dws?q=getbalance&a=$myMN_payoutAddress")/1" | bc -l  )
	averageBlockTime=157.5
####### RU
echo "myMN_LastPaidHeigh= $myMN_LastPaidHeigh"
	if [ "$myMN_LastPaidHeigh" -eq 0 ];then
		lastPaid_text="Выплаты еще не было \n"
	else	
	myMN_LastPaidTime=$(echo "$(dash-cli getblock $( dash-cli getblockhash $myMN_LastPaidHeigh) | jq -r  .time)")
echo "myMN_LastPaidTime=$myMN_LastPaidTime"
	l=$(( $nowEpoch - $myMN_LastPaidTime ))
		((sec=l%60, l/=60, min=l%60, l/=60, hrs=l%24, l/=24, day=l%24))
		if [ $day -eq 0 ]; then 
			myMN_lastPaidTstamp=$(printf "%dч%02dм" $hrs $min)	# если дней =0 то выводим часы и минуты
		else
			myMN_lastPaidTstamp=$(printf "%dд" $day )	# если дней >0 то выводим дни 
		fi
	lastPaid_text="Выплата была $myMN_lastPaidTstamp назад в блоке $myMN_LastPaidHeigh \n"
	fi
		mn_blocks_till_pyment=$(( $myMN_NewPaidHeigh - $height ))
		f=$(echo "scale=0;$mn_blocks_till_pyment*$averageBlockTime/1"  | bc) # сек до выплаты
		myMN_NewPaidTime=$(( $nowEpoch + $f ))
		untilMidnight=$(($(date -d 'tomorrow 00:00:00' +%s) - $(date +%s))) # сек до полуночи 
		PayTimeTilllMidnight=$(( $f - $untilMidnight ))  # из сек до оплаты вычитаем сек до полуночи, 
			if [ "$PayTimeTilllMidnight" -lt 0 ]; then # если <0 , то выплата до плоyночи сегодня
				d="Выплата сегодня в"
				myMN_leftTillPaymentTstamp=$(perl -le 'print scalar localtime $ARGV[0]' $myMN_NewPaidTime | awk '{ print $4 }' | sed -e "s/.\{,3\}$//")
				line_one="блок"
				secTillPayment=$(( $myMN_NewPaidTime- $nowEpoch )) 
				if [ $secTillPayment -lt 14400 ]; then
				./masternodes_info_update_RU.sh $secTillPayment $myMN_payoutAddress $myMN_balance $totalBalance $ip $myMN_cutProTxHash $pass_myMN_num ${MN_FILTERED[$n]} &
				fi					
			else 
				if [ "$PayTimeTilllMidnight" -gt 172800 ]; then   # если >24 часа т е за послезавтра )
					unset d 
					line_one="до выплаты в блоке"
					((sec=f%60, f/=60, min=f%60, f/=60, hrs=f%24, f/=24, day=f%24))
						if [ "$day" -gt 4 ]; then
					myMN_leftTillPaymentTstamp=$(printf "%d дней" $day)
						else 
					myMN_leftTillPaymentTstamp=$(printf "%d дня" $day)
						fi
				else
					if [ "$PayTimeTilllMidnight" -gt 86400 ]; then
						d="Выплата послезавтра в"
						myMN_leftTillPaymentTstamp=$(perl -le 'print scalar localtime $ARGV[0]' $myMN_NewPaidTime | awk '{ print $4 }' | sed -e "s/.\{,3\}$//")
						line_one="в блоке"
					else
						d="Выплата завтра в"
						myMN_leftTillPaymentTstamp=$(perl -le 'print scalar localtime $ARGV[0]' $myMN_NewPaidTime | awk '{ print $4 }' | sed -e "s/.\{,3\}$//")
						line_one="в блоке"
					fi
				fi
			fi	
			let _done=($percentInt*5)/10 
			let _left=50-$_done  
			_done=$(printf "%${_done}s")
			_left=$(printf "%${_left}s")
	printf "$d $myMN_leftTillPaymentTstamp $line_one $myMN_NewPaidHeigh\n[${_done// /|}${_left// /:}] $percentInt%%\n$lastPaid_textБаланс: $myMN_balance/$totalBalance Dash  1Dash=$rateDashUSD$" > ./tmp/nvar		
			nvar=$(echo "$(cat ./tmp/nvar)")			
			myvar=$(echo -e "MN$pass_myMN_num позиция $position/$totalAmountMN\n$ip ProTx-$myMN_cutProTxHash*")
## RU
	curl -s \
	  --form-string "token=af3ktr7qch93wws14b6pxy6tyvfvfh" \
	  --form-string "user=u69uin39geyd7w4244sfbws6abd1wn" \
	  --form-string "sound=bike" \
	  --form-string "title=$myvar" \
	  --form-string "message=$nvar" \
  	https://api.pushover.net/1/messages.json &> /dev/null   	
done
warning=$(printf "$BODY")
curl -s \
  --form-string "token=af3ktr7qch93wws14b6pxy6tyvfvfh" \
  --form-string "user=u69uin39geyd7w4244sfbws6abd1wn" \
  --form-string "sound=bike" \
  --form-string "title=Warning!" \
  --form-string "message=$warning" \
https://api.pushover.net/1/messages.json &> /dev/null 
