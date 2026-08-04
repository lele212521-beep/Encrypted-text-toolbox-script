#!/bin/bash

# ==========================================
# 文件加密解密器 ()
# 核心重构: 磁盘流式缓冲引擎，彻底解决大轮数内存卡顿
# ==========================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# --- 核心单轮算法引擎 ---
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

# --- 多轮流式引擎 (使用磁盘临时文件，防内存溢出) ---
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

# --- 容量预估通用函数 ---
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

# --- 交互式菜单 ---
show_menu() {
    clear
    echo -e "${CYAN}=================================================${NC}"
    echo -e "${CYAN}    乐天原创文本/文件加密解密器 (独创加密语言)         ${NC}"
    echo                       作者乐天
    echo             支持多轮加密和解密，而且防内存卡顿
    echo -e "${CYAN}=================================================${NC}"
    echo -e "${YELLOW}1. 加密文本 ${NC}"
    echo -e "${YELLOW}2. 解密文本 ${NC}"
    echo -e "${YELLOW}3. 加密文本文件${NC}"
    echo -e "${YELLOW}4. 解密文本文件${NC}"
    echo -e "${YELLOW}5. 退出程序${NC}"
    echo -e "${CYAN}=================================================${NC}"
    read -p "请选择操作 [1-5]: " choice

    case $choice in
        1)
            echo -e "\n${GREEN}请输入要加密的文本 (新行输入 'EOF' 回车结束):${NC}"
            text=""
            while IFS= read -r line; do
                [ "$line" = "EOF" ] && break
                [ -z "$text" ] && text="$line" || text="$text
$line"
            done
            read -p "请输入加密轮数 (直接回车默认1次): " rounds
            rounds=${rounds:-1}
            
            original_size=${#text}
            estimated_info=$(calc_size_info "$original_size" "$rounds")
            echo -e "\n${YELLOW}[容量预估] 加密后的文本约为: ${GREEN}${estimated_info}${NC}"
            
            # 【核心防卡顿逻辑】：大于5轮直接走文件流，不生成变量
            if [ "$rounds" -gt 5 ]; then
                echo -e "${RED}[警告] 加密轮数大于5次，密文体积巨大。为防止内存溢出和终端卡顿，将采用【直接写入文件】模式。${NC}"
                read -p "请输入要保存的文件名 (例如: secret.txt.qah): " save_file
                if [ -z "$save_file" ]; then
                    echo -e "${RED}[取消] 文件名为空，放弃加密。${NC}"
                elif [ -e "$save_file" ]; then
                    echo -e "${RED}[错误] 文件 '$save_file' 已存在，为防止覆盖已取消。${NC}"
                else
                    echo -e "${YELLOW}正在流式加密并直接写入文件 (不占用运存)...${NC}"
                    printf "%s" "$text" | do_encrypt_stream_rounds "$rounds" > "$save_file"
                    echo -e "${GREEN}[成功] 结果已直接保存到: $(pwd)/$save_file${NC}"
                fi
            else
                read -p "是否确认开始加密？(Y/n): " confirm_text
                if [[ "$confirm_text" =~ ^[Nn]$ ]]; then
                    echo -e "${RED}[取消] 已放弃加密。${NC}"
                else
                    echo -e "\n${YELLOW}连续加密中 (轮数: $rounds)...${NC}"
                    # <=5轮体积可控，捕获到变量用于显示
                    result=$(printf "%s" "$text" | do_encrypt_stream_rounds "$rounds")
                    
                    echo -e "${CYAN}================ 加密结果 ================${NC}"
                    echo -e "${GREEN}$result${NC}"
                    echo -e "${CYAN}==========================================${NC}"
                    
                    read -p "是否将加密结果保存到当前目录的文件中？(y/N): " input_choice
                    if [[ "$input_choice" =~ ^[Yy]$ ]]; then
                        read -p "请输入保存的文件名 (例如: secret.txt.qah): " save_file
                        if [ -z "$save_file" ]; then
                            echo -e "${RED}[取消] 文件名为空。${NC}"
                        elif [ -e "$save_file" ]; then
                            echo -e "${RED}[错误] 文件 '$save_file' 已存在，为防止覆盖已取消保存。${NC}"
                        else
                            printf "%s\n" "$result" > "$save_file"
                            echo -e "${GREEN}[成功] 结果已保存到: $(pwd)/$save_file${NC}"
                        fi
                    fi
                fi
            fi
            ;;
        2)
            echo -e "\n${GREEN}请输入要解密的密文 (支持多行粘贴，新行输入 'EOF' 回车结束):${NC}"
            text=""
            while IFS= read -r line; do
                [ "$line" = "EOF" ] && break
                [ -z "$text" ] && text="$line" || text="$text
$line"
            done
            read -p "请输入解密轮数 (直接回车默认1次): " rounds
            rounds=${rounds:-1}
            echo -e "\n${YELLOW}连续解密中 (轮数: $rounds)...${NC}"
            
            result=$(printf "%s" "$text" | do_decrypt_stream_rounds "$rounds")
            trimmed_result="${result//[[:space:]]/}"
            
            echo -e "${CYAN}================ 解密结果 ================${NC}"
            if [ -z "$trimmed_result" ]; then
                echo -e "${RED}(解密结果为空白，无有效内容)${NC}"
                echo -e "${CYAN}==========================================${NC}"
                echo -e "${YELLOW}[提示] 可能是密文错误、轮数不匹配或原文本即为空白。${NC}"
            else
                echo -e "${GREEN}$result${NC}"
                echo -e "${CYAN}==========================================${NC}"

                read -p "是否将解密结果保存到当前目录的文件中？(y/N): " input_choice
                if [[ "$input_choice" =~ ^[Yy]$ ]]; then
                    read -p "请输入保存的文件名 (例如: secret.txt): " save_file
                    if [ -z "$save_file" ]; then
                        echo -e "${RED}[取消] 文件名为空。${NC}"
                    elif [ -e "$save_file" ]; then
                        echo -e "${RED}[错误] 文件 '$save_file' 已存在，为防止覆盖已取消保存。${NC}"
                    else
                        printf "%s\n" "$result" > "$save_file"
                        echo -e "${GREEN}[成功] 结果已保存到: $(pwd)/$save_file${NC}"
                    fi
                fi
            fi
            ;;
        3)
            echo -e "\n${GREEN}当前目录: $(pwd)${NC}"
            read -p "请输入要加密的文件 (支持空格分隔或通配符如 *.txt): " file_pattern
            read -p "请输入加密轮数 (直接回车默认1次): " rounds
            rounds=${rounds:-1}
            
            count=0
            for fname in $file_pattern; do
                if [ -f "$fname" ]; then
                    outname="${fname}.qah"
                    if [ -e "$outname" ]; then
                        echo -e "${RED}[跳过] $outname 已存在，防止覆盖。${NC}"
                        continue
                    fi
                    
                    original_size=$(wc -c < "$fname" | tr -d '[:space:]')
                    estimated_info=$(calc_size_info "$original_size" "$rounds")
                    
                    echo -e "${YELLOW}准备加密: $fname (轮数: $rounds)${NC}"
                    echo -e "${YELLOW}[容量预估] 加密后的文件约为: ${GREEN}${estimated_info}${NC}"
                    read -p "是否确认加密并保存？(Y/n): " confirm_file
                    
                    if [[ "$confirm_file" =~ ^[Nn]$ ]]; then
                        echo -e "${RED}[取消] 跳过 $fname${NC}"
                        continue
                    fi
                    
                    echo -e "${YELLOW}正在流式加密: $fname ...${NC}"
                    cat "$fname" | do_encrypt_stream_rounds "$rounds" > "$outname"
                    echo -e "${GREEN}[成功] -> $outname${NC}"
                    ((count++))
                else
                    echo -e "${RED}[跳过] $fname (不适合或不存在)${NC}"
                fi
            done
            echo -e "${CYAN}批量处理完成，共成功加密 $count 个文件。${NC}"
            ;;
        4)
            echo -e "\n${GREEN}当前目录: $(pwd)${NC}"
            read -p "请输入要解密的文件 (支持空格分隔或通配符如 *.qah): " file_pattern
            read -p "请输入解密轮数 (直接回车默认1次): " rounds
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
                        echo -e "${RED}[跳过] $outname 已存在，防止覆盖。${NC}"
                        continue
                    fi

                    echo -e "${YELLOW}正在流式解密: $fname (轮数: $rounds)...${NC}"
                    cat "$fname" | do_decrypt_stream_rounds "$rounds" > "$outname"
                    echo -e "${GREEN}[成功] -> $outname${NC}"
                    ((count++))
                else
                    echo -e "${RED}[跳过] $fname (不适合或不存在)${NC}"
                fi
            done
            echo -e "${CYAN}批量处理完成，共成功解密 $count 个文件。${NC}"
            ;;
        5) exit 0 ;;
        *) echo -e "${RED}无效选择！${NC}" ;;
    esac
    
    echo -e "\n${YELLOW}按回车键返回主菜单...${NC}"
    read
    show_menu
}

# 支持命令行快捷调用
if [ "$1" == "e" ]; then 
    rounds=${3:-1}
    if [ "$rounds" -gt 5 ]; then
        echo -e "${RED}[警告] 命令行模式下加密轮数大于5次会导致终端卡死，请使用交互菜单或文件加密(ef)。${NC}"
        exit 1
    fi
    printf "%s" "$2" | do_encrypt_stream_rounds "$3"; exit 0; 
fi
if [ "$1" == "d" ]; then printf "%s" "$2" | do_decrypt_stream_rounds "$3"; exit 0; fi
if [ "$1" == "ef" ]; then cat "$2" | do_encrypt_stream_rounds "$4" > "$3"; exit 0; fi
if [ "$1" == "df" ]; then cat "$2" | do_decrypt_stream_rounds "$4" > "$3"; exit 0; fi

show_menu
