#!/bin/sh
while :; do
    printf "乐天独创加密工具[1]加密 [2]解密 [q]退出: "
    read m
    [ "$m" = "q" ] && exit
    [ "$m" != "1" ] && [ "$m" != "2" ] && continue
    
    printf "输入文本(单行): "
    IFS= read -r t
    
    if [ "$m" = "1" ]; then
        printf '%s' "$t" | LC_ALL=C od -An -tu1 -v | LC_ALL=C awk '
            BEGIN { split("k m p q r s t u v w x y z a b c", H) }
            { for(i=1; i<=NF; i++) { v=($i*3+17)%256; printf "%s%s", H[int(v/16)+1], H[v%16+1] } }
            END { print "" }'
    elif [ "$m" = "2" ]; then
        printf '%s' "$t" | LC_ALL=C awk '
            BEGIN { split("k m p q r s t u v w x y z a b c", c); for(i=1;i<=16;i++) C[c[i]]=i-1 }
            { for(i=1; i<=length($0); i+=2) { 
                a=substr($0,i,1); b=substr($0,i+1,1)
                if(a in C && b in C) printf "%c", (((C[a]*16+C[b]-17)%256+256)%256*171)%256 
              }
            }
            END { print "" }'
    fi
    printf "\n回车继续..."
    read _
done
