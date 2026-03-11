## 外部パケットフィルターは可能な限り全閉じでOS再インストール
## VPSのクラウドシェルでログイン

## 真っ先にiptables入れて応急措置(sshでは-Pは最後に）
apt install -y iptables

sudo iptables -A INPUT -i lo -j ACCEPT    ## 例外設定
sudo iptables -A INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT
sudo iptables -A INPUT -s <自分のグローバルIP> -p tcp --dport 22 -j ACCEPT   ## lightsailの場合。一時的に許可。
sudo iptables -A OUTPUT -o lo,tailscale0 -j ACCEPT
sudo iptables -A OUTPUT -m state --state RELATED,ESTABLISHED -j ACCEPT
sudo iptables -A OUTPUT -p tcp -m state --state NEW --dport 80 -j ACCEPT
sudo iptables -A OUTPUT -p tcp -m state --state NEW --dport 443 -j ACCEPT
sudo iptables -A OUTPUT -p udp -m state --state NEW --dport 53 -j ACCEPT

for chain in INPUT FORWARD OUTPUT; do sudo ip6tables -P $chain DROP; done   ## ipv6は一時的に全無効化（後のスクリプトでは使用可能とする）

for chain in INPUT FORWARD OUTPUT; do sudo iptables -P $chain DROP; done  ## ipv4。クラウドシェル接続であればロックアウトはされない。

sudo apt update; sudo apt -y full-upgrade      ## 初回アップグレード

curl -fsSL https://tailscale.com/install.sh | sh　　## さくらのVPSではクラウドシェル上でtailscale入れてしまう。ssh設定のため。

sudo tailscale up			## 同上

sudo apt install ssh　　## sshの初期セットアップ
mkdir -p ~/.ssh      　　#　最初はsshディレクトリないため作成
echo "termuxのssh-keygenで生成したid*.pubの中身" >> ~/.ssh/authorized_keys    ##　公開鍵コピー

sudo vim /etc/ssh/sshd_config　　##　すぐにパスワードログインを禁止+Tailscale IPでのみListen
```
ListenAddress ${サーバー自身のtailscale ip}
PermitRootLogin no
PasswordAuthentication no
PermitEmptyPasswords no
```

sudo systemctl restart ssh  
exit        ## ここまできたらクラウドシェルを閉じてよい。これからはtermuxでssh ubuntu@nextcloudとしてログインして作業。

### ここからSSH via tailscaleでTermuxから接続。

sudo passwd ubuntu    ## さくらの初期設定で不可能だったパスを強力に変更（bitwardenで128桁、数字9、記号9で生成して設定日時とともに保存、コンソールにコピペ）

# 永続化のためにスクリプトとサービス作成 
sudo apt install vim
sudo vim /usr/local/bin/customfw.sh
```
#!/usr/bin/env bash

NOWSTATE=$(iptables -nvL | grep "Chain INPUT" | awk '{print $4}')
TODAY=$(date +%Y/%m/%d_%H%M%S)

set_custom_rules() {
        for ipvx in iptables ip6tables; do
                ## default policy
                ${ipvx} -P INPUT DROP
                ${ipvx} -P FORWARD DROP
                ${ipvx} -P OUTPUT DROP

                ## input
                ${ipvx} -A INPUT -i lo -j ACCEPT
                ${ipvx} -A INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT

                ## output
                ${ipvx} -A OUTPUT -o lo -j ACCEPT
                ${ipvx} -A OUTPUT -o tailscale0 -j ACCEPT
                ${ipvx} -A OUTPUT -m state --state RELATED,ESTABLISHED -j ACCEPT
                ${ipvx} -A OUTPUT -p tcp -m state --state NEW --dport 80 -j ACCEPT
                ${ipvx} -A OUTPUT -p tcp -m state --state NEW --dport 443 -j ACCEPT
                ${ipvx} -A OUTPUT -p udp -m state --state NEW --dport 53 -j ACCEPT
        done
}

mkdir -p /var/log/myscripts
chmod 700 /var/log/myscripts

if [ ${NOWSTATE} = "ACCEPT" ]; then
        set_custom_rules
        echo "${TODAY}: custom rules are applied successfully." >> /var/log/myscripts/customfw.log
else
        echo "${TODAY}: custom rules are already applied." >> /var/log/myscripts/customfw.log
fi
```

sudo chown root: /usr/local/bin/customfw.sh
sudo chmod 700 /usr/local/bin/customfw.sh

sudo vim /etc/systemd/system/customfw.service	# 永続化のためのsystemdサービスを作成、有効化
```
[Unit]
After=tailscaled.service

[Service]
ExecStart=/usr/local/bin/customfw.sh

[Install]
WantedBy=multi-user.target
```

sudo systemctl enable customfw
sudo reboot

sudo iptables -nvL; sudo ip6tables -nvL    ## 再起動後に反映を確認する

 ## 自動アップデート設定
sudo vim /usr/local/bin/sysupd.sh
```
#!/usr/bin/env bash
set -eu -o pipefail

apt update
apt -y upgrade
apt -y upgrade $(apt list --upgradable 2>/dev/null | grep -e / | awk '{print $1}' | xargs)
apt -y autoremove
echo "$(date): Update successful." >> /var/log/myscirpts/sysupd.log
systemctl reboot
```

sudo chmod 700 /usr/local/bin/sysupd.sh

sudo apt install cron
sudo systemctl enable cron
sudo systemctl start cron
sudo crontab -e
```  
0 18 * * * /usr/local/bin/sysupd.sh	## UTCで午前3時
```
## ウイルスチェックする場合
sudo apt install clamav
sudo rm /var/log/clamav/freshclam.log
sudo freshclam
sudo clamscan -r / -l scan.log
sudo su
cat scan.log | grep FOUND

sudo apt install rkhunter
sudo rkhunter --propupd
sudo rkhunter --check -sk
sudo su
cat /var/log/rkhunter.log | grep Warning 

### ここからWebサーバー構築開始
### 証明書の取得。カレントディレクトリに保存される。”https://”は不要。
sudo tailscale cert nextcloud.tailXXXXX.ts.net

### root以外読めない/書けないように権限変更する
sudo chmod 600 nextcloud.tailXXXXX.ts.net.crt
sudo chmod 600 nextcloud.tailXXXXX.ts.net.key

### 証明書を/usr/local/tscertに配置する
sudo mkdir -p /usr/local/tscert
sudo mv ~/nextcloud.tailXXXXX.ts.net.* /usr/local/tscert

### /usr/local/binのディレクトリ自体をroot以外は読めないようにする
sudo chown -R root: /usr/local/tscert
sudo chmod 700 /usr/local/tscert

### apacheインストール、サービス起動
sudo apt install apache2
sudo systemctl enable apache2
sudo systemctl start apache2

### SSLモジュールを有効化
sudo a2enmod ssl

### SSL有効にし、取得して配置したSSL証明書を指定
sudo nano /etc/apache2/sites-available/default-ssl.conf
...
SSLEngine on
...
SSLCertificateFile      /usr/local/tscert/nextcloud.tailXXXXX.ts.net.crt
SSLCertificateKeyFile   /usr/local/tscert/nextcloud.tailXXXXX.ts.net.key
...
EOF

### SSL常時リダイレクト＋接続をクライアントのtailnetのローカルIPからのみ許可
sudo nano /etc/apache2/sites-available/000-default.conf
...
ServerName https://nextcloud.tailXXXXX.ts.net:80
...
Redirect permanent / https://nextcloud.tailXXXXX.ts.net

<Directory /var/www/html>
     Require ip ${tailnet-client-phone-ip}
     Require ip ${tailnet-client-pc-ip}
</Directory>
...
EOF

### tailnetのipからのみ待ち受け、グローバルIPからのアクセスを拒否
sudo nano /etc/apache2/ports.conf
...
Listen ${tailnet-server-ip}:80
Listen ${tailnet-server-ip}:443
...
EOF

### 念のため404ページでサーバー情報を非表示
sudo vim /etc/apache2/conf-available/security.conf
ServerTokens Prod
ServerSignature Off
...
EOF

### 上記設定を反映する
sudo s2dissite 000-default
sudo s2ensite 000-default
sudo a2ensite default-ssl
sudo a2disconf security
sudo a2enconf security
sudo systemctl reload apache2
sudo systemctl restart apache2 

## クライアントのブラウザからテストページが表示されるか(SSL含め)動作確認
(firefox on client) https://nextcloud.tailXXXXX.ts.net ## 接続成功する。It works!ページが表示される
(firefox on client) https://nextcloud.tailXXXXX.ts.net/hoge  ## 接続成功するが、Not Found The requested URL was not found on this server.とだけ表示され、ほかの情報が出ないのを確認する
(firefox on client) ${サーバーのIPv4アドレス or IPv6アドレス}   ## 接続がタイムアウトしページが表示されないことを確認する
(firefox on client) ${VPS業者が割り当てたデフォルトドメイン}   ## 接続がタイムアウトしページが表示されないことを確認する


### apacheがtailscaleより先に立ち上がって自身のipを見失う問題の対策
### apacheが起動失敗した場合はいつでも再起動を試行させる
sudo systemctl edit apache2
[Service]
Restart=always

### apache2.serviceが再起動を試行する場合、失敗時から1秒おきに100回まで試行させる（参考: https://tex2e.github.io/blog/linux/systemd-restart-config）
sudo nano /etc/systemd/system.conf
DefaultStartLimitIntervalSec=1s
DefaultStartLimitBurst=100

### PHP環境、MariaDB、redis、curl、unzipのインストール
### Ubuntu, Debianの場合
sudo apt -y install php php-fpm php-opcache php-gd php-mysql php-mariadb-mysql-kbs php-pear php-apcu php-mbstring php-curl \
  php-gmp php-common php-xml php-zip php-imap php-json php-intl php-bcmath php-imagick \
  libmagickcore-6.q16-6-extra mariadb-server redis-server php-redis curl unzip

### fpm,mariadb,redisの開始、自動起動設定
sudo systemctl enable php8.3-fpm mariadb redis-server
sudo systemctl start php8.3-fpm mariadb redis-server

### Nextcloud本体のダウンロード、ドキュメントルートへの配置、オーナー設定
cd /var/www
sudo curl -O https://download.nextcloud.com/server/releases/latest.zip
sudo unzip latest.zip
sudo rm -rf ./html
sudo mv ./nextcloud ./html
sudo chown -R www-data:www-data /var/www/html

### MariaDBの初回セットアップ
sudo mysql_secure_installation
ROOT PASS: set password
Switch to unix_socket authentication: no
Change root password: no
Remove anonymous users: yes
Disallow root login remotely: yes
Remove test database and access to it: yes
Reload privilege tables now: yes

### MariaDBのrootでログインしDB作成
sudo mariadb -u root -p
CREATE DATABASE nextcloud_db;
CREATE USER nextclouduser@localhost IDENTIFIED BY 'StrongPassword';
GRANT ALL PRIVILEGES ON nextcloud_db.* TO nextclouduser@localhost;
FLUSH PRIVILEGES;
quit;

sudo pro attach <tokens>

----------------------------------------------------------------------
### 管理画面で出るエラーをつぶす
sudo a2enmod headers
sudo a2enmod rewrite

sudo nano /etc/apache2/sites-available/nextcloud.conf
<Directory /var/www/html>
        Require all granted
        AllowOverride All      ## .htaccess有効化のため
        Options FollowSymlinks MultiViews
        <IfModule mod_dav.c>
                Dav off
        </IfModule>
        <IfModule mod_headers.c>
                Header always set Strict-Transport-Security "max-age=15552000; includeSubDomains"
        </IfModule>
</Directory>

<Directory /var/www/html/data>
        Require all denied
</Directory>
EOF

sudo a2ensite nextcloud
sudo systemctl restart apache2

--------‐--------------------------------------------------------------
### PHPメモリ量エラー
sudo a2enmod proxy_fcgi setenvif
sudo a2enconf php8.X-fpm　## fpmの設定有効化を忘れずに行う
sudo nano /etc/php/8.X/fpm/php.ini
memory_limit = 1024M

sudo systemctl restart php8.3-fpm apache2

----------------------------------------------------------------------
### OCC実行関連エラー（apcu絡み）
### apcuを/etc/php/8.3/cli/php.iniで有効にしない場合は、--defineオプションでapc.enable_cli=1を明示的に指定・定義（--define）する

sudo -u www-data php --define apc.enable_cli=1 /var/www/html/occ maintenance:repair --include-expensive
sudo -u www-data php --define apc.enable_cli=1 /var/www/html/occ db:add-missing-indices

### cli上でのapcuを恒久的に有効化する場合
sudo nano /etc/php/8.3/cli/php.ini
apc.enable_cli=1
EOF
----------------------------------------------------------------------
### 「メモリキャッシュが設定されていません」エラー
### nextcloud（Web）上でapcuを有効化する
sudo -u www-data nano /var/www/html/config/config.php
...
'memcache.local' => '\\OC\\Memcache\\APCu',
'filelocking.enabled' => true,
...
sudo systemctl restart apache2

‐---‐------------------------------------------------------------------
### OpCache最適化
sudo nano /etc/php/8.3/fpm/php.ini
opcache.enable=1
opcache.enable_cli=1
opcache.memory_consumption=256    
opcache.interned_strings_buffer=32   ## デフォルトは8
opcache.max_accelerated_files=10000
opcache.revalidate_freq=100      ## 0だとcryptomatorの暗号化処理が間に合わず同期エラーとなる
opcache.save_comments=1
...
EOF

sudo a2dismod php8.2 mpm_prefork               ## opcacheを確実に使用させる
sudo a2enmod proxy_fcgi setenvif mpm_event
sudo a2enconf php8.2-fpm

sudo systemctl retart apache2 php8.3-fpm

------------------------------------------------------------------------
### redis関連エラー
### "The database is used for transactional file locking"エラー
sudo nano /etc/redis/redis.conf
...
unixsocket /var/run/redis/redis.sock
unixsocketperm 770
...

sudo systemctl restart redis-server

sudo usermod -aG redis www-data

sudo -u www-data nano /var/www/html/config/config.php
...
'memcache.locking' => '\OC\Memcache\Redis',
'redis' => array(
     'host' => '/var/run/redis/redis.sock',
     'port' => 0,
     'timeout' => 0.0,
      ),
...

sudo systemctl restart apache2
-------------‐---------------------------------------------------------
### メンテナンス関連エラー
sudo -u www-data nano /var/www/html/config/config.php
'maintenance_window_start' => 3,

------------------------------------------------------------------------
### リダイレクトエラー
sudo -u www-data nano /var/www/html/.htaccess

<IfModule mod_rewrite.c>
  RewriteEngine on
  RewriteCond %{HTTP_USER_AGENT} DavClnt
+  RewriteRule ^$ https://example.com/remote.php/webdav/ [L,R=302]
  RewriteRule .* - [env=HTTP_AUTHORIZATION:%{HTTP:Authorization}]
+  RewriteRule ^\.well-known/carddav https://example.com/remote.php/dav/ [R=301,L]
+  RewriteRule ^\.well-known/caldav https://example.com/remote.php/dav/ [R=301,L]
  RewriteRule ^remote/(.*) remote.php [QSA,L]
  RewriteRule ^(?:build|tests|config|lib|3rdparty|templates)/.* - [R=404,L]
  RewriteRule ^\.well-known/(?!acme-challenge|pki-validation) /index.php [QSA,L]
  RewriteRule ^ocm-provider/(.*) index.php [QSA,L]
  RewriteRule ^(?:\.(?!well-known)|autotest|occ|issue|indie|db_|console).* - [R=404,L]
</IfModule>

-----------------------------------‐-------------------------------
### 電話リージョンエラー
sudo -u www-data nano /var/www/html/config/config.php
'default_phone_region' => 'JP',

-------------------------------------------------------------------
### Email未設定のエラー

### Gmailを使用する場合の操作
### 暗号化はnone/starttls
### ポート番号は587
### アプリパスワード生成はhttps://support.google.com/accounts/answer/185833?hl=jaから。
### https://arimasou16.com/blog/2022/06/08/00463/参照。

Account menu => Personal Settings => Set "Email"
Account Menu => Administration Settings => Basic Settings => Email Server
Send Mode = SMTP
Encryption = None/STARTTLS
From Address = example@gmail.com
Server Address = smtp.gmail.com:587
Authentication = check "Authentication required"
Credentials = example@gmail.com, APP PASSWORD

### Zoho Mailを使用する場合
### 参考：https://www.zoho.com/jp/mail/help/zoho-smtp.html#alink1

送信モード：SMTP
暗号化：SSL
送信元アドレス：my-address @ zohomail.jp
サーバーアドレス：smtp.zoho.jp : 465
認証：必要
資格情報：my-address@zohomail.jp / ログインパスワード

----‐------------------------------------------------------------------

### cron エラーの抑止
### https://freefielder.jp/blog/2021/07/nextcloud-bg-job-by-cron.html

sudo crontab -u www-data -e
*/5 * * * * /usr/bin/php /var/www/html/cron.php
↓
sudo nano /etc/php/8.3/cli/php.ini
apc.enable_cli=1
EOF
↓
sudo systemctl enable cron
sudo systemctl start cron
sudo systemctl restart php8.3-fpm apache2 cron
↓
「基本設定」→「バックグラウンドジョブ」で「Cron（推奨）」を選択する

--------------------------------------------------------------------
### 2FA有効化

### OS自動アップデート、SSL証明書自動更新設定しておく
### OCIではUTCのためJST午前4時は18:00となる
sudo crontab -e
0 18 * * * /usr/local/bin/sslupd.sh; /usr/local/bin/nextcloudupd.sh; /usr/local/bin/sysupd.sh

sudo vim /usr/local/bin/sysupd.sh
```
#!/usr/bin/env bash
set -eu -o pipefail
## system
apt update
apt -y upgrade
apt -y upgrade $(apt list --upgradable 2>/dev/null | grep -e / | awk '{print $1}' | xargs)
apt -y autoremove
echo "$(date): Update completed." >> /var/log/myscripts/sysupd.log
systemctl reboot
```

sudo vim /usr/local/bin/ncupd.sh
```
#!/usr/bin env bash
set -eu -o pipefail
## nextcloud
sudo -u www-data php /var/www/html/occ maintenance:mode --on
sudo -u www-data php /var/www/html/updater/updater.phar --no-interaction
sudo -u www-data php /var/www/html/occ maintenance:mode --off
sudo -u www-data php /var/www/html/occ maintenance:repair --include-expensive
sudo -u www-data php /var/www/html/occ db:add-missing-indices
```

sudo vim /usr/local/bin/sslupd.sh
```
#!/usr/bin/env bash
set -eu -o pipefail
cd /usr/local/tscert
tailscale cert nextcloud.tailce2dc.ts.net
systemctl restart apache2
```

### irqbalance
sudo apt install irqbalance
sudo systemctl enable irqbalance
sudo systemctl start irqbalance

### ログファイル出力を/var/logへ変更
### 参考：https://nextcloud.stylez.co.jp/blog/techblog/occ_details_log.html
sudo -u www-data /var/www/html/occ log:file --file=/var/log/nextcloud.log
sudo chmod -R 700 /var/log

-------------------------------------------------------------------------------------------------
## 大容量ファイルへの対応
sudo vim /etc/apache2/apache2.conf    ## apacheでのタイムアウト時間の緩和
```
Timeout 214783647
```
sudo systemctl restart apache2

sudo vim /etc/php/8.3/fpm/php.ini　　## PHPでのタイムアウト時間無効化、メモリ制限緩和
```
max_execution_time = -1
max_input_time = -1
memory_limit = 1500M   ## 実装RAM量との兼ね合い。2gbなvpsの場合
post_max_size = 1400M
upload_max_filesize = 1400M
```

sudo systemctl restart php8.3-fpm apache2

-----------------------------------------------------------------------------------------------

sudo -u www-data php /var/www/html/occ setupchecks

###　参照
https://docs.nextcloud.com/server/latest/admin_manual/installation/php_configuration.html
https://www.howtoforge.com/step-by-step-installing-nextcloud-on-debian-12/
http://memorandum.cloud/2023/01/23/1858/
https://zenn.dev/seiwell/articles/019849a67ccbb6
https://www.kagoya.jp/howto/cloud/vps/nextcloud/
https://help.nextcloud.com/t/how-to-enable-svg-for-php-imagick/108646/4
https://help.nextcloud.com/t/the-php-opcache-module-is-not-properly-configured/135870/2
https://stackoverflow.com/questions/11719495/php-warning-post-content-length-of-8978294-bytes-exceeds-the-limit-of-8388608-b
