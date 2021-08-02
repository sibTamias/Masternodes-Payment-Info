#!/bin/bash
#set -x

MY_MASTERNODES=(
237fdf83eff8ec26dce4c2c6966e1363a5a311b1a2a8f6d5a61e2516fed70d83
f2f0400ecc79c2e2944c5af879c9de434e637edd79fc8b85820d86ebc6c70f47
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
	proTxHash=$proTxHash				# protx info current MN
	registeredHeight=$registeredHeight	#   block registered Height
	PoSeBanHeight=$PoSeBanHeight			# block PoSeBan 
	PoSeRevivedHeight=$PoSeRevivedHeight	# # block revive  MN
	lastPaidHeight=$lastPaidHeight	#   block last paymant
	payoutAddress=$payoutAddress #  payout address
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

ARRAY_POSEBAN_IP=()
while IFS= read -r line; do
	ARRAY_POSEBAN_IP+=( "$line" )
done <  ./tmp/poseban_ip

MN_FILTERED=($(dash-cli protx list|jq -r '.[]'|grep $(sed 's/ /\\|/g'<<<"${MY_MASTERNODES[@]}" )))
sorted_block_ip=$(cat ./tmp/sorted_block_ip)
for (( n=0; n < ${#MY_MASTERNODES[*]}; n++ ))
do	
	m=$(( $n+1 ))
	##### 
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
# total Balance
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
			myMN_lastPaidTstamp=$(printf "%dh%02dm" $hrs $min)	# если дней =0 то выводим часы и минуты
		else
			myMN_lastPaidTstamp=$(printf "%dd" $day )	# если дней >0 то выводим дни 
		fi
	lastPaid_text="Paymant was $myMN_lastPaidTstamp ago at bcock $myMN_LastPaidHeigh \n"
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
				./masternodes_info_update_EN.sh $secTillPayment $myMN_payoutAddress $myMN_balance $totalBalance $ip $myMN_cutProTxHash $pass_myMN_num ${MN_FILTERED[$n]} &
				fi					
			else 
				if [ "$PayTimeTilllMidnight" -gt 172800 ]; then   # если >24 часа т е за послезавтра )
					unset d 
					line_one="until paymant in block"
					((sec=f%60, f/=60, min=f%60, f/=60, hrs=f%24, f/=24, day=f%24))
						if [ "$day" -gt 4 ]; then
					myMN_leftTillPaymentTstamp=$(printf "%d days" $day)
						else 
					myMN_leftTillPaymentTstamp=$(printf "%d days" $day)
						fi
				else
					if [ "$PayTimeTilllMidnight" -gt 86400 ]; then
					d="Payment day after tomorrow at"
						myMN_leftTillPaymentTstamp=$(perl -le 'print scalar localtime $ARGV[0]' $myMN_NewPaidTime | awk '{ print $4 }' | sed -e "s/.\{,3\}$//")
						line_one="in"
					else
					d="Payment tomorrow at"
						myMN_leftTillPaymentTstamp=$(perl -le 'print scalar localtime $ARGV[0]' $myMN_NewPaidTime | awk '{ print $4 }' | sed -e "s/.\{,3\}$//")
						line_one="in"
					fi
				fi
			fi	
			let _done=($percentInt*5)/10 
			let _left=50-$_done  
			_done=$(printf "%${_done}s")
			_left=$(printf "%${_left}s")
	printf "$d $myMN_leftTillPaymentTstamp $line_one $myMN_NewPaidHeigh\n[${_done// /|}${_left// /:}] $percentInt%%\n$lastPaid_textBalance: $myMN_balance/$totalBalance Dash  1Dash=$rateDashUSD$" > ./tmp/nvar		
			nvar=$(echo "$(cat ./tmp/nvar)")			
			myvar=$(echo -e "MN$pass_myMN_num position $position/$totalAmountMN\n$ip ProTx-$myMN_cutProTxHash*")
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
