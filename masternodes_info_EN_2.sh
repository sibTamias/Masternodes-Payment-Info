#!/bin/bash
#set -x

MY_MASTERNODES=(
237fdf83eff8ec26dce4c2c6966e1363a5a311b1a2a8f6d5a61e2516fed70d83
# 25e195c12334573e6f19505155efd12f4c22535a504f78ab40770de99fc10126
# a3cf9812bf59e07befe144e46dca847a2ca12e23360c8a8a4004323820003e9e
# 1779a6d273177531dd7fbb397b609ccffdbe391adae8f1bdcc4c7b002c29658a
# d38fb2f9303b578b1d47d726581c83291c661bef7291eeb017f32390d160b640
# 4797d47cfffae5f0b200f4964f76d824f16fc8ff0569f248049e47ac67469ea7
# 4a450b8c0a2c4615cc9f6bf35689f534e4cc75335a443f85b5deb977af78919d
# 75d3bf6b4d6a5844bef4fd7dc21953ebaeddfac50a8c8d25ec8bb7aef4f0b72f
# e5deb272685095cb4ce916337a86f4cf41ac3e747a1cf6294906a0821aaab5a3
# 08f8825860a3806732080298f52260ab7931845709257d6bcf60b56e7bc5c8dd
# ca15a05d139ab7773d74bf366cf8dac17491aaba2db6d98ca7932492176b423b
)
# Checks that the required software is installed on this machine.
bc -v >/dev/null 2>&1 || progs+=" bc"
jq -V >/dev/null 2>&1 || progs+=" jq"

if [[ -n $progs ]];then
	text="Missing applications on your system, please run\n\n"
	text+="\tsudo apt install $progs\n\nbefore running this program again."
	echo -e "$text" >&2
	exit 1
fi
all_mns_list=$(dash-cli protx list registered 1)
if (( $? != 0 ));then
	echo "Problem running dash-cli, make sure it is in your path and working..."
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
endLastPaidHeight=$(echo "$(sort -k1 ./tmp/block_ip)" | (awk 'NR == 1{print $1}'))
firstLastPaidHeight=$(echo "$(sort -k1 ./tmp/block_ip)"  | sed '$!d' | awk '{ print $1 }')
no_blocks_in_queue=$(( $echo $firstLastPaidHeight - $endLastPaidHeight + 1 ))	
echo "$(sort -k1 ./tmp/block_ip)" | awk '{ print $_ " " ( '$endLastPaidHeight' + '$no_blocks_in_queue' + 'i++') }' > ./tmp/sorted_block_ip

ARRAY_POSEBAN_IP=()
while IFS= read -r line; do
	ARRAY_POSEBAN_IP+=( "$line" )
done <  ./tmp/poseban_ip

MN_FILTERED=($(dash-cli protx list|jq -r '.[]'|grep $(sed 's/ /\\|/g'<<<"${MY_MASTERNODES[@]}" )))
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
			BODY+="MN($m) ProTx($myMN_cutProTxHash***) is mission! Check ProTxHash is correct!\n"
		fi
	fi
done
myMN_num=$(cat ./tmp/myMN_num)
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
####### EN
echo "myMN_LastPaidHeigh= $myMN_LastPaidHeigh"
	if [ "$myMN_LastPaidHeigh" -eq 0 ];then
		lastPaid_text="payments had not yet been made\n"
	else	
	myMN_LastPaidTime=$(echo "$(curl -Ls "https://chainz.cryptoid.info/dash/api.dws?q=getblocktime&height=$myMN_LastPaidHeigh")")
echo "myMN_LastPaidTime=$myMN_LastPaidTime"
	l=$(( $nowEpoch - $myMN_LastPaidTime ))
		((sec=l%60, l/=60, min=l%60, l/=60, hrs=l%24, l/=24, day=l%24))
		if [ $day -eq 0 ]; then 
			myMN_lastPaidTstamp=$(printf "%dd%02dh" $hrs $min)	# если дней =0 то выводим часы и минуты
		else
			myMN_lastPaidTstamp=$(printf "%dd" $day )	# если дней >0 то выводим дни 
		fi
	lastPaid_text="Paymant was $myMN_lastPaidTstamp ago in block $myMN_LastPaidHeigh \n"
	fi
		mn_blocks_till_pyment=$(( $myMN_NewPaidHeigh - $height ))
		f=$(echo "scale=0;$mn_blocks_till_pyment*$averageBlockTime/1"  | bc) # сек до выплаты
		myMN_NewPaidTime=$(( $nowEpoch + $f ))
		untilMidnight=$(($(date -d 'tomorrow 00:00:00' +%s) - $(date +%s))) # сек до полуночи 
		PayTimeTilllMidnight=$(( $f - $untilMidnight ))  # из сек до оплаты вычитаем сек до полуночи, 
			if [ "$PayTimeTilllMidnight" -lt 0 ]; then # если <0 , то выплата до плоyночи сегодня
				d="Paymant today at"
				myMN_leftTillPaymentTstamp=$(perl -le 'print scalar localtime $ARGV[0]' $myMN_NewPaidTime | awk '{ print $4 }' | sed -e "s/.\{,3\}$//")
				line_one="block"
				secTillPayment=$(( $myMN_NewPaidTime- $nowEpoch )) 
				if [ $secTillPayment -lt 14400 ]; then
				./masternodes_info_update_EN_2.sh $secTillPayment $myMN_payoutAddress $myMN_balance $totalBalance $ip $myMN_cutProTxHash $pass_myMN_num ${MN_FILTERED[$n]} &
				fi					
			else 
				if [ "$PayTimeTilllMidnight" -gt 86400 ]; then   # если >24 часа т е за послезавтра )
					unset d 
					line_one="until paymant in block"
					((sec=f%60, f/=60, min=f%60, f/=60, hrs=f%24, f/=24, day=f%24))
						if [ "$hrs" -gt 4 ]; then
							line_hrs="%02d hours"
						else 
							if [ "$hrs" -eq 1 ]; then
								line_hrs="%02d hour"
							else
								hrs="%02d hour"
							fi
						fi
						if [ "$day" -gt 4 ]; then
					myMN_leftTillPaymentTstamp=$(printf "%d days" $day)
						else 
							if [ "$day" -eq 1 ]; then
# 					myMN_leftTillPaymentTstamp=$(printf "%d день $line_hrs" $day $hrs)
					d="Payment day after tomorrow at"
					myMN_leftTillPaymentTstamp=$(perl -le 'print scalar localtime $ARGV[0]' $myMN_NewPaidTime | awk '{ print $4 }' | sed -e "s/.\{,3\}$//")
					line_one="in"
							else
					myMN_leftTillPaymentTstamp=$(printf "%d days" $day)
							fi
						fi
				else # если >0 но  ( те PayTimeTilllMidnight >0 но < 24 часа ( до полуночи завтра) )
					d="Payment tomorrow at"
					myMN_leftTillPaymentTstamp=$(perl -le 'print scalar localtime $ARGV[0]' $myMN_NewPaidTime | awk '{ print $4 }' | sed -e "s/.\{,3\}$//")
					line_one="in"
				fi
			fi
			let _done=($percentInt*5)/10 
			let _left=50-$_done 
			_done=$(printf "%${_done}s")
			_left=$(printf "%${_left}s")
# 			lastPaid_text="Выплата была $myMN_lastPaidTstamp назад в блоке $myMN_LastPaidHeigh \n"
	printf "$d $myMN_leftTillPaymentTstamp $line_one $myMN_NewPaidHeigh\n[${_done// /|}${_left// /:}] $percentInt%%\n$lastPaid_text Balance: $myMN_balance/$totalBalance Dash  1Dash=$rateDashUSD$" > ./tmp/nvar		
			nvar=$(echo "$(cat ./tmp/nvar)")			
# 			pass_myMN_num=$(echo "$myMN_num" | grep ${MN_FILTERED[$n]} | awk '{ print $2 }')
			myvar=$(echo -e "MN$pass_myMN_num position $position/$totalAmountMN\n$ip ProTx-$myMN_cutProTxHash*")
## RU
	curl -s \
	  --form-string "token=af3ktr7qch93wws14b6pxy6tyvfvfh" \
	  --form-string "user=u69uin39geyd7w4244sfbws6abd1wn" \
	  --form-string "sound=bike" \
	  --form-string "title=$myvar" \
	  --form-string "message=$nvar" \
  	https://api.pushover.net/1/messages.json &> /dev/null   	
#   progressLength=50
# 	progressMade=$(echo "scale=2;($totalAmountMN-$position)/$totalAmountMN*$progressLength"|bc|awk '{printf("%d\n",$1 + 0.5)}')
# 	progressRemaining=$((progressLength-progressMade))
# 	progressBar="["
#  	for((i=0; i<progressMade; i++));do progressBar+='|';done
# 	for((i=0; i<progressRemaining; i++));do progressBar+=':';done
# 	progressBar+="]"
# # 	progressPercent=$(printf '%0.2f' $(echo "scale=4;($numMyMN-$position)/$numMyMN*100"|bc))
# 
# 	printf "$d $myMN_leftTillPaymentTstamp $line_one $myMN_NewPaidHeigh\n$progressBar $percent%%\nВыплата была $myMN_lastPaidTstamp назад в блоке $myMN_LastPaidHeigh \nБаланс: $myMN_balance/$totalBalance Dash  1Dash=$rateDashUSD$" > ./tmp/nvar1	
# nvar1=$(echo "$(cat ./tmp/nvar1)")
# 	curl -s \
# 	  --form-string "token=af3ktr7qch93wws14b6pxy6tyvfvfh" \
# 	  --form-string "user=u69uin39geyd7w4244sfbws6abd1wn" \
# 	  --form-string "sound=bike" \
# 	  --form-string "title=$myvar" \
# 	  --form-string "message=$nvar1" \
#   	https://api.pushover.net/1/messages.json &> /dev/null 
  	
done
warning=$(printf "$BODY")
curl -s \
  --form-string "token=af3ktr7qch93wws14b6pxy6tyvfvfh" \
  --form-string "user=u69uin39geyd7w4244sfbws6abd1wn" \
  --form-string "sound=bike" \
  --form-string "title=Warning!" \
  --form-string "message=$warning" \
https://api.pushover.net/1/messages.json &> /dev/null 
