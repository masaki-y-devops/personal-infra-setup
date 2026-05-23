経緯
===
趣味で見ているニュースサイトやニコニコ動画の新規投稿通知を、登録数無制限で受けるために構築した。

選定理由
======
Tiny Tiny RSSと迷ったが、より若いプロジェクトであり、どのような使い勝手なのかを試したくて選択。

LAMP環境は使い慣れたUbuntuベースで構築。RHELベースでも慣れておく必要はあると認識。

Webサーバーは、FreshRSSがPHPアプリケーションのため、nginxと比べ、動的コンテンツ処理に強いといわれるApacheを選択。

さくらのVPS、AWS Lightsail、OCI Always Free Tier各サービス上で構築を確認。

単独運用（Webサーバー、DBサーバーをそれぞれ1セット格納するだけ）であれば、最安の最低スペックプランで不満なく動作する。

設定の内容
=======

### 事前準備
- VPS/インスタンスを作成直後からできるだけ外部ネットワークに晒さないように、事前のパケットフィルター設定を行う。
- 22は家のみ許可し、暫定作業を行った。

### VM作成
- Ubuntu Server 22.04 or 24.04 で動作確認した。x86_64。
- システムストレージ容量は単一運用であれば、50GBもあれば十分であった。
- 操作しているSSHクライアントの公開鍵アップロードを行う。

### SSHからログイン
- まずアップデートする。

~~~
sudo apt update
sudo apt -y upgrade
~~~

### tailscaleセットアップ、サービス開始。

~~~
sudo apt install curl
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up          ## webから参加許可する
~~~

### SSL証明書の取得。カレントディレクトリに保存される。

- **certオプションの引数につき、”https://”付加は不要だった。**
- **何回か実行エラーを繰り返して気づいた。意外な？盲点。**

~~~
sudo tailscale cert freshrss.tailce2dc.ts.net
~~~

### root以外読めないように権限変更する

- 証明書ファイルのため、権限管理を厳格に。

~~~
sudo chmod 600 ${tailnet-url}.crt
sudo chmod 600 ${tailnet-url}.key
~~~

### 証明書を/usr/local/tscertに配置しておく（フォルダ名はtscertでなくても問題ないが、わかりやすい名前で。）

~~~
sudo mkdir -p /usr/local/tscert
sudo mv ./${tailnet-url}.* /usr/local/tscert
~~~

### /usr/local/bin自体root以外で読めないようにする

- 証明書ファイルの格納フォルダも権限を制限・調整しておく。

~~~
sudo chmod 700 /usr/local/tscert
~~~

### apacheインストール、サービス起動

nginxでも構成可能と思うが、未挑戦。今後の課題。

apacheのほうが動的コンテンツ処理に強いという情報を得たため、選定。

~~~
sudo apt install apache2
sudo systemctl enable apache2
sudo systemctl start apache2
~~~

### SSLモジュールを有効化

tailscaleのMagicDNS機能では、SSL証明書の発行が可能なので利用する。

ブラウザの「安全でない接続」の警告を消すのがねらい。

~~~
sudo a2enmod ssl
~~~

### SSL有効にし、取得して配置したSSL証明書を指定

~~~
sudo nano /etc/apache2/sites-available/default-ssl.conf

<VirtualHost *.443>
...
SSLEngine on
...
SSLCertificateFile      /usr/local/tscert/${tailnet-server-url}.crt
SSLCertificateKeyFile   /usr/local/tscert/${tailnet-server-url}.key
...
EOF
~~~

### SSL常時リダイレクト＋接続をクライアントのtailnetのローカルIPからのみ許可

Apache上でもtailscale経由での接続のみ受け付ける。

~~~
sudo nano /etc/apache2/sites-available/000-default.conf

...
ServerName https://${tailnet-server-url}
...
Redirect permanent / https://${tailnet-server-url}
...
EOF
~~~

### tailnetのIPからのみ待ち受け、グローバルIPからのアクセスを拒否

プライベート運用なのでセキュリティ上、必須と考えた。

~~~
sudo nano /etc/apache2/ports.conf

...
Listen ${tailnet-server-ip}:80
Listen ${tailnet-server-ip}:443
...
EOF
~~~

### サーバーバージョン情報非表示など

自分しかURLが見えず（有効ではなく）任意だが、念のため設定。

~~~
sudo nano /etc/apache2/conf-available/security.conf

...
ServerTokens Prod
ServerSignature Off
...
~~~

### 上記設定を反映する

~~~
sudo s2dissite 000-default
sudo s2ensite 000-default
sudo a2ensite default-ssl
sudo a2disconf security
sudo a2enconf security
sudo systemctl reload apache2
sudo systemctl restart apache2  ## ここまで終わったらクライアントのブラウザからテストページが表示されるか動作確認する
~~~

### apacheがtailscaleより先に立ち上がって自身のipを見失う問題の対策

稼働させた状態で夜間にOSアップデートのcronジョブを実行させていたが、朝になって確認するとサービスが落ちていたため対策。

~~~
sudo systemctl status apache2
~~~

でWebサーバーの起動状態を見ると、```Failed```の状態を確認。

原因は、設定で指定したIPがtailscaleによって割り当てられるものであるため、tailscaleのサービスが起動する前にapacheが起動すると、「指定したIPがない」としてエラー終了していた。

そのため、apacheが起動失敗した場合はいつでも（この場合はtailscaleが起動完了するまで）再起動を試行させる。

~~~
sudo systemctl edit apache2

[Service]
Restart=always
~~~

#### systemdが再起動を試行する場合、1秒おきに20回まで試行させる

試行錯誤したところ、このsystemdのグローバルな設定も必要だった。

上記だけ（特に```DefaultStartLimitBurst```を初期値のままにする場合）では、apache2.serviceがtailscaled起動完了まで待ってくれず、起動をあきらめてしまう。

https://tex2e.github.io/blog/linux/systemd-restart-configも参照

~~~
sudo nano /etc/systemd/system.conf

DefaultStartLimitIntervalSec=1s
DefaultStartLimitBurst=20
~~~

### PHP環境のインストール

~~~
sudo apt install php php-curl php-dom php-json php-ctype php-mysql php-mbstring php-zip curl unzip
~~~

### FreshRSSの実行ファイルを/usr/share/freshrssに配置

~~~
cd ~
curl -o latest.zip -L https://github.com/FreshRSS/FreshRSS/zipball/edge
unzip latest.zip
mv ~/FreshRSS-FreshRSS-f6d3c35 ~/freshrss
sudo mv ~/freshrss /usr/share/
~~~

### ファイルのオーナーをapache(www-data)にする

~~~
sudo chown -R www-data:www-data /usr/share/freshrss
~~~
 
freshrssフォルダの内容のread権限をwww-dataオーナーだけでなく、同グループにも付与。

**Web上のUIからアップデートを実行するためにはwriteも必要(```700```ではなく```770```とする)。**

**660ではNGだった。770でないと実行権限なくフォルダにアクセス不可となる。**

~~~
sudo chmod -R 770 /usr/share/freshrss
~~~

### freshrss/dataフォルダの内容のwrite,read権限をグループに付与

~~~
sudo chmod -R 770 /usr/share/freshrss/data
~~~

### /usr/share/freshrss/p**のみ**をwebに公開

FreshRSS公式からもセキュリティ確保の観点から推奨されている。

~~~
sudo rm -rf /var/www/html
sudo ln -s /usr/share/freshrss/p /var/www/html
~~~

### /var/www/htmlのオーナーをwww-dataに変更

~~~
sudo chown -R www-data:www-data /var/www/html
~~~

### MariaDBセットアップ

~~~
sudo apt install mariadb-server
sudo systemctl enable mariadb
sudo systemctl start mariadb
~~~

### とりあえず対話式でrootパスワード作成。

現段階では自動化考慮なし。要検討事項。

~~~
sudo mysql_secure_installation
~~~

### rootでDBにログイン

~~~
sudo mariadb -u root -p
~~~

### DB作成

~~~
CREATE DATABASE freshrss_db;
CREATE USER freshrssuser@localhost IDENTIFIED BY 'StrongPassword';
GRANT ALL PRIVILEGES ON freshrss_db.* TO freshrssuser@localhost;
FLUSH PRIVILEGES;
quit;
~~~

以降、クライアントからブラウザでhttps://${tailnet-server-url}にアクセスして初回セットアップをする。

### チェックしておきたいWebUI設定項目

~~~
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
~~~

### サーバー側で1分に一回フィードを更新を試行する

Webクライアントを開いたときに、「最新の状態に更新されていない？」と感じたのでcronジョブを追加した。

「1分に1回」は過剰に思えるときは、適宜調整する。

~~~
sudo crontab -e

*/1 * * * * sudo -u www-data php /usr/share/freshrss/app/actualize_script.php > /tmp/FreshRSS.log 2>&1
~~~

### クライアント側のＷebUI未操作時に自動ページ更新するアドオン（xExtension-AutoRefresh）

アドオン追加の流れ:

~~~
curl -OL https://github.com/Eisa01/FreshRSS---Auto-Refresh-Extension/archive/refs/heads/master.zip | unzip
sudo mv ./FreshRSS---Auto-Refresh-Extension-master/FreshRSS---Auto-Refresh-Extension-master/xExtension-AutoRefresh /usr/share/freshrss/extensions
sudo chown -R www-data:www-data /usr/share/freshrss/extensions
~~~

主に参照した公式サイト等
=================
便利に利用させていただいております。

この場を借りて御礼申し上げます。

https://freshrss.github.io/FreshRSS/en/admins/03_Installation.html

https://freshrss.github.io/FreshRSS/en/admins/08_FeedUpdates.html
