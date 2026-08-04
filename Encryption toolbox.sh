#!/bin/bash

# ==========================================
# File Encryption/Decryption Tool
# Core Refactor: Disk streaming buffer engine, completely solves memory lag on large rounds
# ==========================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# --- Core Single-Round Algorithm Engine ---
encrypt_stream() {
    LC_ALL=C od -A n -t u1 -v | LC_ALL=C awk '
    BEGIN {
        split("0 1 2 3 4 5 6 7 8 9 a b c d e f", h)
        split("k m p q r s t u v w x y z a b c", c)
        for(i=1;i<=16;i++) h2c[h[i]]=c[i]
        count = 0
    }
    {
        for(i=1; i<=NF; i++) {
            cv = ($i * 3 + 17) % 256
            printf "%s%s", h2c[h[int(cv/16)+1]], h2c[h[cv%16+1]]
            count++
            if (count % 1024 == 0) printf "\n" 
        }
    }'
}

decrypt_stream() {
    LC_ALL=C awk '
    BEGIN {
        split("k m p q r s t u v w x y z a b c", c)
        for(i=1;i<=16;i++) c2h[c[i]] = i-1
    }
    {
        len = length($0)
        for(i=1; i<=len; i+=2) {
            c1 = substr($0, i, 1); c2 = substr($0, i+1, 1)
            if (c1 in c2h && c2 in c2h) {
                cv = c2h[c1] * 16 + c2h[c2]
                p = (((cv - 17) % 256 + 256) % 256 * 171) % 256
                printf "%c", p
            }
        }
    }'
}

# --- Multi-Round Streaming Engine (uses disk temp files to prevent memory overflow) ---
do_encrypt_stream_rounds() {
    local rounds="${1:-1}"
    local tmp1=".qah_enc1_$$"
    local tmp2=".qah_enc2_$$"
    
    encrypt_stream > "$tmp1"
    for ((i=2; i<=rounds; i++)); do
        cat "$tmp1" | encrypt_stream > "$tmp2"
        mv "$tmp2" "$tmp1"
    done
    cat "$tmp1"
    rm -f "$tmp1" "$tmp2"
}

do_decrypt_stream_rounds() {
    local rounds="${1:-1}"
    local tmp1=".qah_dec1_$$"
    local tmp2=".qah_dec2_$$"
    
    decrypt_stream > "$tmp1"
    for ((i=2; i<=rounds; i++)); do
        cat "$tmp1" | decrypt_stream > "$tmp2"
        mv "$tmp2" "$tmp1"
    done
    cat "$tmp1"
    rm -f "$tmp1" "$tmp2"
}

# --- Size Estimation Utility ---
calc_size_info() {
    local original_size=$1
    local rounds=$2
    echo "$original_size $rounds" | awk '{
        est = $1 * (2 ^ $2);
        mb = est / 1024 / 1024; kb = est / 1024;
        if (mb >= 1) printf "%.2f MB (%d Bytes)", mb, est;
        else if (kb >= 1) printf "%.2f KB (%d Bytes)", kb, est;
        else printf "%d Bytes", est;
    }'
}

# --- Interactive Menu ---
show_menu() {
    clear
    echo -e "${CYAN}=================================================${NC}"
    echo -e "${CYAN}    Letian Original Text/File Encryption Tool         ${NC}"
    echo -e "                   Author: Letian"
    echo -e "   Supports multi-round encryption & decryption"
    echo -e "          Anti-memory-lag streaming engine"
    echo -e "${CYAN}=================================================${NC}"
    echo -e "${YELLOW}1. Encrypt Text${NC}"
    echo -e "${YELLOW}2. Decrypt Text${NC}"
    echo -e "${YELLOW}3. Encrypt Text File${NC}"
    echo -e "${YELLOW}4. Decrypt Text File${NC}"
    echo -e "${YELLOW}5. Exit${NC}"
    echo -e "${CYAN}=================================================${NC}"
    read -p "Please select an option [1-5]: " choice

    case $choice in
        1)
            echo -e "\n${GREEN}Enter text to encrypt (type 'EOF' on a new line to finish):${NC}"
            text=""
            while IFS= read -r line; do
                [ "$line" = "EOF" ] && break
                [ -z "$text" ] && text="$line" || text="$text
$line"
            done
            read -p "Enter encryption rounds (default 1 if empty): " rounds
            rounds=${rounds:-1}
            
            original_size=${#text}
            estimated_info=$(calc_size_info "$original_size" "$rounds")
            echo -e "\n${YELLOW}[Size Estimate] Encrypted text size approx: ${GREEN}${estimated_info}${NC}"
            
            # Core anti-lag logic: more than 5 rounds uses file streaming, no variable storage
            if [ "$rounds" -gt 5 ]; then
                echo -e "${RED}[WARNING] More than 5 rounds produces huge ciphertext. To prevent memory overflow and terminal lag, results will be written directly to a file.${NC}"
                read -p "Enter filename to save (e.g., secret.txt.qah): " save_file
                if [ -z "$save_file" ]; then
                    echo -e "${RED}[Cancel] Empty filename, encryption aborted.${NC}"
                elif [ -e "$save_file" ]; then
                    echo -e "${RED}[Error] File '$save_file' already exists, cancelled to prevent overwrite.${NC}"
                else
                    echo -e "${YELLOW}Streaming encryption writing directly to file (no RAM usage)...${NC}"
                    printf "%s" "$text" | do_encrypt_stream_rounds "$rounds" > "$save_file"
                    echo -e "${GREEN}[Success] Result saved to: $(pwd)/$save_file${NC}"
                fi
            else
                read -p "Confirm encryption? (Y/n): " confirm_text
                if [[ "$confirm_text" =~ ^[Nn]$ ]]; then
                    echo -e "${RED}[Cancel] Encryption aborted.${NC}"
                else
                    echo -e "\n${YELLOW}Encrypting (rounds: $rounds)...${NC}"
                    # <=5 rounds size is manageable, capture to variable for display
                    result=$(printf "%s" "$text" | do_encrypt_stream_rounds "$rounds")
                    
                    echo -e "${CYAN}================ Encryption Result ================${NC}"
                    echo -e "${GREEN}$result${NC}"
                    echo -e "${CYAN}====================================================${NC}"
                    
                    read -p "Save result to a file in current directory? (y/N): " input_choice
                    if [[ "$input_choice" =~ ^[Yy]$ ]]; then
                        read -p "Enter filename to save (e.g., secret.txt.qah): " save_file
                        if [ -z "$save_file" ]; then
                            echo -e "${RED}[Cancel] Empty filename.${NC}"
                        elif [ -e "$save_file" ]; then
                            echo -e "${RED}[Error] File '$save_file' already exists, cancelled to prevent overwrite.${NC}"
                        else
                            printf "%s\n" "$result" > "$save_file"
                            echo -e "${GREEN}[Success] Result saved to: $(pwd)/$save_file${NC}"
                        fi
                    fi
                fi
            fi
            ;;
        2)
            echo -e "\n${GREEN}Enter ciphertext to decrypt (paste multiple lines, type 'EOF' to finish):${NC}"
            text=""
            while IFS= read -r line; do
                [ "$line" = "EOF" ] && break
                [ -z "$text" ] && text="$line" || text="$text
$line"
            done
            read -p "Enter decryption rounds (default 1 if empty): " rounds
            rounds=${rounds:-1}
            echo -e "\n${YELLOW}Decrypting (rounds: $rounds)...${NC}"
            
            result=$(printf "%s" "$text" | do_decrypt_stream_rounds "$rounds")
            trimmed_result="${result//[[:space:]]/}"
            
            echo -e "${CYAN}================ Decryption Result ================${NC}"
            if [ -z "$trimmed_result" ]; then
                echo -e "${RED}(Decryption result is blank, no valid content)${NC}"
                echo -e "${CYAN}==================================================${NC}"
                echo -e "${YELLOW}[Hint] Possible wrong ciphertext, round mismatch, or original text was empty.${NC}"
            else
                echo -e "${GREEN}$result${NC}"
                echo -e "${CYAN}==================================================${NC}"

                read -p "Save decryption result to a file? (y/N): " input_choice
                if [[ "$input_choice" =~ ^[Yy]$ ]]; then
                    read -p "Enter filename to save (e.g., secret.txt): " save_file
                    if [ -z "$save_file" ]; then
                        echo -e "${RED}[Cancel] Empty filename.${NC}"
                    elif [ -e "$save_file" ]; then
                        echo -e "${RED}[Error] File '$save_file' already exists, cancelled to prevent overwrite.${NC}"
                    else
                        printf "%s\n" "$result" > "$save_file"
                        echo -e "${GREEN}[Success] Result saved to: $(pwd)/$save_file${NC}"
                    fi
                fi
            fi
            ;;
        3)
            echo -e "\n${GREEN}Current directory: $(pwd)${NC}"
            read -p "Enter file(s) to encrypt (space-separated or wildcard like *.txt): " file_pattern
            read -p "Enter encryption rounds (default 1 if empty): " rounds
            rounds=${rounds:-1}
            
            count=0
            for fname in $file_pattern; do
                if [ -f "$fname" ]; then
                    outname="${fname}.qah"
                    if [ -e "$outname" ]; then
                        echo -e "${RED}[Skip] $outname already exists, preventing overwrite.${NC}"
                        continue
                    fi
                    
                    original_size=$(wc -c < "$fname" | tr -d '[:space:]')
                    estimated_info=$(calc_size_info "$original_size" "$rounds")
                    
                    echo -e "${YELLOW}Preparing to encrypt: $fname (rounds: $rounds)${NC}"
                    echo -e "${YELLOW}[Size Estimate] Encrypted file size approx: ${GREEN}${estimated_info}${NC}"
                    read -p "Confirm encryption and save? (Y/n): " confirm_file
                    
                    if [[ "$confirm_file" =~ ^[Nn]$ ]]; then
                        echo -e "${RED}[Cancel] Skipping $fname${NC}"
                        continue
                    fi
                    
                    echo -e "${YELLOW}Streaming encryption: $fname ...${NC}"
                    cat "$fname" | do_encrypt_stream_rounds "$rounds" > "$outname"
                    echo -e "${GREEN}[Success] -> $outname${NC}"
                    ((count++))
                else
                    echo -e "${RED}[Skip] $fname (invalid or not found)${NC}"
                fi
            done
            echo -e "${CYAN}Batch processing complete. Successfully encrypted $count file(s).${NC}"
            ;;
        4)
            echo -e "\n${GREEN}Current directory: $(pwd)${NC}"
            read -p "Enter file(s) to decrypt (space-separated or wildcard like *.qah): " file_pattern
            read -p "Enter decryption rounds (default 1 if empty): " rounds
            rounds=${rounds:-1}
            
            count=0
            for fname in $file_pattern; do
                if [ -f "$fname" ]; then
                    if [[ "$fname" == *.qah ]]; then
                        outname="${fname%.qah}"
                    else
                        outname="${fname}.dec"
                    fi
                    
                    if [ -e "$outname" ]; then
                        echo -e "${RED}[Skip] $outname already exists, preventing overwrite.${NC}"
                        continue
                    fi

                    echo -e "${YELLOW}Streaming decryption: $fname (rounds: $rounds)...${NC}"
                    cat "$fname" | do_decrypt_stream_rounds "$rounds" > "$outname"
                    echo -e "${GREEN}[Success] -> $outname${NC}"
                    ((count++))
                else
                    echo -e "${RED}[Skip] $fname (invalid or not found)${NC}"
                fi
            done
            echo -e "${CYAN}Batch processing complete. Successfully decrypted $count file(s).${NC}"
            ;;
        5) exit 0 ;;
        *) echo -e "${RED}Invalid option!${NC}" ;;
    esac
    
    echo -e "\n${YELLOW}Press Enter to return to main menu...${NC}"
    read
    show_menu
}

# CLI quick-call support
if [ "$1" == "e" ]; then 
    rounds=${3:-1}
    if [ "$rounds" -gt 5 ]; then
        echo -e "${RED}[WARNING] In CLI mode, more than 5 rounds may cause terminal freeze. Use interactive menu or file encryption (ef).${NC}"
        exit 1
    fi
    printf "%s" "$2" | do_encrypt_stream_rounds "$3"; exit 0; 
fi
if [ "$1" == "d" ]; then printf "%s" "$2" | do_decrypt_stream_rounds "$3"; exit 0; fi
if [ "$1" == "ef" ]; then cat "$2" | do_encrypt_stream_rounds "$4" > "$3"; exit 0; fi
if [ "$1" == "df" ]; then cat "$2" | do_decrypt_stream_rounds "$4" > "$3"; exit 0; fi

show_menu
