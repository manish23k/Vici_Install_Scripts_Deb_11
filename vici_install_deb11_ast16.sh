#!/bin/bash

#################################
##########  variables ###########
#################################

#COLORS
Color_Off='\033[0m'       # Text Reset
# Regular Colors
Red='\033[0;31m'          # Red
Green='\033[0;32m'        # Green
Yellow='\033[0;33m'       # Yellow
Cyan='\033[0;36m'         # Cyan
DATE=`date "+%Y:%m:%d-%H:%M:%S"`
tty=$(tty)



#Set as 0 if you do not want to install dialer on this server
INSTALL_DIALER=1
#Set as 0 if you do not want to install web on this server
INSTALL_WEB=1
#Set as 0 if you do not want to install database on this server
INSTALL_DB=1

#################################
####  general functions #########
#################################

#Get user specified data
get_ipdomain ()
{
        read -p "Enter your Local/Public IP (i.e 192.168.1.100): "
        Server_IP=${REPLY}
        read -n 1 -p "Press any key to continue ... "
}

#Generate random password
genpasswd()
{
        length=$1
        [ "$length" == "" ] && length=16
        tr -dc '12345_qwertQWERT_sdfgASDFzx_vbZXC_B' < /dev/urandom | head -c ${length} | xargs
}

#Generate 6 digit Value for API
genvalueapi()
{
       length=$1
       [ "$length" == "" ] && length=6
       tr -dc '123456' < /dev/urandom | head -c ${length} | xargs
}

#Generate random port
genport()
{
        length=$1
        [ "$length" == "" ] && length=4
        tr -dc '456789' < /dev/urandom | head -c ${length} | xargs
}

#setting port
setport()
{
        if [ -f /var/log/installation.log ]; then
                MYSQL_ROOT_PASSWORD=$(cat /var/log/installation.log | head -n1 | tail -n1 | cut -c 21-40)
                MYSQL_CRON_PASSWORD=$(cat /var/log/installation.log | head -n2 | tail -n1 | cut -c 21-40)
                REBOOT=$(cat /var/log/installation.log | head -n3 | tail -n1 | cut -c 8)
                PERL=$(cat /var/log/installation.log | head -n4 | tail -n1 | cut -c 6)
        else
                MYSQL_ROOT_PASSWORD=$(genpasswd 20)
                MYSQL_CRON_PASSWORD=1234
                touch /var/log/installation.log
                echo MYSQL_ROOT_PASSWORD=$MYSQL_ROOT_PASSWORD>> /var/log/installation.log
                echo MYSQL_CRON_PASSWORD=$MYSQL_CRON_PASSWORD >> /var/log/installation.log
        fi
}

#Fetch OS Distribution
get_linux_distribution ()
{
	V1="`cat /etc/os-release | head -n1 | tail -n1 | cut -c 14- | cut -c1-19`"
	if [[ $V1 = "" ]]; then
		V1="`cat /etc/*release | head -n4 | tail -n1 | cut -c 14- | cut -c1-19`"
	fi
	
	if [[ $V1 = "Debian GNU/Linux 11" ]]; then
                echo "Debian 11"
				DIST="DEBIAN"
                echo -e "Found Debian 11, Starting Installation...."

				if [ "$(id -u)" != "0" ]; then
					echo "This installation script must be run as root !!!" 1>&2
					exit 1
				fi

				#Internet availablity check
				ping -q -c 1 google.com > /dev/null
				if [ $? -ne 0 ]; then
					echo "You must require Internet connectivity to continue installation !!!"
					exit 1
				fi				

				apt-get -y update
				apt-get -y install mokutil
				SecureBoot=""
				mokutil --sb-state
				if [ $? == 'SecureBoot enabled' ]; then
				echo -e "Please disable SecureBoot from boot options and then retry !!!" && exit 1
				else

				echo "deb http://ftp.de.debian.org/debian buster main" | tee /etc/apt/sources.list.d/unixodbc-bin.list	
				fi
	else
				DIST="OTHER"
                echo -e "Ooops!!! Your linux distribution is not supported, please install Debian 11 and contact the support team."
                exit 1

    fi
	
}


#Install Prerequisties
install_prerequisties ()
{

    echo -e "$Cyan==========================================$Color_Off"
    echo -e "$Yellow Installing prerequisties"
    echo -e "$Cyan==========================================$Color_Off"
    apt-get -y update

	sleep 2s
	apt-get install -y build-essential
	apt-get install -y dirmngr --install-recommends
	apt-get install -y subversion htop wget mailutils git ntpdate systemd glibc-source net-tools whois sendmail-bin sensible-mda mlocate vim ffmpeg dnsutils curl cron sudo 
		
	
	#echo "Adding GCC-10 Version......... "
	rm /usr/bin/gcc
	rm /usr/bin/g++
	ln -s /usr/bin/gcc-10 /usr/bin/gcc
	ln -s /usr/bin/g++-10 /usr/bin/g++
		
    apt-get install -y libgmime* libsrtp* unixodbc unixodbc-bin
    
	apt-get install -y mariadb-client libmysqlclient-dev* libmariadb-dev-compat libmariadb-dev default-libmysqlclient-dev*

	if [[ $INSTALL_DIALER == "1" ]]; then
		install_header
	fi
	
	   
	echo "REBOOT=1" >> /var/log/installation.log
	clear
	echo -e "$Red ---------- YOUR SERVER WILL BE REBOOTED NOW. PLEASE RE-RUN THE INSTALLATION SCRIPT ONCE SERVER IS REBOOTED ------ $Color_Off"
	sleep 5s
	echo -e "$Red ---------- REBOOTING NOW. . . . . $Color_Off"
	sleep 10s
	/sbin/reboot now
	exit 1
}

#Install Kernel Headers
install_header ()
{
		apt-get -y install linux-image-amd64 linux-headers-amd64
        apt-get -y install linux-headers-$(uname -r)
}


get_sourcecode ()
{
		mkdir /usr/src/astguiclient
		mkdir /usr/src/extra
        cd /usr/src/astguiclient
        rm -rf /usr/src/astguiclient/trunk
        clear
		
		c=1
		dl=0
		while ([ $c -le 3 ] && [ $dl -eq 0 ])
		do
				echo -n "Please enter 4 digit SVN version code (Keep blank for latest SVN): "
				read  svn
				if [[ $svn = '' ]]
				then
						svn checkout svn://svn.eflo.net:3690/agc_2-X/trunk
						dl=1
				else
						svn checkout -r $svn svn://svn.eflo.net:3690/agc_2-X/trunk | grep -q 'No such revision'
						if [ $? -eq 0 ]; then
								echo "Error: SVN version $version is not valid. Please try again."
								(( c++ ))
						else
								dl=1
						fi
				fi
		done

		if [[ $dl == "0" ]]; then
			exit 1
		fi
}

get_packages ()
{
		mkdir /usr/src/asterisk
        cd /usr/src/asterisk
        #Added AST-16 By Manish
        wget -c http://download.vicidial.com/required-apps/asterisk-16.30.1-vici.tar.gz
		wget -c https://downloads.asterisk.org/pub/telephony/dahdi-linux-complete/dahdi-linux-complete-3.2.0+3.2.0.tar.gz
		wget -c http://download.vicidial.com/required-apps/asterisk-perl-0.08.tar.gz
		wget -c https://downloads.asterisk.org/pub/telephony/libpri/libpri-1.6.1.tar.gz
		wget -c http://dl.icallify.com/extra/codec-install.sh
		
}

#Mariadb Installation
install_mariadb ()
{

		apt-get install -y mariadb-server
        echo -e "$Cyan==========================================$Color_Off"
        echo -e "$Yellow Installing Database & Configurations $Color_Off"
        echo -e "$Cyan==========================================$Color_Off"

		mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '$MYSQL_ROOT_PASSWORD'; flush privileges;"
        
		mysql -uroot -p$MYSQL_ROOT_PASSWORD -e "CREATE DATABASE asterisk DEFAULT CHARACTER SET utf8 COLLATE utf8_unicode_ci;"
        mysql -uroot -p$MYSQL_ROOT_PASSWORD -e "CREATE USER 'cron'@'localhost' IDENTIFIED BY '$MYSQL_CRON_PASSWORD';"
        mysql -uroot -p$MYSQL_ROOT_PASSWORD -e "GRANT CREATE,SELECT,INSERT,UPDATE,DELETE,LOCK TABLES on asterisk.* TO cron@'%' IDENTIFIED BY '$MYSQL_CRON_PASSWORD';"
        mysql -uroot -p$MYSQL_ROOT_PASSWORD -e "GRANT CREATE,SELECT,INSERT,UPDATE,DELETE,LOCK TABLES on asterisk.* TO cron@localhost IDENTIFIED BY '$MYSQL_CRON_PASSWORD';"
        mysql -uroot -p$MYSQL_ROOT_PASSWORD -e "GRANT RELOAD ON *.* TO cron@'%';"
        mysql -uroot -p$MYSQL_ROOT_PASSWORD -e "GRANT RELOAD ON *.* TO cron@localhost;"
        
		
		mysql -uroot -p$MYSQL_ROOT_PASSWORD -e "CREATE USER 'custom'@'localhost' IDENTIFIED BY 'custom1234';"
		mysql -uroot -p$MYSQL_ROOT_PASSWORD -e "GRANT SELECT,CREATE,ALTER,INSERT,UPDATE,DELETE,LOCK TABLES on asterisk.* TO custom@'%' IDENTIFIED BY 'custom1234';"
		mysql -uroot -p$MYSQL_ROOT_PASSWORD -e "GRANT SELECT,CREATE,ALTER,INSERT,UPDATE,DELETE,LOCK TABLES on asterisk.* TO custom@localhost IDENTIFIED BY 'custom1234';"
		mysql -uroot -p$MYSQL_ROOT_PASSWORD -e "GRANT RELOAD ON *.* TO custom@'%';"
		mysql -uroot -p$MYSQL_ROOT_PASSWORD -e "GRANT RELOAD ON *.* TO custom@localhost;"
		mysql -uroot -p$MYSQL_ROOT_PASSWORD -e "flush privileges;"
		mysql -uroot -p$MYSQL_ROOT_PASSWORD -e "SET GLOBAL connect_timeout=60;"

		cd /usr/src/extra
		wget -c http://dl.icallify.com/extra/my.cnf
        mv /etc/mysql/my.cnf /etc/mysql/my.cnf_bkp
        cp -rf /usr/src/extra/my.cnf /etc/mysql/my.cnf

        systemctl restart mariadb
        
		mysql_config --libs
        mysql_config --cflags
		systemctl mask mysql
		systemctl enable mariadb
}

#Customization in Database
install_customsql ()
{
        echo -e "$Cyan==========================================$Color_Off"
        echo -e "$Yellow Importing database files $Color_Off"
        echo -e "$Cyan==========================================$Color_Off"
		mysql -f -uroot -p$MYSQL_ROOT_PASSWORD asterisk < /usr/src/astguiclient/trunk/extras/MySQL_AST_CREATE_tables.sql		
        mysql -f -uroot -p$MYSQL_ROOT_PASSWORD asterisk < /usr/src/astguiclient/trunk/extras/first_server_install.sql 
        mysql -uroot -p"$MYSQL_ROOT_PASSWORD" -D asterisk -e "update servers set asterisk_version='13.29.2';"
}



#Installing Web Server dependencies
install_php ()
{
        echo -e "$Cyan==========================================$Color_Off"
        echo -e "$Yellow Installating apache & php  $Color_Off"
        echo -e "$Cyan==========================================$Color_Off"

		apt-get -y install lsb-release apt-transport-https ca-certificates apache2 apache2-suexec-pristine libapache2-mpm-itk apache2-data
		wget -O /etc/apt/trusted.gpg.d/php.gpg https://packages.sury.org/php/apt.gpg
		echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" | tee /etc/apt/sources.list.d/php7.3.list
		apt-get update -y
		
		export DEBIAN_FRONTEND=noninteractive
		apt-get install -y php7.3 php7.3-imap php7.3-fpm php7.3-mysql php7.3-cli php7.3-json php7.3-readline php7.3-xml php7.3-curl php7.3-gd php7.3-json php7.3-mbstring php7.3-mysql php7.3-opcache php7.3-dev php7.3-zip
		
		apt-get install -y libapache2-mod-php7.3
		
		
        sed -i 's/^error_reporting=.*/error_reporting=E_ALL & ~E_NOTICE/g' /etc/php/7.3/apache2/php.ini
        sed -i 's/^memory_limit=.*/memory_limit=48M/g' /etc/php/7.3/apache2/php.ini
        sed -i 's/^short_open_tag =.*/short_open_tag=On/g' /etc/php/7.3/apache2/php.ini
        sed -i 's/^max_execution_time =.*/max_execution_time=330/g' /etc/php/7.3/apache2/php.ini
        sed -i 's/^max_input_time =.*/max_input_time=360/g' /etc/php/7.3/apache2/php.ini
        sed -i 's/^post_max_size =.*/post_max_size=48M/g' /etc/php/7.3/apache2/php.ini
        sed -i 's/^upload_max_filesize =.*/upload_max_filesize=42M/g' /etc/php/7.3/apache2/php.ini
        sed -i 's/^default_socket_timeout =.*/default_socket_timeout=360/g' /etc/php/7.3/apache2/php.ini
		update-alternatives --set php /usr/bin/php7.3


        systemctl restart apache2
		systemctl enable apache2
}

#Install Perl
install_perl ()
{
        echo -e "$Cyan==========================================$Color_Off"
        echo -e "$Yellow Perl Module Installation $Color_Off"
        echo -e "$Cyan==========================================$Color_Off"
		
		apt-get -y install perl libreadline-dev libterm-readline-perl-perl readline-common libi18n-charset-perl libunicode-map-perl libunicode-map8-perl libunicode-maputf8-perl libterm-readline-perl-perl libole-storage-lite-perl libspreadsheet-parseexcel-perl libspreadsheet-writeexcel-perl libjcode-perl libjcode-pm-perl libproc-pid-file-perl libio-stringy-perl libnet-telnet-perl libnet-server-perl libdbd-mysql-perl libproc-processtable-perl
		
        #Added for locale issue resolve
        localectl set-locale LANG=en_US.UTF-8
        sudo dpkg-reconfigure locales
        updatedb
        sleep 5s
        #Added for CPAN install issue fix
        PERL_MM_USE_DEFAULT=1 perl -MCPAN -e "CPAN::Shell->notest('install', 'IO::Socket::SSL', 'Bundle::CPAN', 'YAML', 'MD5', 'Digest::MD5', 'Digest::SHA1','readline' ,'DBI' ,'Devel::CheckLib' ,'Asterisk::AGI' ,'Net::Telnet','Time::HiRes' ,'Net::Server' ,'Switch' ,'Mail::Sendmail' ,'Unicode::Map' ,'Jcode' ,'OLE::Storage_Lite','Proc::ProcessTable' ,'IO::Scalar' ,'Curses' ,'Getopt::Long' ,'Net::Domain' ,'Term::ReadKey' ,'Term::ANSIColor' ,'LWP::UserAgent' ,'HTML::Entities' ,'HTML::Strip' ,'HTML::Element' ,'HTML::FormatText','HTML::TreeBuilder' ,'Time::Local','MIME::Decoder' ,'Mail::POP3Client' ,'Mail::IMAPClient' ,'Mail::Message' ,'IO::Socket::SSL' ,'MIME::Base64' ,'MIME::QuotedPrint' ,'Crypt::Eksblowfish::Bcrypt' ,'Text::CSV','Text::CSV_PP','Text::CSV_XS','DBD::mysql','Spreadsheet::Read','Spreadsheet::XLSX','JSON')"
		cpan -fi reload cpan
#		perl -MCPAN -e "reload cpan"
		

        echo "PERL=1" >> /var/log/installation.log
}

#Installing Asterisk
install_asterisk ()
{
        echo -e "$Cyan==========================================$Color_Off"
        echo -e "$Yellow Installling Asterisk Dependencies $Color_Off"
        echo -e "$Cyan==========================================$Color_Off"

		get_packages
		apt-get install -y autoconf libtool perl libpri-dev libtonezone-dev libproc-processtable-perl bison openssl libeditline0 libeditline-dev libedit-dev make libedit2 libncurses5 libncurses5-dev unzip zip libnewt-dev libnewt0.52 gcc-10 g++-10 libreadline5 libterm-readline-perl-perl readline-common libi18n-charset-perl libunicode-map-perl libunicode-map8-perl libunicode-maputf8-perl libreadline5 libterm-readline-perl-perl readline-common libole-storage-lite-perl libspreadsheet-parseexcel-perl libspreadsheet-writeexcel-perl libjcode-perl libjcode-pm-perl  libproc-pid-file-perl libio-stringy-perl libnet-telnet-perl libnet-server-perl iftop lame libploticus0-dev libsox-fmt-all mpg123 ntp openssh-server ploticus screen sipsak sox rdate ttyload git uuid uuid-dev libdata-uuid-libuuid-perl libsqlite3-dev sqlite3 libxml2-dev libjansson-dev libswitch-perl libsrtp* libssl-dev
	
        cd /usr/src/asterisk

        tar zxf asterisk-perl-0.08.tar.gz		
        tar zxf asterisk-16.30.1-vici.tar.gz      
		tar xzf dahdi-linux-complete-3.2.0+3.2.0.tar.gz		
        tar zxf libpri-1.6.0.tar.gz
		
        echo -e "$Cyan==========================================$Color_Off"
        echo -e "$Yellow Installing Dahdi $Color_Off"
        echo -e "$Cyan==========================================$Color_Off"

		
		cd /usr/src/asterisk/dahdi-linux-complete-3.2.0+3.2.0/		
		
		make clean M=$PWD
		make distclean M=$PWD
        make all M=$PWD
        make install M=$PWD
		make install-config M=$PWD
		/etc/init.d/dahdi start
		#make config M=$PWD
    
		

        echo -e "$Cyan==========================================$Color_Off"
        echo -e "$Yellow Installing Libpri $Color_Off"
        echo -e "$Cyan==========================================$Color_Off"
        cd /usr/src/asterisk/libpri-1.6.0
        make clean M=$PWD
        make M=$PWD
        make install M=$PWD 

        echo -e "$Cyan==========================================$Color_Off"
        echo -e "$Yellow Installing Asterisk-Perl $Color_Off"
        echo -e "$Cyan==========================================$Color_Off"		
        cd /usr/src/asterisk/asterisk-perl-0.08
        perl Makefile.PL
        make all M=$PWD
        make install M=$PWD				
		
		
		
        echo -e "$Cyan==========================================$Color_Off"
        echo -e "$Yellow Installing Asterisk $Color_Off"
        echo -e "$Cyan==========================================$Color_Off"
        cd /usr/src/asterisk/asterisk-16.30.1-vici
		apt-get install libuuid-devel libxml2-devel -y
        make clean M=$PWD
        make distclean M=$PWD
		contrib/scripts/install_prereq install
#        AST-16 --with-pjproject-bundled --with-jansson-bundled
		./configure --libdir=/usr/lib --with-gsm=internal --enable-opus --enable-srtp --with-ssl --enable-asteriskssl --with-pjproject-bundled --with-jansson-bundled
        #make menuselect
		make menuselect/menuselect menuselect-tree menuselect.makeopts
		#enable app_meetme
		menuselect/menuselect --enable app_meetme menuselect.makeopts
		#enable res_http_websocket
		menuselect/menuselect --enable res_http_websocket menuselect.makeopts
		#enable res_srtp
		menuselect/menuselect --enable res_srtp menuselect.makeopts
        make M=$PWD 
        make install M=$PWD
        make samples M=$PWD
		make config M=$PWD
        
        echo -e "$Cyan==========================================$Color_Off"
        echo -e "$Yellow Confirm DAHDI working  $Color_Off"
        echo -e "$Cyan==========================================$Color_Off"
        sleep 5s
        echo -e "$Green lsmod | grep dahdi $Color_Off"
        lsmod | grep dahdi
        
		#Added for dahdi driver load issue fix
		sudo modprobe dahdi modules
		sudo modprobe dahdi
        
		echo -e "$Green dahdi_genconf $Color_Off"
        sudo dahdi_genconf -vvvvvvvvvv
        echo -e "$Green dahdi_cfg -vvv $Color_Off"
        sudo dahdi_cfg -vvv
        echo -e "$Green dahdi_test -c 5 $Color_Off"
        sudo dahdi_test -c 5
		
		#Changes by Shyama for asterisk cli connection
		cd /usr/lib64
		cp ibasteriskpj.so* /usr/lib
		cp libasteriskssl.so* /usr/lib
		ldconfig
		
        echo -e "$Cyan==========================================$Color_Off"
        echo -e "$Yellow Sound Installation $Color_Off"
        echo -e "$Cyan==========================================$Color_Off"
		
		cd /usr/src/asterisk
		wget http://downloads.digium.com/pub/telephony/sounds/asterisk-core-sounds-en-ulaw-current.tar.gz
		wget http://downloads.digium.com/pub/telephony/sounds/asterisk-core-sounds-en-wav-current.tar.gz
		wget http://downloads.digium.com/pub/telephony/sounds/asterisk-core-sounds-en-gsm-current.tar.gz
		wget http://downloads.digium.com/pub/telephony/sounds/asterisk-extra-sounds-en-ulaw-current.tar.gz
		wget http://downloads.digium.com/pub/telephony/sounds/asterisk-extra-sounds-en-wav-current.tar.gz
		wget http://downloads.digium.com/pub/telephony/sounds/asterisk-extra-sounds-en-gsm-current.tar.gz
		wget http://downloads.asterisk.org/pub/telephony/sounds/asterisk-moh-opsound-gsm-current.tar.gz
		wget http://downloads.asterisk.org/pub/telephony/sounds/asterisk-moh-opsound-ulaw-current.tar.gz
		wget http://downloads.asterisk.org/pub/telephony/sounds/asterisk-moh-opsound-wav-current.tar.gz		
		
        cd /var/lib/asterisk/sounds
		tar -zxf /usr/src/asterisk-core-sounds-en-gsm-current.tar.gz
		tar -zxf /usr/src/asterisk-core-sounds-en-ulaw-current.tar.gz
		tar -zxf /usr/src/asterisk-core-sounds-en-wav-current.tar.gz
		tar -zxf /usr/src/asterisk-extra-sounds-en-gsm-current.tar.gz
		tar -zxf /usr/src/asterisk-extra-sounds-en-ulaw-current.tar.gz
		tar -zxf /usr/src/asterisk-extra-sounds-en-wav-current.tar.gz
		
        mkdir /var/lib/asterisk/mohmp3
        mkdir /var/lib/asterisk/quiet-mp3
        ln -s /var/lib/asterisk/mohmp3 /var/lib/asterisk/default
        
		cd /var/lib/asterisk/mohmp3
        tar -zxf /usr/src/asterisk-moh-opsound-gsm-current.tar.gz
		tar -zxf /usr/src/asterisk-moh-opsound-ulaw-current.tar.gz
		tar -zxf /usr/src/asterisk-moh-opsound-wav-current.tar.gz
        
		
		rm -f CHANGES*
        rm -f LICENSE*
        rm -f CREDITS*
		
        cd /var/lib/asterisk/moh
        rm -f CHANGES*
        rm -f LICENSE*
        rm -f CREDITS*
		
        cd /var/lib/asterisk/sounds
        rm -f CHANGES*
        rm -f LICENSE*
        rm -f CREDITS*
		
		sox ../mohmp3/macroform-cold_day.wav macroform-cold_day.wav vol 0.25
		sox ../mohmp3/macroform-cold_day.gsm macroform-cold_day.gsm vol 0.25
		sox -t ul -r 8000 -c 1 ../mohmp3/macroform-cold_day.ulaw -t ul macroform-cold_day.ulaw vol 0.25
		sox ../mohmp3/macroform-robot_dity.wav macroform-robot_dity.wav vol 0.25
		sox ../mohmp3/macroform-robot_dity.gsm macroform-robot_dity.gsm vol 0.25
		sox -t ul -r 8000 -c 1 ../mohmp3/macroform-robot_dity.ulaw -t ul macroform-robot_dity.ulaw vol 0.25
		sox ../mohmp3/macroform-the_simplicity.wav macroform-the_simplicity.wav vol 0.25
		sox ../mohmp3/macroform-the_simplicity.gsm macroform-the_simplicity.gsm vol 0.25
		sox -t ul -r 8000 -c 1 ../mohmp3/macroform-the_simplicity.ulaw -t ul macroform-the_simplicity.ulaw vol 0.25
		sox ../mohmp3/reno_project-system.wav reno_project-system.wav vol 0.25
		sox ../mohmp3/reno_project-system.gsm reno_project-system.gsm vol 0.25
		sox -t ul -r 8000 -c 1 ../mohmp3/reno_project-system.ulaw -t ul reno_project-system.ulaw vol 0.25
		sox ../mohmp3/manolo_camp-morning_coffee.wav manolo_camp-morning_coffee.wav vol 0.25
		sox ../mohmp3/manolo_camp-morning_coffee.gsm manolo_camp-morning_coffee.gsm vol 0.25
		sox -t ul -r 8000 -c 1 ../mohmp3/manolo_camp-morning_coffee.ulaw -t ul manolo_camp-morning_coffee.ulaw vol 0.25		
		
        systemctl start asterisk 
}

#Install G729 and G723 Codecs
install_codec()
{
        echo -e "$Cyan==========================================$Color_Off"
        echo -e "$Yellow G729,G723 Codec Installation  $Color_Off"
        echo -e "$Cyan==========================================$Color_Off"
        cd /usr/src/asterisk
        /bin/bash codec-install.sh
        asterisk -rx "core show translation"
}


#Configure rc.local
configure_rclocal ()
{
        echo -e "$Cyan==========================================$Color_Off"
        echo -e "$Yellow Configuring rc.local $Color_Off"
        echo -e "$Cyan==========================================$Color_Off"
		
		cd /usr/src/extra/
		wget -c http://dl.icallify.com/extra/rc-local.service
		wget -c http://dl.icallify.com/extra/rc.local
		
        cp -rf /usr/src/extra/rc-local.service /etc/systemd/system/rc-local.service
		
		if [[ $INSTALL_DB == "0" ]]; then
			sed -i "15"'s/^/#/' /usr/src/extra/rc.local
		fi

		if [[ $INSTALL_WEB == "0" ]]; then
			sed -i "18"'s/^/#/' /usr/src/extra/rc.local
		fi		
		
        cp -rf /usr/src/extra/rc.local /etc/rc.local
		
        chmod +x /etc/rc.local
        systemctl daemon-reload
        systemctl enable rc-local
		sleep 3
        systemctl start rc-local.service
		sleep 30
        systemctl disable asterisk
		sleep 3
}

#cron configuration
cron_install ()
{
        echo -e "$Cyan==========================================$Color_Off"
        echo -e "$Yellow Configure cronjobs $Color_Off"
        echo -e "$Cyan==========================================$Color_Off"

		cd /usr/src/extra
		wget -c http://dl.icallify.com/extra/vicidial_cron
		
        cp -rf /usr/src/extra/vicidial_cron /var/spool/cron/crontabs/root
        crontab /var/spool/cron/crontabs/root		
		
}

#SSL certificate installation
ssl_install ()
{
        echo -e "$Cyan==========================================$Color_Off"
        echo -e "$Yellow SSL Configuration $Color_Off"
        echo -e "$Cyan==========================================$Color_Off"

        mkdir /etc/ssl/icssl
        openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout /etc/ssl/icssl/icallify.key -out /etc/ssl/icssl/icallify.crt
        cp -rf /usr/src/ICALLIFY/install/icallify-ssl.conf /etc/apache2/sites-available/icallify-ssl.conf
        sed -i 's/^Listen 443.*/#Listen 443/g' /etc/apache2/sites-available/icallify-ssl.conf
        sudo a2enmod ssl
        sudo a2enmod rewrite
        sudo a2ensite icallify-ssl.conf
        sudo a2dissite 000-default.conf
        sed -i '172s/None/All/' /etc/apache2/apache2.conf
        sudo service apache2 restart
}

#Asterisk directories and permission configuration
asterisk_dirconf ()
{
        clear
        echo -e "$Cyan==========================================$Color_Off"
        echo -e "$Yellow Asterisk Directory configurations $Color_Off"
        echo -e "$Cyan==========================================$Color_Off"
        echo "Creating required directories..."


        mkdir -p /var/spool/asterisk/monitor
        mkdir -p /var/spool/asterisk/monitor/MIX
        mkdir -p /var/spool/asterisk/monitorDONE
        mkdir -p /var/spool/asterisk/monitorDONE/FTP
        mkdir -p /var/spool/asterisk/monitorDONE/FTP2
        mkdir -p /var/spool/asterisk/monitorDONE/GPG
        mkdir -p /var/spool/asterisk/monitorDONE/GSM
        mkdir -p /var/spool/asterisk/monitorDONE/GSW
        mkdir -p /var/spool/asterisk/monitorDONE/MP3
        mkdir -p /var/spool/asterisk/monitorDONE/OGG
        mkdir -p /var/spool/asterisk/monitorDONE/ORIG

        chmod 755 /etc/asterisk
        chmod -Rf 644 /etc/asterisk/*
        chmod -Rf 755 /var/lib/asterisk/agi-bin
        chmod -Rf 644 /var/lib/asterisk/sounds
        chmod -Rf 755 /var/spool/asterisk/monitor
        chmod -Rf 755 /var/spool/asterisk/monitorDONE

}


#Logrotaion configuration
logrotate_install ()
{
        echo -e "$Cyan==========================================$Color_Off"
        echo -e "$Yellow Log rotation configurations $Color_Off"
        echo -e "$Cyan==========================================$Color_Off"
        sed -i -e 's/daily/size 30M/g' /etc/logrotate.d/rsyslog
        sed -i -e 's/weekly/size 30M/g' /etc/logrotate.d/rsyslog
        sed -i -e 's/rotate 7/rotate 5/g' /etc/logrotate.d/rsyslog
        sed -i -e 's/weekly/size 30M/g' /etc/logrotate.d/fail2ban
        sed -i -e 's/weekly/size 30M/g' /etc/logrotate.d/monit
}

#Change default ports
dialer_conf ()
{
        echo -e "$Cyan==========================================$Color_Off"
        echo -e "$Yellow Dialer Configurations file normalization $Color_Off"
        echo -e "$Cyan==========================================$Color_Off"

		cd /usr/src/astguiclient/trunk
		perl install.pl
		
}

#Local Turn server installation
turnserver_install ()
{
        echo -e "$Cyan==========================================$Color_Off"
        echo -e "$Yellow Turnserver installation  $Color_Off"
        echo -e "$Cyan==========================================$Color_Off"
        apt-get -y update
        apt-get -y install coturn
        systemctl stop coturn
        sed -i 's/^#TURNSERVER_ENABLED=1 =>.*/TURNSERVER_ENABLED=1/g' /etc/default/coturn
        sed -i "s/replace-this-secret/$(openssl rand -hex 32)/" /etc/turnserver.conf
        sed -i 's/^#listening-port=3478=>.*/listening-port=3478/g' /etc/turnserver.conf
        sed -i 's/^#tls-listening-port=5349=>.*/tls-listening-port=5349/g' /etc/turnserver.conf
        sed -i 's/^#min-port=49152=>.*/min-port=49152/g' /etc/turnserver.conf
        sed -i 's/^#max-port=65535=>.*/max-port=65535/g' /etc/turnserver.conf
        sed -i 's/^#fingerprint=>.*/fingerprint/g' /etc/turnserver.conf
        sed -i 's/^#use-auth-secret=>.*/use-auth-secret/g' /etc/turnserver.conf
        sed -i 's/^#static-auth-secret=north=>.*/static-auth-secret=north/g' /etc/turnserver.conf

        echo "realm=${iCallify_HOST_DOMAIN_NAME}" >> /etc/turnserver.conf
        echo "total-quota=100" >> /etc/turnserver.conf
        echo "stale-nonce=600" >> /etc/turnserver.conf
        echo "cert=/etc/ssl/icssl/icallify.crt" >> /etc/turnserver.conf
        echo "pkey=/etc/ssl/icssl/icallify.key" >> /etc/turnserver.conf
        echo "user=admin:admin" >> /etc/turnserver.conf
        echo "realm=kurento.org" >> /etc/turnserver.conf
        echo "log-file=/var/log/turnserver/turnserver.log" >> /etc/turnserver.conf
        echo "simple-log" >> /etc/turnserver.conf
        echo "external-ip=${iCallify_IP}" >> /etc/turnserver.conf
        sed -i 's/stunaddr=stun.l.google.com:19302/stunaddr=turn:${iCallify_IP}:3478/g' /etc/asterisk/rtp.conf
		mkdir /var/log/turnserver
		touch turnserver.conf
	
        systemctl start coturn
}


#Removing Source and Other files
clean_installation ()
{
        apt-get -y autoremove
		clear
}

install_webserver ()
{
		install_php
#		ssl_install
}

install_dbserver ()
{
		if [ ! -f /var/run/mysqld/mysql.pid ]; then
			install_mariadb
			install_customsql
		fi
}

install_dialer ()
{
#		install_header
        if [[ $PERL != "1" ]]; then
			install_perl
        fi
	
		install_asterisk
		install_codec
#		turnserver_install
		asterisk_dirconf
		dialer_conf		
		cron_install
		configure_rclocal
}

#Calling all main function
start_installation ()
{       
        get_linux_distribution
		
		setport
        if [[ $REBOOT != "1" ]]; then
			install_prerequisties
        fi
        
		get_ipdomain
		
        get_sourcecode
		

		if [[ $INSTALL_WEB == "1" ]]; then
			install_webserver
			sleep 2	
		fi

		if [[ $INSTALL_DB == "1" ]]; then
			install_dbserver
			sleep 2	
		fi		

		if [[ $INSTALL_DIALER == "1" ]]; then
			install_dialer
			sleep 2	
		fi				

		if [[ "$INSTALL_DIALER" == "1" ]]  && [[ "$INSTALL_WEB" == "1" ]] &&  [[ "$INSTALL_DB" == "1" ]]; then
			/usr/share/astguiclient/ADMIN_update_server_ip.pl --auto --old-server_ip=10.10.10.15 --server_ip=$Server_IP
			/usr/share/astguiclient/ADMIN_area_code_populate.pl
		fi

        logrotate_install
		sleep 2
        
		clean_installation
		sleep 2
		
        
        

        clear
        echo "=========================================================================================="
        echo "=========================================================================================="
        echo "=========================================================================================="
        echo "==========                                                                      =========="
        echo "==========        Your Vicidial server is installed successfully.               =========="
        echo ""
        echo "                     Vicidial Portal:"
        echo "                     http://${Server_IP}/vicidial/admin.php"
        echo ""
        echo "                     Vicidial Admin Username:"
        echo "                     6666"
        echo ""
        echo "                     Vicidial Admin Password:"
        echo "                     1234"
        echo ""
        echo "==========                                                                      =========="
        echo "==========        Please reboot your server once for seamless experience.       =========="
        echo "=========================================================================================="
        echo "=========================================================================================="
		exit 1
}
start_installation
