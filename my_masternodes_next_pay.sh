#!/bin/bash
#set -x

> ./protxinfo
> ./block_ip
# echo $(dash-cli protx list|jq -r '.[]')  >> protxlist.txt
# MASTERNODES=$(cat ./protxlist.txt)
# echo $(dash-cli protx list|jq -r 'join(" ")' | sed  's/\s\+/\n/g')  >> protxlist.txt
echo $(dash-cli protx list|jq -r 'join(" ")') > ./protx
MASTERNODES=($(cat ./protx))
	for (( i=0; i < ${#MASTERNODES[*]}; i++ ))
	do
 			dash-cli protx info ${MASTERNODES[$i]} >> protxinfo 					# построчная запись всех proTxHash 
			protx_info=$(dash-cli protx info ${MASTERNODES[$i]})					# protx info текущей MN
			reg_height=$(jq -r '.state.registeredHeight'<<<"$protx_info")			# блок registeredHeight
			banheight=$(jq -r '.state.PoSeBanHeight'<<<"$protx_info")				# PoSeBan
			PoSeRevivedHeight=$(jq -r '.state.PoSeRevivedHeight'<<<"$protx_info") 	# перерегистрация MN
			last_paid_height=$(jq -r '.state.lastPaidHeight'<<<"$protx_info")		# блок последней выплаты
			payoutAddress=$(jq -r '.state.payoutAddress'<<<"$protx_info")
			ip_port=$(jq -r '.state.service'<<<"$protx_info"|sed 's/:/ /g')			# ip 
			if [ "$banheight" -eq -1 ];then
				if [ "$PoSeRevivedHeight"  -lt "$last_paid_height" ];then
						if (( "$last_paid_height" > 0 )); then
							block=$(echo "$last_paid_height")
						else
							block=$(echo "$reg_height")
						fi
				else 
					block=$(echo "$PoSeRevivedHeight")
				fi
			echo "$block  ${MASTERNODES[$i]} $payoutAddress $ip_port " >> ./block_ip
			else 
				echo $banheight >> ./block_poseban		
			fi
	echo $i
	done
	
MY_MASTERNODES=(\
25e195c12334573e6f19505155efd12f4c22535a504f78ab40770de99fc10126 \
75d3bf6b4d6a5844bef4fd7dc21953ebaeddfac50a8c8d25ec8bb7aef4f0b72f \
1779a6d273177531dd7fbb397b609ccffdbe391adae8f1bdcc4c7b002c29658a \
d38fb2f9303b578b1d47d726581c83291c661bef7291eeb017f32390d160b640 \
a3cf9812bf59e07befe144e46dca847a2ca12e23360c8a8a4004323820003e9e \
4797d47cfffae5f0b200f4964f76d824f16fc8ff0569f248049e47ac67469ea7 \
4a450b8c0a2c4615cc9f6bf35689f534e4cc75335a443f85b5deb977af78919d)	
# 
# height new block 
height=$(echo "$(curl -Ls "https://chainz.cryptoid.info/dash/api.dws?q=getblockcount")")
# считываем инфо 
block_ip=$(cat ./block_ip)
# всего блоков в очереди
no_mn=$(echo "$block_ip" | wc -l)
# последний в очереди  на выплату
end_last_paid_height=$(echo "$(sort -k1 ./block_ip)" | (awk 'NR == 1{print $1}'))
# echo $end_last_paid_height
# первый в списке  на выплату
first_last_paid_height=$(echo "$(sort -k1 ./block_ip)"  | sed '$!d' | awk '{ print $1 }')
#  echo $first_last_paid_height
no_blocks_in_queue=$(( $echo $first_last_paid_height - $end_last_paid_height ))
# echo $no_blocks_in_queue
echo "$(sort -k1 ./block_ip)" | awk '{ print $_ " " ( '$end_last_paid_height' + '$no_blocks_in_queue' + 'i++') }' > ./sorted_block_ip
# new_pay_in_blockecho "$sorted_block_ip" > ./sorted_block_ip
sorted_block_ip=$(cat ./sorted_block_ip)
# n_blocks=$(echo "$sorted_block_ip" |  sed '1!{$!d}') ???
for (( n=0; n < ${#MY_MASTERNODES[*]}; n++ ))
do	
	info_myMN_QUEUE_POSITION_to_pay=$(echo "$sorted_block_ip" | grep ${MY_MASTERNODES[$n]}  | awk '{ print $_ " " ( $6 - '$height' ) }')
	echo $info_myMN_QUEUE_POSITION_to_pay 
	No_myMN_QUEUE_POSITION_to_pay=$(echo $info_myMN_QUEUE_POSITION_to_pay | awk '{ print $7 }')
# 	echo $No_myMN_QUEUE_POSITION_to_pay
	percent=$(echo "scale=1;100*( $no_mn - $No_myMN_QUEUE_POSITION_to_pay )/$no_mn" | bc -l )
 	percent_int=$(echo "$percent" | awk '{print int($1+0.5)}')
	ip=$(echo $info_myMN_QUEUE_POSITION_to_pay | awk '{ print $4 }')
	mn_last_paid_heigh=$(echo $info_myMN_QUEUE_POSITION_to_pay | awk '{ print $1 }')
	mn_last_paid_time=$(echo "$(curl -Ls "https://chainz.cryptoid.info/dash/api.dws?q=getblocktime&height=$mn_last_paid_heigh")")
	mn_new_paid_heigh=$(echo $info_myMN_QUEUE_POSITION_to_pay | awk '{ print $6 }')
	mn_new_paid_time=$(echo "$(curl -Ls "https://chainz.cryptoid.info/dash/api.dws?q=getblocktime&height=$mn_new_paid_heigh")")
	mn_payoutAddress=$(echo $info_myMN_QUEUE_POSITION_to_pay | awk '{ print $3 }')
	# echo $n , $mn_last_paid_time
	#Create ProgressBar	
	NOW_EPOCH=`date +%s`
	Dash_USD=$(echo "scale=1;$(curl -Ls "https://chainz.cryptoid.info/dash/api.dws?q=ticker.usd")/1" | bc -l  )
	myMN_BALANCE=$(echo "scale=1;$(curl -Ls "https://chainz.cryptoid.info/dash/api.dws?q=getbalance&a=$mn_payoutAddress")/1" | bc -l  )
	height=$(echo "$(curl -Ls "https://chainz.cryptoid.info/dash/api.dws?q=getblockcount")")
	# echo $height
	time1=$(echo "$(curl -Ls "https://chainz.cryptoid.info/dash/api.dws?q=getblocktime&height=$height")")
	# echo $time1
	time2=$(echo "$(curl -Ls "https://chainz.cryptoid.info/dash/api.dws?q=getblocktime&height=$(( $height - 10000))")")
	# echo $time2
	average_block_time=$( echo "($time1 - $time2)/10000" | bc )
	# 	echo $average_block_time
	i=$(( $NOW_EPOCH - $mn_last_paid_time ))
		((sec=i%60, i/=60, min=i%60, i/=60, hrs=i%24, i/=24, day=i%24))
		if [ $day -eq 0 ]; then 
			mn_last_paid_tstamp=$(printf "%dh%02dm" $hrs $min)	
		else
			mn_last_paid_tstamp=$(printf "%dd%02dh" $day $hrs)
		fi
	# 	echo $mn_last_paid_tstamp	
		mn_blocks_till_pyment=$(( $mn_new_paid_heigh - $height ))
	# 	echo $mn_blocks_till_pyment	
	# вычисляем сколько времени до выплаты в секундах (i=)	
	i=$(echo "scale=0;($mn_new_paid_heigh - $height)*$average_block_time/1"  | bc)
	# вычисляем  EPOCH время выплаты в секундах (mn_new_paid_time =)	
	mn_new_paid_time=$(( $NOW_EPOCH + $i ))
	echo $i , $mn_new_paid_time		
		((sec=i%60, i/=60, min=i%60, i/=60, hrs=i%24, i/=24, day=i%24))
		if [ $day -eq 0 ]; then 
			if [ $(perl -le 'print scalar localtime $ARGV[0]' $mn_new_paid_time | awk '{ print $3 }') -eq $(perl -le 'print scalar localtime $ARGV[0]' $NOW_EPOCH | awk '{ print $3 }') ]; then
			d="New payment today at"
			else 
			d="New payment tomorrow at"
			fi
# 			mn_left_till_payment_tstamp=$(printf "%dh%02dm"  $hrs $min)
			mn_left_till_payment_tstamp=$(perl -le 'print scalar localtime $ARGV[0]' $mn_new_paid_time | awk '{ print $4 }' | sed -e "s/.\{,3\}$//")
			# https://askdev.ru/q/kak-udalit-posledniy-simvol-iz-vyvoda-bash-grep-72931/
# 			awk -v date="$mn_new_paid_time" '/Hello/ { print $2 }'
			line_one="block"
		else
		unset d 
		line_one="left till payment in block"
		mn_left_till_payment_tstamp=$(printf "%dd%02dh%02dm" $day $hrs $min)
		fi
	#     echo $mn_left_till_payment_tstamp 
			let _done=($percent_int*6)/10 
			let _left=60-$_done 
			_done=$(printf "%${_done}s")
			_left=$(printf "%${_left}s")
	printf "$d $mn_left_till_payment_tstamp $line_one $mn_new_paid_heigh\n[${_done// /|}${_left// /:}] $percent%%\nLast payment was $mn_last_paid_tstamp ago in $mn_last_paid_heigh \nBALANCE=$myMN_BALANCE"Dash" 1Dash=$Dash_USD$" > ./nvar		
			nvar=$(echo "$(cat ./nvar)")
			myvar=$(echo -e "Masternode $ip  position $No_myMN_QUEUE_POSITION_to_pay/$no_mn")
	curl -s \
	  --form-string "token=af3ktr7qch93wws14b6pxy6tyvfvfh" \
	  --form-string "user=u69uin39geyd7w4244sfbws6abd1wn" \
	  --form-string "sound=bike" \
	  --form-string "title=$myvar" \
	  --form-string "message=$nvar" \
  https://api.pushover.net/1/messages.json &> /dev/null 
done
  
  