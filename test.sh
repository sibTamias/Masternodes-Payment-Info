#!/bin/bash
#set -x

# В первом блоке добавлен код проверки ProTxHash в блокчейне  

#######
MY_MASTERNODES=(\
25e195c12334573e6f19505155efd12f4c22535a504f78ab40770de99fc10126 \
75d3bf6b4d6a5844bef4fd7dc21953ebaeddfac50a8c8d25ec8bb7aef4f0b72f \
1779a6d273177531dd7fbb397b609ccffdbe391adae8f1bdcc4c7b002c29658a \
d38fb2f9303b578b1d47d726581c83291c661bef7291eeb017f32390d160b640 \
a3cf9812bf59e07befe144e46dca847a2ca12e23360c8a8a4004323820003e91 \
4797d47cfffae5f0b200f4964f76d824f16fc8ff0569f248049e47ac67469ea7 \
4a450b8c0a2c4615cc9f6bf35689f534e4cc75335a443f85b5deb977af78919d \
e5deb272685095cb4ce916337a86f4cf41ac3e747a1cf6294906a0821aaab5a3 \
)

PROG="$0"
echo $PROG
# Checks that the required software is installed on this machine.
check_dependencies(){

	nc -h >/dev/null 2>&1 || progs+=" netcat"
	jq -V >/dev/null 2>&1 || progs+=" jq"
	mailx -V >/dev/null 2>&1 || progs+=" mailx"
	

	if [[ -n $progs ]];then
		text="$PROG	Missing applications on your system, please run\n\n"
		text+="sudo apt install $progs\n\nbefore running this program again."
		echo -e "$text" >&2
		exit 1
	fi
}
check_dependencies

#CODE1

> ./block_ip
echo $(dash-cli protx list|jq -r 'join(" ")' | sed  's/\s\+/\n/g')  >> protxlist.txt
echo $(dash-cli protx list|jq -r 'join(" ")') > ./protx
MASTERNODES=($(cat ./protx))
	for (( i=0; i < ${#MASTERNODES[*]}; i++ ))
	do
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


# из файла ./block_ip вычисляем, выбираем нужные параметры, сортируем и записываем в ./sorted_block_ip
# height new block 
height=$(echo "$(curl -Ls "https://chainz.cryptoid.info/dash/api.dws?q=getblockcount")")
# считываем  файл ./block_ip
block_ip=$(cat ./block_ip)
# всего блоков в очереди - количество  строк
no_mn=$(echo "$block_ip" | wc -l)
# последний в очереди  на выплату
end_last_paid_height=$(echo "$(sort -k1 ./block_ip)" | (awk 'NR == 1{print $1}'))
# первый в списке  на выплату
first_last_paid_height=$(echo "$(sort -k1 ./block_ip)"  | sed '$!d' | awk '{ print $1 }')
no_blocks_in_queue=$(( $echo $first_last_paid_height - $end_last_paid_height ))
echo "$(sort -k1 ./block_ip)" | awk '{ print $_ " " ( '$end_last_paid_height' + '$no_blocks_in_queue' + 'i++') }' > ./sorted_block_ip
##########

# This variable gets updated after an incident occurs.
# LAST_SENT_TIME=1619958605
MN_FILTERED=($(dash-cli protx list|jq -r '.[]'|grep $(sed 's/ /\\|/g'<<<"${MY_MASTERNODES[@]}")))
[[ -x `which dash-cli` ]] || BODY="dash-cli failed to execute...\n"

> ./mn_payoutAddress
sorted_block_ip=$(cat ./sorted_block_ip)

# выводим все mn_payoutAddress мастернод в массив array_payoutAddress

for (( n=0; n < ${#MY_MASTERNODES[*]}; n++ ))
do
if echo "${MN_FILTERED[@]}"|grep -q "${MY_MASTERNODES[$n]}";then
	
	echo "$sorted_block_ip" | grep ${MY_MASTERNODES[$n]} | awk '{ print $3 }' | sort -u >> ./mn_payoutAddress
else
	BODY+="Missing MN ${MY_MASTERNODES[$n]}. Check protx hash is correct."
fi
done

echo $BODY	
cat ./mn_payoutAddress | sort -u > ./sort_mn_payoutAddress
array_payoutAddress=()

while IFS= read -r line; do
	array_payoutAddress+=( "$line" )
done <  ./sort_mn_payoutAddress
	
	
# вычисляем суммарный  баланс мастернод
# mn_payoutAddress=('cat "./mn_payoutAddress"')
MN_BALANCE=0
for i in ${!array_payoutAddress[@]}; 
do
	MN_BALANCE=$(bc<<<"scale=1;$MN_BALANCE+$(echo "$(curl -Ls "https://chainz.cryptoid.info/dash/api.dws?q=getbalance&a=${array_payoutAddress[$i]}")/1" )")
done


# основной цикл для отправки сообщений
sorted_block_ip=$(cat ./sorted_block_ip)
for (( n=0; n < ${#MN_FILTERED[*]}; n++ ))
do	
# 	if echo "$MN_FILTERED"|grep -q "${MY_MASTERNODES[$n]}";then
		info_myMN_QUEUE_POSITION_to_pay=$(echo "$sorted_block_ip" | grep ${MN_FILTERED[$n]}  | awk '{ print $_ " " ( $6 - '$height' ) }')
		No_myMN_QUEUE_POSITION_to_pay=$(echo $info_myMN_QUEUE_POSITION_to_pay | awk '{ print $7 }')
		percent=$(echo "scale=1;100*( $no_mn - $No_myMN_QUEUE_POSITION_to_pay )/$no_mn" | bc -l )
		percent_int=$(echo "$percent" | awk '{print int($1+0.5)}')
		ip=$(echo $info_myMN_QUEUE_POSITION_to_pay | awk '{ print $4 }')
		mn_last_paid_heigh=$(echo $info_myMN_QUEUE_POSITION_to_pay | awk '{ print $1 }')
		mn_last_paid_time=$(echo "$(curl -Ls "https://chainz.cryptoid.info/dash/api.dws?q=getblocktime&height=$mn_last_paid_heigh")")
		mn_new_paid_heigh=$(echo $info_myMN_QUEUE_POSITION_to_pay | awk '{ print $6 }')
		mn_new_paid_time=$(echo "$(curl -Ls "https://chainz.cryptoid.info/dash/api.dws?q=getblocktime&height=$mn_new_paid_heigh")")
		mn_payoutAddress=$(echo $info_myMN_QUEUE_POSITION_to_pay | awk '{ print $3 }')
	#Create ProgressBar	
		NOW_EPOCH=`date +%s`
		Dash_USD=$(echo "scale=1;$(curl -Ls "https://chainz.cryptoid.info/dash/api.dws?q=ticker.usd")/1" | bc -l  )
		myMN_BALANCE=$(echo "scale=1;$(curl -Ls "https://chainz.cryptoid.info/dash/api.dws?q=getbalance&a=$mn_payoutAddress")/1" | bc -l  )
		height=$(echo "$(curl -Ls "https://chainz.cryptoid.info/dash/api.dws?q=getblockcount")")
	# вычисляем среднее время  блока (average_block_time)
		time1=$(echo "$(curl -Ls "https://chainz.cryptoid.info/dash/api.dws?q=getblocktime&height=$height")")
		time2=$(echo "$(curl -Ls "https://chainz.cryptoid.info/dash/api.dws?q=getblocktime&height=$(( $height - 10000))")")
		average_block_time=$( echo "($time1 - $time2)/10000" | bc ) # среднее время  блока
	# сколько прошло времени после последней выплаты
		l=$(( $NOW_EPOCH - $mn_last_paid_time ))
			((sec=l%60, l/=60, min=l%60, l/=60, hrs=l%24, l/=24, day=l%24))
			if [ $day -eq 0 ]; then 
				mn_last_paid_tstamp=$(printf "%dh%02dm" $hrs $min)	# если дней =0 то выводим часы и минуты
			else
				mn_last_paid_tstamp=$(printf "%dd%02dh" $day $hrs)	# если дней >0 то выводим дни и часы
			fi
			mn_blocks_till_pyment=$(( $mn_new_paid_heigh - $height ))
	# вычисляем сколько времени до выплаты в секундах (f=)	
			f=$(echo "scale=0;$mn_blocks_till_pyment*$average_block_time/1"  | bc)
	# вычисляем  EPOCH время выплаты в секундах (mn_new_paid_time =)	
			mn_new_paid_time=$(( $NOW_EPOCH + $f ))
	# время в сек до полуночи
			until_midnight=$(($(date -d 'tomorrow 00:00:00' +%s) - $(date +%s)))
	# выводим время в форматах (Wed Jun 23 21:26:33 2021)  будующей выплаты и время cравниваем , сравниваем даты 	
			dif_days=$(( $f - $until_midnight )) # $i -left till paymen / секунд до оплаты
				if [ "$dif_days" -lt 0 ]; then
					d="New payment today at"
					mn_left_till_payment_tstamp=$(perl -le 'print scalar localtime $ARGV[0]' $mn_new_paid_time | awk '{ print $4 }' | sed -e "s/.\{,3\}$//")
					line_one="block"
				else 
					if [ "$dif_days" -gt 86400 ]; then
						unset d 
						line_one="left till payment in block"
						((sec=f%60, f/=60, min=f%60, f/=60, hrs=f%24, f/=24, day=f%24))
						if [ "$hrs" -eq 1 ]; then
								line_hrs="%02d hour"
						else 
								line_hrs="%02d hours"
						fi
						if [ "$day" -eq 1 ]; then
							mn_left_till_payment_tstamp=$(printf "%d day $line_hrs" $day $hrs)
						else
							mn_left_till_payment_tstamp=$(printf "%d days" $day)
						fi
					else
						d="New payment tomorrow at"
						mn_left_till_payment_tstamp=$(perl -le 'print scalar localtime $ARGV[0]' $mn_new_paid_time | awk '{ print $4 }' | sed -e "s/.\{,3\}$//")
						line_one="block"
					fi
				fi
			echo $d	
				let _done=($percent_int*5)/10 
				let _left=50-$_done 
				_done=$(printf "%${_done}s")
				_left=$(printf "%${_left}s")
		printf "$d $mn_left_till_payment_tstamp $line_one $mn_new_paid_heigh\n[${_done// /|}${_left// /:}] $percent%%\nLast payment was $mn_last_paid_tstamp ago in $mn_last_paid_heigh \nBALANCE=$myMN_BALANCE/$MN_BALANCE Dash  1Dash=$Dash_USD$" > ./nvar		
				nvar=$(echo "$(cat ./nvar)")
				myvar=$(echo -e "Masternode $ip  position $No_myMN_QUEUE_POSITION_to_pay/$no_mn")
				

		curl -s \
		  --form-string "token=af3ktr7qch93wws14b6pxy6tyvfvfh" \
		  --form-string "user=u69uin39geyd7w4244sfbws6abd1wn" \
		  --form-string "sound=bike" \
		  --form-string "title=$myvar" \
		  --form-string "message=$nvar" \
		https://api.pushover.net/1/messages.json &> /dev/null 
# 	else
# 		BODY+="Missing MN ${MASTERNODES[$i]}. Check protx hash is correct.\n"
# 	fi  
done

curl -s \
  --form-string "token=af3ktr7qch93wws14b6pxy6tyvfvfh" \
  --form-string "user=u69uin39geyd7w4244sfbws6abd1wn" \
  --form-string "sound=bike" \
  --form-string "title=123" \
  --form-string "message=$BODY" \
https://api.pushover.net/1/messages.json &> /dev/null 

exit



MY_MASTERNODES=(\
25e195c12334573e6f19505155efd12f4c22535a504f78ab40770de99fc10126 \
75d3bf6b4d6a5844bef4fd7dc21953ebaeddfac50a8c8d25ec8bb7aef4f0b72f \
1779a6d273177531dd7fbb397b609ccffdbe391adae8f1bdcc4c7b002c29658a \
d38fb2f9303b578b1d47d726581c83291c661bef7291eeb017f32390d160b640 \
a3cf9812bf59e07befe144e46dca847a2ca12e23360c8a8a4004323820003e9e \
4797d47cfffae5f0b200f4964f76d824f16fc8ff0569f248049e47ac67469ea7 \
4a450b8c0a2c4615cc9f6bf35689f534e4cc75335a443f85b5deb977af78919d \
e5deb272685095cb4ce916337a86f4cf41ac3e747a1cf6294906a0821aaab5a3 \
)
# 
> ./mn_payoutAddress
sorted_block_ip=$(cat ./sorted_block_ip)
# выводим все mn_payoutAddress мастернод в массив array_payoutAddress
for (( n=0; n < ${#MY_MASTERNODES[*]}; n++ ))
do
	echo "$sorted_block_ip" | grep ${MY_MASTERNODES[$n]} | awk '{ print $3 }' | sort -u >> ./mn_payoutAddress
	done
	cat ./mn_payoutAddress
	cat ./mn_payoutAddress | sort -u > ./sort_mn_payoutAddress
	cat ./sort_mn_payoutAddress
	array_payoutAddress=()
	while IFS= read -r line; do
		array_payoutAddress+=( "$line" )
done <  ./sort_mn_payoutAddress
# вычисляем суммарный  баланс мастернод
# mn_payoutAddress=('cat "./mn_payoutAddress"')
MN_BALANCE=0
for i in ${!array_payoutAddress[@]}; 
do
	MN_BALANCE=$(bc<<<"scale=1;$MN_BALANCE+$(echo "$(curl -Ls "https://chainz.cryptoid.info/dash/api.dws?q=getbalance&a=${array_payoutAddress[$i]}")/1" )")
done
# height new block 
height=$(echo "$(curl -Ls "https://chainz.cryptoid.info/dash/api.dws?q=getblockcount")")
# считываем  файл ./block_ip
block_ip=$(cat ./block_ip)
# всего блоков в очереди - количество  строк
no_mn=$(echo "$block_ip" | wc -l)
# последний в очереди  на выплату
end_last_paid_height=$(echo "$(sort -k1 ./block_ip)" | (awk 'NR == 1{print $1}'))
# первый в списке  на выплату
first_last_paid_height=$(echo "$(sort -k1 ./block_ip)"  | sed '$!d' | awk '{ print $1 }')
no_blocks_in_queue=$(( $echo $first_last_paid_height - $end_last_paid_height ))
echo "$(sort -k1 ./block_ip)" | awk '{ print $_ " " ( '$end_last_paid_height' + '$no_blocks_in_queue' + 'i++') }' > ./sorted_block_ip
sorted_block_ip=$(cat ./sorted_block_ip)
for (( n=0; n < ${#MY_MASTERNODES[*]}; n++ ))
do	
	info_myMN_QUEUE_POSITION_to_pay=$(echo "$sorted_block_ip" | grep ${MY_MASTERNODES[$n]}  | awk '{ print $_ " " ( $6 - '$height' ) }')
	No_myMN_QUEUE_POSITION_to_pay=$(echo $info_myMN_QUEUE_POSITION_to_pay | awk '{ print $7 }')
	percent=$(echo "scale=1;100*( $no_mn - $No_myMN_QUEUE_POSITION_to_pay )/$no_mn" | bc -l )
 	percent_int=$(echo "$percent" | awk '{print int($1+0.5)}')
	ip=$(echo $info_myMN_QUEUE_POSITION_to_pay | awk '{ print $4 }')
	mn_last_paid_heigh=$(echo $info_myMN_QUEUE_POSITION_to_pay | awk '{ print $1 }')
	mn_last_paid_time=$(echo "$(curl -Ls "https://chainz.cryptoid.info/dash/api.dws?q=getblocktime&height=$mn_last_paid_heigh")")
	mn_new_paid_heigh=$(echo $info_myMN_QUEUE_POSITION_to_pay | awk '{ print $6 }')
	mn_new_paid_time=$(echo "$(curl -Ls "https://chainz.cryptoid.info/dash/api.dws?q=getblocktime&height=$mn_new_paid_heigh")")
	mn_payoutAddress=$(echo $info_myMN_QUEUE_POSITION_to_pay | awk '{ print $3 }')
#Create ProgressBar	
	NOW_EPOCH=`date +%s`
	Dash_USD=$(echo "scale=1;$(curl -Ls "https://chainz.cryptoid.info/dash/api.dws?q=ticker.usd")/1" | bc -l  )
	myMN_BALANCE=$(echo "scale=1;$(curl -Ls "https://chainz.cryptoid.info/dash/api.dws?q=getbalance&a=$mn_payoutAddress")/1" | bc -l  )
	height=$(echo "$(curl -Ls "https://chainz.cryptoid.info/dash/api.dws?q=getblockcount")")
# вычисляем среднее время  блока (average_block_time)
	time1=$(echo "$(curl -Ls "https://chainz.cryptoid.info/dash/api.dws?q=getblocktime&height=$height")")
	time2=$(echo "$(curl -Ls "https://chainz.cryptoid.info/dash/api.dws?q=getblocktime&height=$(( $height - 10000))")")
	average_block_time=$( echo "($time1 - $time2)/10000" | bc ) # среднее время  блока
# сколько прошло времени после последней выплаты
	l=$(( $NOW_EPOCH - $mn_last_paid_time ))
		((sec=l%60, l/=60, min=l%60, l/=60, hrs=l%24, l/=24, day=l%24))
		if [ $day -eq 0 ]; then 
			mn_last_paid_tstamp=$(printf "%dh%02dm" $hrs $min)	# если дней =0 то выводим часы и минуты
		else
			mn_last_paid_tstamp=$(printf "%dd%02dh" $day $hrs)	# если дней >0 то выводим дни и часы
		fi
		mn_blocks_till_pyment=$(( $mn_new_paid_heigh - $height ))
# вычисляем сколько времени до выплаты в секундах (f=)	
		f=$(echo "scale=0;$mn_blocks_till_pyment*$average_block_time/1"  | bc)
# вычисляем  EPOCH время выплаты в секундах (mn_new_paid_time =)	
		mn_new_paid_time=$(( $NOW_EPOCH + $f ))
# время в сек до полуночи
		until_midnight=$(($(date -d 'tomorrow 00:00:00' +%s) - $(date +%s)))
# выводим время в форматах (Wed Jun 23 21:26:33 2021)  будующей выплаты и время cравниваем , сравниваем даты 	
		dif_days=$(( $f - $until_midnight )) # $i -left till paymen / секунд до оплаты
			if [ "$dif_days" -lt 0 ]; then
				d="New payment today at"
				mn_left_till_payment_tstamp=$(perl -le 'print scalar localtime $ARGV[0]' $mn_new_paid_time | awk '{ print $4 }' | sed -e "s/.\{,3\}$//")
				line_one="block"
			else 
				if [ "$dif_days" -gt 86400 ]; then
					unset d 
					line_one="left till payment in block"
					((sec=f%60, f/=60, min=f%60, f/=60, hrs=f%24, f/=24, day=f%24))
					mn_left_till_payment_tstamp=$(printf "%dd%02dh" $day $hrs)
				else
					d="New payment tomorrow at"
					mn_left_till_payment_tstamp=$(perl -le 'print scalar localtime $ARGV[0]' $mn_new_paid_time | awk '{ print $4 }' | sed -e "s/.\{,3\}$//")
					line_one="block"
				fi
			fi
		echo $d	
			let _done=($percent_int*6)/10 
			let _left=60-$_done 
			_done=$(printf "%${_done}s")
			_left=$(printf "%${_left}s")
	printf "$d $mn_left_till_payment_tstamp $line_one $mn_new_paid_heigh\n[${_done// /|}${_left// /:}] $percent%%\nLast payment was $mn_last_paid_tstamp ago in $mn_last_paid_heigh \nBALANCE=$myMN_BALANCE/$MN_BALANCE"Dash" 1Dash=$Dash_USD$" > ./nvar		
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
  
# ./test.sh


exit

#   ./my_masternodes_next_pay.sh


 # crontab -e
# 
#                        
# SHELL=/bin/bash
# PATH=/usr/sbin:/usr/bin:/sbin:/bin:/opt/dash/bin:
# 
# 0 */4 * * * /home/dash03/my_masternodes_next_pay.sh
# 
# 
# 
  
./my_masternodes_next_pay.sh

https://stackoverflow.com/questions/2961635/using-awk-to-print-al l-columns-from-the-nth-to-the-last

Print all columns:

awk '{print $0}' somefile
Print all but the first column:

awk '{$1=""; print $0}' somefile
Print all but the first two columns:

awk '{$1=$2=""; print $0}' somefile

# вывести первую и последнюю строки файла и только первый столбец
echo "$sorted_block_ip" | sed '1!{$!d}' | awk '{ print $1 }'
# только первую 
echo "$sorted_block_ip" | sed q | awk '{ print $1 }' 
# только последнюю
echo "$sorted_block_ip" | sed '$!d' | awk '{ print $1 }'
###
# Вывести n строку n столбца

awk 'NR == 2{print$3}'

sorted_block_ip=$(cat ./sorted_block_ip)
next_block=$(( echo "$sorted_block_ip" | (awk 'NR == 1{print$1}') ))
###
sorted_block_ip=$(cat ./sorted_block_ip)
echo "$sorted_block_ip" | sed '$!d' | awk '{ print $1 }' 

			mn_left_till_payment_tstamp=$(perl -le 'print scalar localtime $ARGV[0]' $mn_new_paid_time | awk '{ print $4 }' | sed -e "s/.\{,3\}$//")
			https://askdev.ru/q/kak-udalit-posledniy-simvol-iz-vyvoda-bash-grep-72931/

crontab -e
SHELL=/bin/bash
PATH=/usr/sbin:/usr/bin:/sbin:/bin:/opt/dash/bin:
0 */4 * * * /home/dash03/my_masternodes_next_pay.sh

сравнить два текста

grep -v a.txt b.txt > c.txt
####или ?
while read -r line; do

     todel=$(grep -n "$line" file2 | awk '{print $1}')
     
     for f in $todel; do
        sed -i "${f}d" file2
     done

done < file1

