#!/bin/sh
# csr.sh: Генератор приватных ключей и запросов на сертификат

# Установка безопасного разрешения на файл
LASTUMASK=`umask`
umask 077

# OpenSSL for HPUX needs a random file
RANDOMFILE=$HOME/.rnd

# Создание конфигурационного файла для OpenSSL
CONFIG=`mktemp -q /tmp/openssl-conf.XXXXXXXX`
if [ ! $? -eq 0 ]; then
	echo "Не удалось создать временный файл конфигурации. Выходим."
	exit 1
fi

echo "Генератор приватных ключей и запросов на сертификат"
echo

printf "Короткое имя хоста (например: server ns2 ftp imap mx support): "
read HOST	# Чтение введённого имени хоста
printf "Полное доменное имя/FQDN/CommonName (например: example.com) : "
read COMMONNAME	# Чтение введённого названия домена

echo "Введите SubjectAltNames для сертификата, по одному в каждой строке. Нажмите Enter на пустой строке, чтобы закончить."
echo "(например: DNS.1 = example.com)"
echo "(например: DNS.2 = mail.example.com)"
echo "(например: DNS.3 = www.example.com)"
echo "(например: DNS.4 = www.sub.example.com)"
echo "(например: DNS.5 = mx.example.com)"
echo "(например: DNS.6 = support.example.com)"

SAN=1	# Фиктивное значение, чтобы начать цикл
SANAMES=""
while [ ! "$SAN" = "" ]; do
	printf "SubjectAltName: DNS:"
	read SAN
	if [ "$SAN" = "" ]; then break; fi	# Конец ввода
	if [ "$SANAMES" = "" ]; then
		SANAMES="DNS:$SAN"
	else
		SANAMES="$SANAMES,DNS:$SAN"
	fi
done

# Создание конфигурационного файла

cat <<EOF > $CONFIG
# -------------- BEGIN custom openssl.cnf -----
	HOME	= $HOME
EOF

if [ "`uname -s`" = "HP-UX" ]; then
	echo " RANDFILE                = $RANDOMFILE" >> $CONFIG
fi

cat <<EOF >> $CONFIG
	oid_section		= new_oids
	[ new_oids ]
	[ req ]
	default_days		= 730	# Срок действия сетрификата в днях 730 это 2 года
	default_keyfile	= $HOME/${HOST}_privatekey.pem
	distinguished_name	= req_distinguished_name
	default_md		= sha256	# Шифрование по умолчанию sha256 для создаваемых запросов. Старое значение sha1
	encrypt_key		= no
	string_mask		= nombstr
EOF

if [ ! "$SANAMES" = "" ]; then
    echo "req_extensions = v3_req # Расширения для добавления к запросу на сертификат" >> $CONFIG
fi

cat <<EOF >> $CONFIG
 [ req_distinguished_name ]
 commonName		= Common Name (eg, YOUR name)
 commonName_default	= $COMMONNAME
 commonName_max		= 64
 [ v3_req ]
EOF

if [ ! "$SANAMES" = "" ]; then
    echo "subjectAltName=$SANAMES" >> $CONFIG
fi

echo "# -------------- END custom openssl.cnf -----" >> $CONFIG

echo "Запуск OpenSSL..."

############### Блок выбора шифрования ###############
ONERSA=2048	# Переменная, в данном случае битность шифрования в 2048 bit
TWORSA=4096	# Переменная, в данном случае битность шифрования в 4096 bit
TREERSA=8192	# Переменная, в данном случае битность шифрования в 8192 bit

echo "Выберите битность ключа (введите цифру от 1 до 3 ):"
echo "1) для шифрования 2048 bit RSA (Fast)"
echo "2) для шифрования 4096 bit RSA (Optimally)"
echo "3) для шифрования 8192 bit RSA (Slow)"
read DOING	# здесь мы читаем в переменную $DOING со стандартного ввода

case $DOING in
1)
openssl req -batch -config $CONFIG -newkey rsa:${ONERSA} -out $HOME/${HOST}_csr.pem	# если $DOING содержит 1, то подставить 2048
;;
2)
openssl req -batch -config $CONFIG -newkey rsa:${TWORSA} -out $HOME/${HOST}_csr.pem	# если $DOING содержит 2, то подставить 4096
;;
3)
openssl req -batch -config $CONFIG -newkey rsa:${TREERSA} -out $HOME/${HOST}_csr.pem	# если $DOING содержит 3, то подставить 8192
;;
*)	# если введено с клавиатуры то, что в case не описывается, выполнять следующее:
echo "Введено неправильное действие"

esac	# окончание оператора case.

############### Блок выбора шифрования ###############

echo "Скопируйте следующий запрос на сертификат и вставте в форму для получения сертификата."
echo "Когда вы получите свой сертификат, назовите его наподобие этого ${HOST}_server.pem"
echo
cat $HOME/${HOST}_csr.pem
echo
echo "Запрос сертификата находится здесь $HOME/${HOST}_csr.pem"
echo "Приватный ключ хранится здесь $HOME/${HOST}_privatekey.pem"
echo
echo "=======================Certificate Request======================="
openssl req -text -noout -in $HOME/${HOST}_csr.pem
echo

rm $CONFIG

# Восстановление umask
umask $LASTUMASK
