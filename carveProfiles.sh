#!/bin/bash

#bash carveProfiles.sh

saveData=FitPlus0.dat
csvFile="output.csv"
profileLength=37504
offsetStart=8
offsetEnd=$(( $offsetStart + $profileLength ))
saveSize=`du -b $saveData | cut -f1`
offsetEOF=$(( $saveSize - 16 ))
statName=("Name" "Height" "DoB") # "DatesWD" "Date" "Weight" "BMI" "BalanceP")
statPos=("0" "46" "48") # "192" "28978" "28986" "28990" "28994")
statLen=("40" "2" "8") # "20" "8" "4" "4" "4")
dataPos="28978"
dataLen="42"


# Extract profiles
i=0
while (( $offsetEnd < $offsetEOF ))
do
    # xxd -a -s +$offsetStart -l $profileLength $saveData > "export$i.txt" 
    # xxd -p -a -s +$offsetStart -l $profileLength $saveData | tr -d '\n' > "export$i.txt"
    profiles[$i]=$(xxd -p -a -s +$offsetStart -l $profileLength $saveData | tr -d '\n')
    
    offsetStart=$(( offsetEnd + 1 ))
    offsetEnd=$(( offsetEnd + profileLength + 1 ))
    i=$((++i))
done

# Reset csv
echo "Name,Height,DoB,Date,Weight,BMI,Balance" > "$csvFile"

# Process profiles
i=0
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
                    echo -e  "${statName[j]}\t\t$tempDec"
                    csv="$tempDec,"
                    ;;
                "Height")
                    if (( $((16#$tempHex)) != "00" ))
                    then
                        tempDec="$((16#$tempHex))"
                        echo -e  "${statName[j]}\t\t$tempDec cm"
                        csv="$csv$tempDec,"
                    else                        
                        csv="$csv""0,"
                    fi
                    ;;
                "DoB")
                    tempDec="${tempHex:6:2}-${tempHex:4:2}-${tempHex:0:4}"
                    echo -e  "${statName[j]}\t\t$tempDec"
                    csv="$csv$tempDec,"
                    ;;
                *)
                    echo "${statName[j]} Error. Exiting"
                    exit
                ;;
            esac
            j=$((++j))
        done
        
        # Process fitness data
        chunkEmpty=false
        k=0
        while (( $k > -1 ))
        do 
            # echo $((dataPos+(dataLen*k)))
            tempHex="${profile:$((dataPos+(dataLen*k))):${dataLen}}"
            if [ ${tempHex:0:4} != "0000" ]
            then                
                # Convert date and time
                zero="00"
                formattedHex=$(echo "${tempHex:0:8}" | tr -cd '[:alnum:]' | tr '[:lower:]' '[:upper:]')
                tempBin=$(echo "ibase=16; obase=2; $formattedHex" | bc)
                tempDay=$((2#${tempBin:15:5}))
                tempMonth=$(((2#${tempBin:11:4})+1))
                tempYear=$((2#${tempBin:0:11}))
                tempHour=$((2#${tempBin:20:5}))
                tempMin=$((2#${tempBin:25:6}))
                strBuilder="${zero:${#tempDay}:${#zero}}$tempDay-${zero:${#tempMonth}:${#zero}}$tempMonth-$tempYear ${zero:${#tempHour}:${#zero}}$tempHour:${zero:${#tempMin}:${#zero}}$tempMin"
                csvBuilder="$csv$tempYear-${zero:${#tempMonth}:${#zero}}$tempMonth-${zero:${#tempDay}:${#zero}}$tempDay ${zero:${#tempHour}:${#zero}}$tempHour:${zero:${#tempMin}:${#zero}}$tempMin,"

                # Convert weight
                strBuilder="$strBuilder - $(((16#${tempHex:8:4})/10)).$(((16#${tempHex:8:4})%10))kg"
                csvBuilder="$csvBuilder$(((16#${tempHex:8:4})/10)).$(((16#${tempHex:8:4})%10)),"
                
                # Convert BMI
                if (( $((16#${tempHex:12:4})) != "00" ))
                then
                    strBuilder="$strBuilder - $(((16#${tempHex:12:4})/100)).$(((16#${tempHex:12:4})%100)) BMI"
                    csvBuilder="$csvBuilder$(((16#${tempHex:12:4})/100)).$(((16#${tempHex:12:4})%100)),"
                else
                    csvBuilder="$csvBuilder""0,"
                fi
                
                # Convert balance percentage (to the right)
                if (( $((16#${tempHex:16:4})) != "00" ))
                then
                    strBuilder="$strBuilder - $(((16#${tempHex:16:4})/10)).$(((16#${tempHex:16:4})%10))%"
                    csvBuilder="$csvBuilder$(((16#${tempHex:16:4})/10)).$(((16#${tempHex:16:4})%10))"
                else
                    csvBuilder="$csvBuilder""0"
                fi

                echo "$strBuilder"                
                echo "$csvBuilder" >> "$csvFile"
                k=$((++k))
            else
                k=-1
            fi
        done
        echo "============================================="
    fi
done