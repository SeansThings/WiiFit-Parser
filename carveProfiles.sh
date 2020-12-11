#!/bin/bash

#bash carveProfiles.sh

saveData=FitPlus0.dat
profileLength=37504
offsetStart=8
offsetEnd=$(( $offsetStart + $profileLength ))
saveSize=`du -b $saveData | cut -f1`
offsetEOF=$(( $saveSize - 16 ))
statName=("Name" "Height" "DoB" "DatesWD" "Date" "Weight" "BMI" "BalanceP")
statPos=("0" "46" "48" "192" "28978" "28986" "28990" "28994")
statLen=("40" "2" "8" "20" "8" "4" "4" "4")
i=0

# Extract profiles
while (( $offsetEnd < $offsetEOF ))
do
    # xxd -a -s +$offsetStart -l $profileLength $saveData > "export$i.txt" 
    # xxd -p -a -s +$offsetStart -l $profileLength $saveData | tr -d '\n' > "export$i.txt"
    profiles[$i]=$(xxd -p -a -s +$offsetStart -l $profileLength $saveData | tr -d '\n')
    
    offsetStart=$(( offsetEnd + 1 ))
    offsetEnd=$(( offsetEnd + profileLength + 1 ))
    i=$((++i))
done

# Process profiles
for profile in "${profiles[@]}"
do
    # Ignore blank profiles
    if [ ${profile:0:8} != "00000000" ]
    then
        j=0
        for name in "${statName[@]}"
        do
            # Extract relevant hex and process
            tempHex="${profile:${statPos[j]}:${statLen[j]}}"
            case ${statName[j]} in
                "Name")
                    tempDec=$( echo -ne $tempHex | xxd -p -r | tr -d '\0')
                    echo -e  "${statName[j]}\t\tDec:$tempDec\t\tHex:$tempHex"
                    ;;
                "Height")
                    if (( $((16#$tempHex)) != "00" ))
                    then
                        tempDec="$((16#$tempHex))"
                        echo -e  "${statName[j]}\t\tDec:$tempDec cm\t\tHex:$tempHex"
                    fi
                    ;;
                "DoB")
                    tempDec="${tempHex:6:2}-${tempHex:4:2}-${tempHex:0:4}"
                    echo -e  "${statName[j]}\t\tDec:$tempDec\t\tHex:$tempHex"
                    ;;
                "DatesWD")
                    tempDec="FIX ME"            
                    echo -e  "${statName[j]}\t\tDec:$tempDec\t\tHex:$tempHex"
                    ;;
                "Date")
                    zero="00"
                        # tempHexNext="${profile:$((${statPos[j]}+42)):$((${statLen[j]}))}" Need to loop this so each row has Date, Weight, BMI, BalanceP
                        tempHex=$(echo "$tempHex" | tr -cd '[:alnum:]' | tr '[:lower:]' '[:upper:]')
                        tempBin=$(echo "obase=2; ibase=16; $tempHex" | bc)
                        tempDay=$((2#${tempBin:15:5}))
                        tempMonth=$((2#${tempBin:11:4}))
                        tempYear=$((2#${tempBin:0:11}))
                        tempHour=$((2#${tempBin:20:5}))
                        tempMin=$((2#${tempBin:25:6}))
                        tempDec="${zero:${#tempDay}:${#zero}}$tempDay-$tempMonth-$tempYear $tempHour:${zero:${#tempMin}:${#zero}}$tempMin"
                        echo -e  "${statName[j]}\t\tDec:$tempDec\tHex:$tempHex"
                    ;;
                "Weight")
                    tempDec="$(((16#$tempHex)/10)).$(((16#$tempHex)%10))kg"
                    echo -e  "${statName[j]}\t\tDec:$tempDec\t\tHex:$tempHex"
                    ;;
                "BMI")
                    if (( $((16#$tempHex)) != "00" ))
                    then
                        tempDec="$(((16#$tempHex)/100)).$(((16#$tempHex)%100))"
                        echo -e "${statName[j]}\t\tDec:$tempDec BMI\t\tHex:$tempHex"
                    fi
                    ;;
                "BalanceP")
                    if (( $((16#$tempHex)) != "00" ))
                    then
                        tempDec="$(((16#$tempHex)/10)).$(((16#$tempHex)%10))"
                        echo -e  "${statName[j]}\tDec:$tempDec %\t\tHex:$tempHex"
                    fi
                    ;;
                *)
                    echo "${statName[j]} Error. Exiting"
                    exit
                ;;
            esac
            j=$((++j))
        done
        echo "===================================================================================="
    fi
done