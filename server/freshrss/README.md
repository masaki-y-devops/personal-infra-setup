### 事前のパケットフィルター設定
22は家のみ許可

### VM作成
### Ubuntu 22.04 or 24.04 で動作確認した
### x86_64 CPU
### システムストレージ容量は任意
### 公開鍵アップロード

### SSHからログイン
### アップデートする
sudo apt update
sudo apt -y upgrade

### tailscaleセットアップ、サービス開始
sudo apt install curl
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up          ## webから参加許可する

## SSL証明書の取得。カレントディレクトリに保存される。
## ”https://”は不要
sudo tailscale cert freshrss.tailxxxxxx.ts.net

## root以外読めないように権限変更する
sudo chmod 600 ${tailnet-url}.crt
sudo chmod 600 ${tailnet-url}.key

## 証明書を/usr/local/binに配置する
sudo mkdir -p /usr/local/tscert
sudo mv ./${tailnet-url}.* /usr/local/tscert

##/usr/local/bin自体root以外で読めないようにする
sudo chmod 700 /usr/local/tscert

### apacheインストール、サービス起動
sudo apt install apache2
sudo systemctl enable apache2
sudo systemctl start apache2

## SSLモジュールを有効化
sudo a2enmod ssl

## SSL有効にし、取得して配置したSSL証明書を指定
sudo nano /etc/apache2/sites-available/default-ssl.conf
<VirtualHost *.443>
...
SSLEngine on
...
SSLCertificateFile      /usr/local/tscert/${tailnet-server-url}.crt
SSLCertificateKeyFile   /usr/local/tscert/${tailnet-server-url}.key
...
EOF

## SSL常時リダイレクト＋接続をクライアントのtailnetのローカルIPからのみ許可
sudo nano /etc/apache2/sites-available/000-default.conf
...
ServerName https://${tailnet-server-url}
...
Redirect permanent / https://${tailnet-server-url}
...
EOF

sudo nano /etc/apache2/ports.conf
## tailnetのipからのみ待ち受け、グローバルIPからのアクセスを拒否
...
Listen ${tailnet-server-ip}:80
Listen ${tailnet-server-ip}:443
...
EOF

sudo nano /etc/apache2/conf-available/security.conf
```
ServerTokens Prod
ServerSignature Off
```

### 上記設定を反映する
sudo s2dissite 000-default
sudo s2ensite 000-default
sudo a2ensite default-ssl
sudo a2disconf security
sudo a2enconf security
sudo systemctl reload apache2
sudo systemctl restart apache2  ## ここまで終わったらクライアントのブラウザからテストページが表示されるか動作確認する

### apacheがtailscaleより先に立ち上がって自身のipを見失う問題の対策
### apacheが起動失敗した場合はいつでも再起動を試行させる
sudo systemctl edit apache2
```
[Service]
Restart=always
```

### systemdが再起動を試行する場合、1秒おきに20回まで試行させる
### https://tex2e.github.io/blog/linux/systemd-restart-configを参照
sudo nano /etc/systemd/system.conf
DefaultStartLimitIntervalSec=1s
DefaultStartLimitBurst=20

### PHP環境のインストール
sudo apt install php php-curl php-dom php-json php-ctype php-mysql php-mbstring php-zip curl unzip

### FreshRSSの実行ファイルを/usr/share/freshrssに配置
cd ~
curl -o latest.zip -L https://github.com/FreshRSS/FreshRSS/zipball/edge
unzip latest.zip
mv ~/FreshRSS-FreshRSS-f6d3c35 ~/freshrss
sudo mv ~/freshrss /usr/share/

### ファイルのオーナーをapache(www-data)にする
sudo chown -R www-data:www-data /usr/share/freshrss

### freshrssフォルダの内容のread権限をwww-dataオーナーだけでなく、同グループにも付与。webからupdateするためにwriteも必要。
### 660ではNG、770でないと実行権限なくフォルダにアクセス不可。
sudo chmod -R 770 /usr/share/freshrss

### freshrss/dataフォルダの内容のwrite,read権限をグループに付与
sudo chmod -R 770 /usr/share/freshrss/data

### /usr/share/freshrss/pのみをwebに公開
sudo rm -rf /var/www/html
sudo ln -s /usr/share/freshrss/p /var/www/html

### /var/www/htmlのオーナーをwww-dataに変更
sudo chown -R www-data:www-data /var/www/html

### MariaDBセットアップ
sudo apt install mariadb-server
sudo systemctl enable mariadb
sudo systemctl start mariadb

### 対話式でrootパスワード作成
sudo mysql_secure_installation

### rootでDBにログイン
sudo mariadb -u root -p

### DB作成
CREATE DATABASE freshrss_db;
CREATE USER freshrssuser@localhost IDENTIFIED BY 'StrongPassword';
GRANT ALL PRIVILEGES ON freshrss_db.* TO freshrssuser@localhost;
FLUSH PRIVILEGES;
quit;

### クライアントからhttps://${tailnet-server-url}にアクセスして初回セットアップをする

### 設定
```
display
	region: asia/tokyo
	theme: origin-compact
	content width: narrow
	thumbnail: landscape
	article icons: top line: unread, star, summary, date of publications bottom line: none
	show the navigation buttons: disabled

Reading
	View
		default view: normal view
		articles to display: show unreads if any, all article otherwise
		number of articles per page: 500 #max values
		load more articles at the bottom of the page: enabled
		"mark all as read" button: big
		sort order: newest	first
		categories to unfold: all categories
	Left navigation: categories
		categories to unfold: all categories
			show all articles in favourites by default: enabled
			hide categories & feeds with no unread ...: disabled

Archiving
	Do not automatically refresh more often than: 20min. ## do not set it to 1wk
	purge policy: disable all

Extensions
	Auto Refresh: enabled

Privacy
	Retrieve extension list: disabled
```

### サーバー側で1分に一回フィードを更新を試行する
sudo crontab -e
*/1 * * * * sudo -u www-data php /usr/share/freshrss/app/actualize_script.php > /tmp/FreshRSS.log 2>&1

### クライアント側自動フィード更新Extension
### FreshRSS-AutoTTL
### xExtension-AutoRefresh
### フォルダを/usr/share/freshrss/extensionsに配置し、chown -Rする
### その後、Web上で有効化する

### xExtension-AutoRefresh    ## webUI未操作時に自動ページ更新
curl -OL https://github.com/Eisa01/FreshRSS---Auto-Refresh-Extension/archive/refs/heads/master.zip | unzip
sudo mv ./FreshRSS---Auto-Refresh-Extension-master/FreshRSS---Auto-Refresh-Extension-master/xExtension-AutoRefresh /usr/share/freshrss/extensions
sudo chown -R www-data:www-data /usr/share/freshrss/extensions

### FreshRSS-AutoTTL
### curl -OL https://github.com/mgnsk/FreshRSS-AutoTTL/archive/refs/tags/v0.5.8.zip | unzip
### sudo mv .FreshRSS-AutoTTL-0.5.8 /usr/share/freshrss/extensions
### sudo chown -R www-data:www-data/usr/share/freshrss/extensions


-----------------------------------------------------------------------------

### reference
https://freshrss.github.io/FreshRSS/en/admins/03_Installation.html
https://freshrss.github.io/FreshRSS/en/admins/08_FeedUpdates.html
