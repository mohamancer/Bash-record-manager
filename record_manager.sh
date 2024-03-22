#!/bin/bash


#display the found records
found_records_menu(){
	while true; do
        	echo "Multiple records found. Please choose one to update:"
                grep "$record_name" "$record_file" | cat -n
                read -p "Enter the number of the record to update, or press enter for your initial prompt: " choice
		if [ -z "$choice" ] && ! [[ $mode == "insert" ]]; then
			echo "default can only be used on insert"
		elif [ -z "$choice" ]; then
			echo "$record_name,$amount" >> "$record_file"
			return 0
		elif [[ "$choice" =~ ^[1-9]+$ ]] && [[ $choice -le $(echo "$options" | wc -l) ]]; then
                	selected_record=$(echo "$options" | sed -n "${choice}p" | cut -d, -f1)
			selected_amount=$(echo "$options" | sed -n "${choice}p" | cut -d, -f2)
			if [[ $mode == "insert" ]]; then
				update_record "$selected_record" "$(( selected_amount + amount ))"
				return 0
			elif [[ $mode == "delete" ]]; then
				if [[ $selected_amount -lt $amount ]]; then
					echo "Number of records to delete more than that in stock"
				elif [[ $selected_amount -eq $amount ]]; then
					sed -i "/^$selected_record,/d" $record_file
					return 0
				else
					update_record "$selected_record" "$(( selected_amount - amount ))"
					return 0
				fi
			elif [[ $mode == "name" ]]; then #update name
				local old_name="$1"
				local new_name="$2"
				sed -i "s/${selected_record},.*/${new_name},${selected_amount}/" "$record_file"
				return 0
			else
				update_record "$selected_record" "$amount"
				return 0
			fi				
		else
			echo "Invalid choice. Please choose a number from the list or press enter"
		fi
	done

}

# validates both arguments
valid_arguments(){	
        validate_record_name "$record_name" || return 1
        validate_amount "$amount" || return 1
}

# Function to validate record name
validate_record_name() {
    local name=$1

    if [[ ! $name =~ ^[a-zA-Z0-9[:space:]]+$ ]]; then
        echo "Error: Invalid record name. Record name must contain only characters, digits, and spaces."
        return 1
    fi
}

# Function to validate amount
validate_amount() {
    local amount=$1

    if [[ ! $amount =~ ^[0-9]+$ ]]; then
        echo "Error: Invalid amount. Amount must be a number."
        return 1
    fi
}

#handles the insertion and deletion
handle() {
	if ! valid_arguments; then
        	return 1
        fi
	
	mode=$1
        if search; then
                options=$(grep "$record_name" "$record_file")
                found_records_menu "$record_name" "$amount"
        else
		if [[ $mode == "insert" ]]; then
                	echo "$record_name,$amount" >> "$record_file"
			return 0
		else
			echo "Record not found"
			return 1
		fi
        fi

}
# Extract arguments
extract(){
	record_name=$(echo "$@" | sed 's/ [^ ]*$//')
        amount=$(echo "$@" | sed 's/.* //')
}
# Function to insert a record
insert_record() {
	extract $@
	if handle "insert"; then
		echo "Successfully inserted records"
	        log_event "Insert Success"
	else
		echo "Failure in inserting records"
		log_event "Insert Failure"
	fi

}

# Function to delete a record
delete_record() {
	extract $@
	if handle "delete"; then
                echo "Successfully deleted records"
                log_event "Delete Success"
        else
                echo "Failure in deleting records"
                log_event "Delete Failure"
        fi

}

# Function to show the searched records
search_record() {
	record_name=$1
	validate_record_name $record_name || return 1
	if search; then
		grep "$record_name" "$record_file" | sort
		log_event "Search Success"
	else
		echo "Search failed, no records found"
		log_event "Search Failure"
	fi
}
# Function to search for a record
search() {
    local search_term="$record_name"
    
    grep -q "$search_term" "$record_file" || return 1

}

# Function to update record name
update_record_name() {
    local old_name=$1
    local new_name=$2
    record_name=$old_name
    validate_record_name "$old_name" || return 1
    validate_record_name "$new_name" || return 1
    mode="name"
    if search; then
	options=$(grep "$old_name" "$record_file")
        found_records_menu "$old_name" "$new_name"
	log_event "UpdateName Success"
    else
        echo "Error: Record not found"
        log_event "UpdateName Failure"
    fi
}
# Update Record function

update_record_amount() {
	
	extract $@
	if handle "amount"; then
		echo "Successfully updated amount"
	        log_event "UpdateAmount Success $amount"
	else
		echo "Error: record not found"
		log_event "UpdateAmount Failure"
	fi
}
# Function to update record amount
update_record() {
    record_name=$1
    amount=$2 
    sed -i "s/${record_name},.*/${record_name},${amount}/" "$record_file"
   
}

# Function to print total amount of records
print_total_amount() {
    local total=$(awk -F ',' '{sum+=$2} END {print sum}' "$record_file")
    if (( total == 0 )); then
        echo "No records found."
        log_event "PrintAmount 0"
    else
        echo "Total number of records: $total"
        log_event "PrintAmount $total"
    fi
}

# Function to print all records sorted by name
print_sorted_records() {
    if [ ! -s "$record_file" ]; then
        echo "No records found."
        log_event "PrintAll"
    else
	sorted_records=$(sort -t ',' -k1 "$record_file")
        while IFS= read -r record; do
            echo "$record"
            log_event "PrintAll: $record"
        done <<< "$sorted_records"
    fi

}


# Function to log events
log_event() {
    local event="$1"
    echo "$(date +'%d/%m/%Y %H:%M:%S') $event" >> "$log_file"
}

# Main menu function
main_menu() {
    echo "Record Collection Management System"
    echo "1. Insert Record"
    echo "2. Delete Record"
    echo "3. Search Records"
    echo "4. Update Record Name"
    echo "5. Update Record Amount"
    echo "6. Print Total Amount of Records"
    echo "7. Print Sorted Records"
    echo "8. Exit"
    read -p "Enter your choice: " choice
    case $choice in
        1) read -p "Enter record name and amount separated by a space: " name amount
           insert_record "$name" "$amount";;
        2) read -p "Enter record name and amount separated by a space: " name amount
           delete_record "$name" "$amount";;
        3) read -p "Enter search term: " term
           search_record "$term";;
        4) read -p "Enter old record name: " old_name
	   read -p "Enter  new record name: "	new_name
           update_record_name "$old_name" "$new_name";;
        5) read -p "Enter record name and new Amount: " name new_amount
           update_record_amount "$name" "$new_amount";;
        6) print_total_amount;;
        7) print_sorted_records;;
        8) exit;;
        *) echo "Invalid choice";;
    esac
}

# Set record and log file names
record_file=$1
log_file="${record_file%.*}_log.txt"
# Main loop
while true; do
    main_menu
done
