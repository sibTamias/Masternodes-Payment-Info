#!/bin/bash
#set -x

# MY_MASTERNODES=($1)
MY_MASTERNODES=(
7d8cbe202440dadcf2592a3c1786bc6792832ff6e3697d27585cb3adbd9272f8
a0e40e35e1c75b7132f8f1e9d2714421a0df10f38975d0f55f7f6012dd081a7e
233f109446f91a054999f2ec3a76fb8e2193ebb5723fce9e3fb388bd7d91179b
41ba88a75b38ea127db7436ec380dadca341f1f9570afb6437481b3a1f73a935
23af73b3e5e8015f019841bbd04895630876d730aa44cedd52fe8b0631c25130
523f7c4a249699b376bee65ac902d9d5b4a91e050aacc895cad58cccf0777252
6c50b2d79aecadb3925657b5b16d4ff8db8946b7a30ad3086b723cce65a278fc
3a1b85f3828892a5b6ba82d1c79966dfb7dc46ec94068dda6af2fe4067f319d6
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
> ./tmp/allvar
> ./tmp/all_messeges

# функция перевода секунд в часы минуты секунды для строки 105
convertsecs() {
 ((h=${1}/3600))
 ((m=(${1}%3600)/60))
 ((s=${1}%60))
 printf "%02d:%02d:%02d\n" $h $m $s
}
# 
# convertsecs() {
#  h=$(bc <<< "${1}/3600")
#  m=$(bc <<< "(${1}%3600)/60")
#  s=$(bc <<< "${1}%60")
#  printf "%02d:%02d:%05.2f\n" $h $m $s
# }

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
# содаем массив мастернод со статусом PoSeBanned (proTxHash ipPort)
ARRAY_POSEBAN_IP=()
while IFS= read -r line; do
	ARRAY_POSEBAN_IP+=( "$line" )
done <  ./tmp/poseban_ip
# из моих (MY_MASTERNODES) мастернод, удаляем которых нет в блокчейне , новый массив (MN_FILTERED)
MN_FILTERED=($(dash-cli protx list|jq -r '.[]'|grep $(sed 's/ /\\|/g'<<<"${MY_MASTERNODES[@]}" )))
# echo ${MN_FILTERED[@]}
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
MN_FILTERED=("${MN_FILTERED_w_BAN[@]}")  	# мои мастерноды без статуса PoSeBanned
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
######  основной цикл 
# сотировка вывода в Pushover по номеру моих мастернод MN1, MN2, ... MN10
result=() 
MN_FILTERED=" ${MN_FILTERED[*]} "   
for item in ${MY_MASTERNODES[@]}; do
  if [[ $MN_FILTERED =~ " $item " ]] ; then    # use $item as regexp
    result+=($item)
  fi
done
# echo  ${result[@]}


height=$(dash-cli getblockcount)
for (( n=0; n < ${#MN_FILTERED[*]}; n++ ))
do
	pass_myMN_num=$(echo "$myMN_num" | grep ${result[$n]} | awk '{ print $2 }')
# echo "pass_myMN_num=$pass_myMN_num"
	infoMyMN_QeuePositionToPayment=$(echo "$sorted_block_ip" | grep ${result[$n]}  | awk '{ print $_ " " ( $6 - '$height' ) }')
# echo "infoMyMN_QeuePositionToPayment=$infoMyMN_QeuePositionToPayment"
	position=$(echo $infoMyMN_QeuePositionToPayment | awk '{ print $7 }')
# echo "position1=$position"
	percent=$(echo "scale=1;100*( $totalAmountMN - $position )/$totalAmountMN" | bc -l )
	percentInt=$(echo "$percent" | awk '{print int($1+0.5)}')
	ip=$(echo $infoMyMN_QeuePositionToPayment | awk '{ print $4 }')
	myMN_LastPaidHeigh=$(echo $infoMyMN_QeuePositionToPayment | awk '{ print $5 }')
	myMN_NewPaidHeigh=$(echo $infoMyMN_QeuePositionToPayment | awk '{ print $6 }') 
	myMN_payoutAddress=$(echo $infoMyMN_QeuePositionToPayment | awk '{ print $3 }')
	myMN_cutProTxHash=$(echo ${MN_FILTERED[$n]} | cut -c1-4 )
	nowEpoch=`date +%s`
	rateDashUSD=$(echo "scale=1;$(curl -Ls "https://chainz.cryptoid.info/dash/api.dws?q=ticker.usd")/1" | bc -l  )
# 	myMN_balance=$(printf %.1f $(echo "$(dash-cli getaddressbalance '{"addresses": ["'$myMN_payoutAddress'"]}' | jq -r .balance)/100000000" | bc -l))
 	myMN_balance=$(echo "scale=1;$(curl -Ls "https://chainz.cryptoid.info/dash/api.dws?q=getbalance&a=$myMN_payoutAddress")/1" | bc -l  )
	averageBlockTime=157.5
	myMN_balance_usd=$(printf %.1f $(echo "$myMN_balance*$rateDashUSD" | bc -l))
	totalBalance_usd=$(printf %.1f $(echo "$totalBalance*$rateDashUSD" | bc -l))
####### RU
# echo "myMN_LastPaidHeigh= $myMN_LastPaidHeigh"
	if [ "$myMN_LastPaidHeigh" -eq 0 ];then
		lastPaid_text="Выплаты еще не было"
	else	
	myMN_LastPaidTime=$(echo "$(dash-cli getblock $( dash-cli getblockhash $myMN_LastPaidHeigh) | jq -r  .time)")
# echo "myMN_LastPaidTime=$myMN_LastPaidTime"
	l=$(( $nowEpoch - $myMN_LastPaidTime ))
		((sec=l%60, l/=60, min=l%60, l/=60, hrs=l%24, l/=24, day=l%24))
		if [ $day -eq 0 ]; then 
			if [ $hrs -eq 0 ]; then
			myMN_lastPaidTstamp=$(printf "%dм" $min)	# если дней =0  и час =0 то выводим  минуты
			else
			myMN_lastPaidTstamp=$(printf "%dч" $hrs)	# если дней =0 то выводим часы
			fi
		else
			myMN_lastPaidTstamp=$(printf "%dд" $day )	# если дней >0 то выводим дни 
		fi
	lastPaid_text="Выплата была $myMN_lastPaidTstamp назад в блоке $myMN_LastPaidHeigh"
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
				BODY+="MN$pass_myMN_num - выплата через $(convertsecs $secTillPayment)"		
# 				./masternodes_info_update_RU.sh $secTillPayment $myMN_payoutAddress $myMN_balance $totalBalance $ip $myMN_cutProTxHash $pass_myMN_num ${MN_FILTERED[$n]} &
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
			let _done=($percentInt*6)/10 
			let _left=60-$_done  
			_done=$(printf "%${_done}s")
			_left=$(printf "%${_left}s")
	echo "$myMN_NewPaidHeigh TITLE MN$pass_myMN_num позиция $position/$totalAmountMN\n$ip ProTx-$myMN_cutProTxHash* MESSEGE $d $myMN_leftTillPaymentTstamp $line_one $myMN_NewPaidHeigh\n[${_done// /|}${_left// /:}] $percentInt%\n$lastPaid_text\nБаланс: $myMN_balance($myMN_balance_usd$)/$totalBalance($totalBalance_usd$)\nКурс:1Dash=$rateDashUSD$" >> ./tmp/allvar
done
########
cat ./tmp/allvar | sort -t " " -rk1 >  ./tmp/sort_allvar 
while IFS= read -r line
do
	title=$(echo -e "$(echo  "$line" | sed 's/^.*TITLE// ; s/MESSEGE.*//')") # внутренний echo извлекает текст между TITLE - MESSEGE, второй выполняет переводы строк - "\n"
	message=$(echo -e "$(echo "$line" | sed 's/^.*MESSEGE//')") #  внутренний echo извлекает текст после MESSEGE , второй выполняет переводы строк - "\n

  curl -s \
	  --form-string "token=af3ktr7qch93wws14b6pxy6tyvfvfh" \
	  --form-string "user=u69uin39geyd7w4244sfbws6abd1wn" \
	  --form-string "sound=bike" \
	  --form-string "title=$title" \
	  --form-string "message=$message" \
  	https://api.pushover.net/1/messages.json &> /dev/null   
  sleep 1
done < ./tmp/sort_allvar 

warning=$(printf "$BODY")
curl -s \
  --form-string "token=af3ktr7qch93wws14b6pxy6tyvfvfh" \
  --form-string "user=u69uin39geyd7w4244sfbws6abd1wn" \
  --form-string "sound=bike" \
  --form-string "title=Warning!" \
  --form-string "message=$warning" \
https://api.pushover.net/1/messages.json &> /dev/null 
