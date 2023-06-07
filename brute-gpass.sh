#!/bin/bash

# Define color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Function to generate permutations based on configuration rules
generate_permutations() {
    local word=$1
    local lowercase=$2
    local uppercase=$3
    local digits=$4
    local symbols=$5

    if [[ -z $word ]]; then
        echo "$word"
        return
    fi

    local char="${word:0:1}"
    local remaining="${word:1}"

    if [[ -n $remaining ]]; then
        generate_permutations "$remaining" "$lowercase" "$uppercase" "$digits" "$symbols"
    fi

    case $char in
        [a-z])
            if [[ $lowercase == "true" ]]; then
                generate_permutations "$remaining" "$lowercase" "$uppercase" "$digits" "$symbols"
            fi
            if [[ $uppercase == "true" ]]; then
                generate_permutations "$(echo "$remaining" | tr '[:lower:]' '[:upper:]')" "$lowercase" "$uppercase" "$digits" "$symbols"
            fi
            ;;
        [A-Z])
            if [[ $uppercase == "true" ]]; then
                generate_permutations "$remaining" "$lowercase" "$uppercase" "$digits" "$symbols"
            fi
            if [[ $lowercase == "true" ]]; then
                generate_permutations "$(echo "$remaining" | tr '[:upper:]' '[:lower:]')" "$lowercase" "$uppercase" "$digits" "$symbols"
            fi
            ;;
        [0-9])
            if [[ $digits == "true" ]]; then
                generate_permutations "$remaining" "$lowercase" "$uppercase" "$digits" "$symbols"
            fi
            ;;
        [\!\@\#\$\%\*])
            if [[ $symbols == "true" ]]; then
                generate_permutations "$remaining" "$lowercase" "$uppercase" "$digits" "$symbols"
            fi
            ;;
    esac
}

# Read the available secret keys
keys=()
while read -r line; do
    if [[ $line =~ ^sec ]]; then
        key_id=$(echo "$line" | awk '{print $2}' | awk -F'/' '{print $NF}')
        keys+=("$key_id")
    fi
done < <(gpg --list-secret-keys --keyid-format LONG)

# Prompt the user to select a key to test
echo -e "${YELLOW}Available secret keys:${NC}"
for ((i=0; i<${#keys[@]}; i++)); do
    echo "[$i] ${keys[$i]}"
done

read -p "Select a key to test (0-${#keys[@] - 1}): " key_index

# Check if the key index is valid
if ! [[ $key_index =~ ^[0-9]+$ ]] || ((key_index < 0)) || ((key_index >= ${#keys[@]})); then
    echo -e "${RED}Invalid key index.${NC}"
    exit 1
fi

selected_key=${keys[$key_index]}

# Extract the key ID from the selected key
key_id=$(echo "$selected_key" | awk -F'/' '{print $NF}')

# Read the passphrase seed values
seed_values=()
while true; do
    read -p "Enter a passphrase seed value (leave empty to finish): " seed_value
    if [[ -z $seed_value ]]; then
        break
    fi
    seed_values+=("$seed_value")
done

# Prompt for permutation options
echo -e "\n${YELLOW}Permutation Options:${NC}"
echo -e "Enter the letters corresponding to the options you want to include:"
echo -e "    ${GREEN}a${NC}: Include lowercase letters"
echo -e "    ${GREEN}A${NC}: Include uppercase letters"
echo -e "    ${GREEN}0${NC}: Include digits (0-9)"
echo -e "    ${GREEN}!${NC}: Include symbols (!, @, $, #, %, *)"
read -p "Permutation options (default: aA0!): " -r permutation_options

# Set default values for permutation options
lowercase=true
uppercase=true
digits=true
symbols=true

# Process the provided permutation options or use the defaults
if [[ -n $permutation_options ]]; then
    lowercase=false
    uppercase=false
    digits=false
    symbols=false

    for option in $(echo "$permutation_options" | fold -w1); do
        case $option in
            a)
                lowercase=true
                ;;
            A)
                uppercase=true
                ;;
            0)
                digits=true
                ;;
            \!)
                symbols=true
                ;;
        esac
    done
fi

# Generate and test the passphrase permutations
for seed_value in "${seed_values[@]}"; do
	while IFS= read -r permutation; do
    		echo -e "${YELLOW}Testing passphrase:${NC} $permutation"
    		# Attempt to decrypt the dummy file using the permutation
    			if gpg --batch --yes --passphrase "$permutation" --decrypt --default-key "$key_id" dummy_file.gpg > /dev/null 2>&1; then
        		# Passphrase found
        		echo -e "${GREEN}Passphrase found:${NC} $permutation"
        		exit 0
    		fi
	done < <(generate_permutations "$seed_value" "$lowercase" "$uppercase" "$digits" "$symbols")
done

# No valid passphrase found
echo -e "${RED}No valid passphrase found.${NC}"
exit 1

