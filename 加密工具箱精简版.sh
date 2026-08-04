#!/bin/bash
export LC_ALL=C;trap 'rm -f .q_*_$$' EXIT
E(){ od -An -tu1 -v|awk 'BEGIN{c="kmpqrstuvwxyzabc";for(i=1;i<=16;i++)H[i]=substr(c,i,1)}{for(i=1;i<=NF;i++){v=($i*3+17)%256;printf "%s%s",H[int(v/16)+1],H[v%16+1];if(++k%1024==0)print ""}}';}
D(){ awk 'BEGIN{c="kmpqrstuvwxyzabc";for(i=1;i<=16;i++)C[substr(c,i,1)]=i-1}{l=length($0);for(i=1;i<=l;i+=2){a=substr($0,i,1);b=substr($0,i+1,1);if(a in C&&b in C)printf "%c",(((C[a]*16+C[b]-17)%256+256)%256*171)%256}}';}
R(){ local r=$1 t=$2 f=.q_$$ i=1;cat>$f.1;while [ $i -le $r ];do [ $t = e ]&&E<$f.1>$f.2||D<$f.1>$f.2;mv $f.2 $f.1;((i++));done;cat $f.1;rm -f $f.1 $f.2;}
S(){ awk -v s=$1 -v r=$2 'BEGIN{e=s*2^r;m=e/2^20;k=e/1024;printf(m>=1?"%.1fMB":k>=1?"%.1fKB":"%dB")"(%dB)\n",m>=1?m:k>=1?k:e,e}';}
W(){ read -p "存文件(y/N):" c;[[ $c =~ [Yy] ]]&&{ read -p "名:" f;[ -z "$f" ]&&echo 取消||{ [ -e "$f" ]&&echo 已存在||{ cat>$f;echo 存:$f;};};}||cat>/dev/null;}
G(){ t="";while IFS= read -r l;do [ "$l" = EOF ]&&break;t="${t:+$t$'\n'}$l";done;}
[ "$1" = e ]&&{ [ "${3:-1}" -gt 5 ]&&echo ">5轮请用菜单"&&exit 1;printf "%s" "$2"|R ${3:-1} e;exit;}
[ "$1" = d ]&&{ printf "%s" "$2"|R ${3:-1} d;exit;}
[ "$1" = ef ]&&{ cat "$2"|R ${4:-1} e>"$3";exit;}
[ "$1" = df ]&&{ cat "$2"|R ${4:-1} d>"$3";exit;}
while :;do
clear;echo "=== 乐天独创加密 ===
1.加密文本 2.解密文本 3.加密文件 4.解密文件 5.退出"
read -p "选:" ch
case $ch in
1) echo "文本(EOF结束):";G;read -p "轮数(1):" r;r=${r:-1};echo "预估:$(S ${#t} $r)"
if [ $r -gt 5 ];then echo ">5轮直写硬盘";read -p "名:" f;[ -z "$f" ]&&echo 取消||{ [ -e "$f" ]&&echo 已存在||{ printf "%s" "$t"|R $r e>"$f";echo 存:$f;};}
else read -p "确认(Y/n):" c;[[ $c =~ [Nn] ]]&&echo 取消||{ printf "%s" "$t"|R $r e|tee .q_t_$$;echo;W<.q_t_$$;rm -f .q_t_$$;};fi;;
2) echo "密文(EOF结束):";G;read -p "轮数(1):" r;r=${r:-1};res=$(printf "%s" "$t"|R $r d);tr=${res//[[:space:]]/}
[ -z "$tr" ]&&echo "(空白)"||{ printf "%s\n" "$res";printf "%s" "$res"|W;};;
3) read -p "文件(*):" p;read -p "轮数(1):" r;r=${r:-1};c=0
for f in $p;do [ -f "$f" ]&&{ o="$f.qah";[ -e "$o" ]&&echo "跳$o"||{ echo "[$f]预估:$(S $(wc -c <"$f") $r)";read -p "确认(Y/n):" y;[[ $y =~ [Nn] ]]&&echo 取消||{ cat "$f"|R $r e>"$o";echo "->$o";((c++));};};};done;echo "完成:$c";;
4) read -p "当前目录文件(*):" p;read -p "轮数(1):" r;r=${r:-1};c=0
for f in $p;do [ -f "$f" ]&&{ [[ "$f" == *.qah ]]&&o="${f%.qah}"||o="$f.dec";[ -e "$o" ]&&echo "跳$o"||{ cat "$f"|R $r d>"$o";echo "->$o";((c++));};};done;echo "完成:$c";;
5) exit;;esac
read -p "回车...";done
