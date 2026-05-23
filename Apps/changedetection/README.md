## 作成経緯
お気に入りのアニメの更新や、趣味で読んでいるブログなどで、RSSに対応していないサイトがよくある。

RSS対応のサイトであれば、Feedlyや、セルフホストならFreshRSSという選択肢があるが、動的なサイトでRSSに対応しないサイトも増えてきた。

現在はホスティング費用がかかるのでDistill Web Monitorの無料プランに移行しているが、学習も兼ねてchangedetection.ioを構築していたときの記録を残しておく。

サイト側のポリシーでスクレイピングを禁止していたり、robots.txtで明示しているサイトを監視しないようにして、確認頻度についても、10分に一回など、節度ある利用を心掛けた。

## 構成要素と選定理由

- AWS Lightsail 2GBメモリ

→　Ubuntuインスタンスを選択可能なため選定。さくら（や、GMO社などの）VPS 2GBでも可能と思われる。OCI Always Free Tierはメモリが1GBなため厳しい可能性高い。

- Ubuntu Server 24.04

→　使い慣れているため選定。RedHat系離れていないが、パッケージマネージャーとApache関連のコマンドで違いが出るかもしれない。

- プリセットのLAMP環境セットは使わず、OSインストールのみからスタート

→　より基本的な操作を学ぶため、あえてプリセット環境を使わず。

- 元々のグローバルIPはLightsailの外部ファイアウォール、OS側iptablesで封鎖。Tailscaleを使用し、その割当IP（、ドメイン）で通信する。

→　プライベート用なので外部開放するのは必要性がなく、セキュリティー的に不正アクセスの足掛かりになりうるので気を付けた。
　　サーバーと同一のtailnetに自分のクライアント端末を参加させて利用する。ACLも設定する。

## 具体的な手順

(1) 下記を確認し、スタートアップスクリプトとして実行。

この際、初回は自宅のパブリックIPを確認、許可する必要がある。固定IPサービスを契約していない場合、IPの変更に注意する。

確認にはwhatismyip.comを使用した。

インスタンス初回起動時の無防備な時間を最小化するため、Lightsailや他のVPSでよくあるスタートアップスクリプト実行機能を使って、最低限のセキュリティ状態を確保する。

~~~
sudo iptables -A INPUT -i lo -j ACCEPT
sudo iptables -A INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT
sudo iptables -A INPUT -s <自宅IP> -p tcp --dport 22 -j ACCEPT
sudo iptables -A OUTPUT -o lo,tailscale0 -j ACCEPT
sudo iptables -A OUTPUT -m state --state RELATED,ESTABLISHED -j ACCEPT
sudo iptables -A OUTPUT -p tcp -m state --state NEW --dport 80 -j ACCEPT
sudo iptables -A OUTPUT -p tcp -m state --state NEW --dport 443 -j ACCEPT
sudo iptables -A OUTPUT -p udp -m state --state NEW --dport 53 -j ACCEPT

for chain in INPUT FORWARD; do sudo ip6tables -P $chain DROP; done
for chain in INPUT FORWARD; do sudo iptables -P $chain DROP; done

cat << 'CFW' | sudo tee /usr/local/bin/customfw.sh
#!/usr/bin/env bash

NOWSTATE=$(iptables -nvL | grep "Chain INPUT" | awk '{print $4}')
TODAY=$(date +%Y/%m/%d_%H%M%S)

set_custom_rules() {
        for ipvx in iptables ip6tables; do
                ## default policy
                ${ipvx} -P INPUT DROP
                ${ipvx} -P FORWARD DROP
                ${ipvx} -P OUTPUT ACCEPT   ## allow output for docker

                ## input
                ${ipvx} -A INPUT -i lo -j ACCEPT
                ${ipvx} -A INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT

                ## output
                ${ipvx} -A OUTPUT -o lo -j ACCEPT
                ${ipvx} -A OUTPUT -o tailscale0 -j ACCEPT

                ${ipvx} -A OUTPUT -m state --state RELATED,ESTABLISHED -j ACCEPT

                ${ipvx} -A OUTPUT -p tcp -m state --state NEW --dport 80 -j ACCEPT
                ${ipvx} -A OUTPUT -p tcp -m state --state NEW --dport 443 -j ACCEPT

                ${ipvx} -A OUTPUT -p tcp -m state --state NEW --dport 53 -j ACCEPT
                ${ipvx} -A OUTPUT -p udp -m state --state NEW --dport 53 -j ACCEPT
        done
}

mkdir -p /var/log/myscripts

if [ ${NOWSTATE} = "ACCEPT" ]; then
        set_custom_rules
        echo "${TODAY}: custom rules are applied successfully." >> /var/log/myscripts/customfw.log
else
        echo "${TODAY}: custom rules are already applied." >> /var/log/myscripts/customfw.log
fi
CFW

sudo chown -R root: /usr/local/bin
sudo chmod -R 700 /usr/local/bin

cat << 'SYSD' | sudo tee /etc/systemd/system/customfw.service
[Unit]
After=tailscaled.service

[Service]
ExecStart=/usr/local/bin/customfw.sh

[Install]
WantedBy=multi-user.target
SYSD

sudo systemctl enable customfw.service
~~~

(2) termuxからubuntu@public-ipとしてsshログイン

自分はどこでもsshでメンテナンスできるようにtermuxを使ったが、もちろん他のsshクライアントでも大丈夫と思われる。

(3) インスタンスにtailscaleをインストール

~~~
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up

## up実行後、Webコンソールで承認＋承認の有効期限無効化＋マシンネーム変更
## ACLを設定している場合は、ロックアウトを防ぐためACLタグをつけない
~~~

(4) いったんパブリックIPでのSSHセッションを「切断してから」、ACL tagを疎通可能なタグに設定する。

(5) ubuntu@cdio（さきほどtailscaleで設定したノード名）でssh接続しなおす

(6) SSHのListen Addressをtailscale割り当ての IPに変更する、”PermitRootLogin”などの各種オプションも、ついでにnoに書き換えておく。

(7) 再起動後、ubuntu@cdioではログインできるがubuntu@<パブリックIP>ではログインできないことを確認

(8) ubuntuにDocker一式を導入 https://qiita.com/taka777n/items/ea3a1b3a2802aabf3db2

~~~
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt update
sudo apt install docker-ce docker-ce-cli containerd.io -y
sudo usermod -aG docker ubuntu   ## 忘れがちなので注意。逆にしない。ubuntuをdockerグループに追加。
~~~



(9) ChangeDetection.ioの導入 https://github.com/dgtlmoon/changedetection.io

~~~
sudo apt -y install git
git clone https://github.com/dgtlmoon/changedetection.io.git
cd ./changedetection.io

nano ./docker-compose.yml
```
services:
    changedetection:
        image: ghcr.io/dgtlmoon/changedetection.io
        container_name: changedetection
        hostname: changedetection
        volumes:
            - changedetection-data:/datastore
        environment:                        ## コメントアウトする
             - PLAYWRIGHT_DRIVER_URL=ws://browser-sockpuppet-chrome:3000
        ports:
            - 127.0.0.1:5000:5000
        depends_on:
            browser-sockpuppet-chrome:
                condition: service_started

    browser-sockpuppet-chrome:
        hostname: browser-sockpuppet-chrome
        image: dgtlmoon/sockpuppetbrowser:latest
        cap_add:
            - SYS_ADMIN
        restart: unless-stopped
        environment:                                                                                                                                                                
            - SCREEN_WIDTH=1920
            - SCREEN_HEIGHT=1024
            - SCREEN_DEPTH=16
            - MAX_CONCURRENT_CHROME_PROCESSES=1　## メモリ不足のため編集した　デフォは10
        ports:                                              ## 新規追加した
            - 127.0.0.1:3000:3000                 ## 新規追加した

volumes:
    changedetection-data:
```

docker compose up -d  ## 起動

~~~




(10) ssl接続適用のためにapache2のリバースプロキシ経由でcdioに接続するための設定と、Apacheの各種調整をする

- SSL証明書の取得。カレントディレクトリに保存される。保存先として```/usr/local/tscert```を作成して配置している。```cert```オプションの引数において、”https://”は不要だった（ここで少し詰まった）。

~~~
mkdir ~/cert && cd ~/cert
sudo tailscale cert cdio.tailXXXXXX.ts.net　　## https://...は指定不要だった。
~~~

- 証明書ファイルにつき、root以外読めないように権限変更する

~~~
sudo chmod 600 cdio.tailXXXXXX.ts.net.crt
sudo chmod 600 cdio.tailXXXXXX.ts.net.key
~~~



- 証明書を/usr/local/binに配置する

~~~
sudo mkdir -p /usr/local/tscert
sudo mv ./cdio.tailXXXXXX.ts.net.* /usr/local/tscert
~~~

- /usr/local/tscert自体root以外で読めないようにする

~~~
sudo chmod 700 /usr/local/tscert
~~~

- apache2インストール

~~~
sudo apt install apache2
~~~

- 先にmodule有効化しておく。proxy関連とssl, rewrite, headers

~~~
sudo a2enmod ssl proxy proxy_http proxy_balancer rewrite headers
~~~

- 443。SSL有効にし、取得して配置したSSL証明書を指定＋リバースプロキシ設定

"ProxyPass","ProxyPassReverse"のURL指定でハマり、半日以上費やした。

末尾の"/"を付けないで稼働させたところ、サイトの表示が崩れたので、AIに尋ねてヒントを得ながらトラブルシューティングをした。

~~~
sudo nano /etc/apache2/sites-available/default-ssl.conf

<VirtualHost *.443>
    ...
    ProxyPreserveHost On
    ProxyPass / http://127.0.0.1:5000/ ## 末尾の"/"を付けないとURLが正しく渡されず名前解決でエラーとなるので注意
    ProxyPassReverse / http://127.0.0.1:5000/ ## 同上
    ...
    SSLEngine on
    ...
    SSLCertificateFile      /usr/local/tscert/cdio.tailXXXXXX.ts.net.crt
    SSLCertificateKeyFile   /usr/local/tscert/cdio.tailXXXXXX.ts.net.key
    ...
    <FilesMatch "\.(?:cgi|shtml|phtml|php)$">
        SSLOptions +StdEnvVars
    </FilesMatch>
    <Directory /usr/lib/cgi-bin>
        SSLOptions +StdEnvVars
    </Directory>
</VirtualHost>
~~~

- 80。SSL常時リダイレクトのみ設定。80ではリバースプロキシ設定はしない（httpsへのリダイレクトを優先させるため。）。

この点も自分で明示的にhttp://…とアドレス入力してアクセスしたときに発覚。

~~~
sudo nano /etc/apache2/sites-available/000-default.conf

<VirtualHost *.80>
    ServerName https://cdio.tailXXXXXX.ts.net

    Redirect permanent / https://cdio.tailXXXXXX.ts.net

    ServerAdmin webmaster@localhost
    DocumentRoot /var/www/html

    ErrorLog ... ##そのまま
    CustomLog ... ##そのまま
</VirtualHost>
~~~

- tailnetのIPからのみ待ち受け、グローバルIPからのアクセスを拒否する。

自分専用で使うことを念頭においた設定。

そもそもtailscaleのMagic DNS、アドレスは自分のtailnet内でしか機能しないが、フェイルセーフとしてApache側でもグローバルIP経由でのコンテンツの提供を拒否するのが得策と判断した。

~~~
sudo nano /etc/apache2/ports.conf


Listen ${tailnet-server-ip}:80
Listen ${tailnet-server-ip}:443
~~~

- ミドルウェアバージョン非表示等

~~~
sudo nano /etc/apache2/conf-available/security.conf

ServerTokens Prod
ServerSignature Off
~~~

- 上記設定を反映する

~~~
sudo a2dissite 000-default
sudo a2ensite 000-default
sudo a2ensite default-ssl
sudo a2disconf security
sudo a2enconf security
sudo systemctl reload apache2
sudo systemctl restart apache2
~~~

- ここまで終わったらクライアントのブラウザからテストページが表示されるか動作確認する

(11) apacheがtailscaleより先に立ち上がって自身のIPアドレスを見失う問題の対策をしておく。

構築初期に、深夜のアップデート後、朝起きてクライアントからアクセスすると、サービスが止まっているのを確認。

そこでSSH接続して```systemctl status apache2```したところ、起動失敗していることが確認できた。

その状態で手動で```sudo systemctl restart apache2```すると、サービスが復帰したため、 

```tailscale.service```が起動する前に```apache2.service```の起動が試行され、apacheにリッスンするように設定したIPがシステム上（tailscale起動まで一時的に）存在しないために起動失敗していたことが分かった。

そのため、apache2にtailscaleが起動するまで「諦めさせない」ようにした。

- apacheが起動失敗した場合は再起動を十分な回数試行させる。

~~~
sudo systemctl edit apache2

[Service]
Restart=always
~~~

- systemdが再起動を試行する場合、1秒おきに1000回まで試行させる。 https://tex2e.github.io/blog/linux/systemd-restart-config　が参考になった。

1000という数字に特段の意味はないが、「十分な時間的猶予がある回数」として設定した。

これで再起動時の起動エラーは起きなくなった。

~~~
sudo nano /etc/systemd/system.conf

DefaultStartLimitIntervalSec=1s
DefaultStartLimitBurst=1000
~~~

- 手元のクライアント端末で```https://cdio.tailXXXXXX.ts.net```にアクセスしてみる

(12) 各種自動アップデート設定

changedetection.io本体、tailscaleのSSL証明書、OSのアップデートのスケジュール。

~~~
sudo nano /usr/local/bin/cdioupd.sh

#!/usr/bin/env bash
cd /home/ubuntu/changedetection.io
sudo -u ubuntu docker compose pull && docker compose up -d
~~~

~~~
sudo chmod 700 /usr/local/bin/cdioupd.sh
~~~

~~~
sudo nano /usr/local/bin/tlsupd.sh

#!/usr/bin/env bash
cd /usr/local/tscert
tailscale cert cdio.tail232e40.ts.net
chmod 600 /usr/local/tscert/*
~~~

~~~
sudo chmod 700 /usr/local/bin/tlsupd.sh
~~~

~~~
sudo nano /usr/local/bin/sysupd.sh

#!/usr/bin/env bash
export DEBIAN_FRONTEND=noninteractive

for i in {1..5}; do
    apt update
    apt -y upgrade
    apt -y upgrade $(apt list --upgradable 2>/dev/null | grep -e / | awk '{print $1}' | xargs) && break
done

apt -y autoremove
systemctl reboot
~~~

~~~
sudo chmod 700 /usr/local/bin/sysupd.sh
~~~

```restartdocker.sh```は、しばしば自動巡回が停止しているときがあるため別途設定。

systemdサービスとしても登録して、起動時にも念のため```apache2.service```の後に実行されるように設定した。

~~~
sudo nano /usr/local/bin/restartdocker.sh

#!/usr/bin/env bash

systemctl restart docker
sudo -u ubuntu docker rm --force $(docker ps -aq)

cd /home/ubuntu/changedetection.io
sudo -u ubuntu docker compose up -d 2>&1 1>/dev/null
~~~

~~~
sudo chmod 700 /usr/local/bin/restartdocker.sh
~~~

~~~
sudo nano /etc/systemd/system/restartdocker.service

[Unit]
After=apache2.service

[Service]
ExecStart=/usr/local/bin/restartdocker.sh

[Install]
WantedBy=multi-user.target
~~~

~~~
sudo systemctl enable restartdocker.service
~~~

~~~
sudo crontab -e

0 18 * * * /usr/local/bin/tlsupd.sh; /usr/local/bin/cdioupd.sh; /usr/local/bin/sysupd.sh
*/45 * * * * /usr/local/bin/restartdocker.sh
~~~

- zram設定

多少メモリに余裕が出るか？と思い設定したが、任意。

~~~
sudo apt install systemd-zram-generator

sudo nano /etc/sysctl.d/local.conf

vm.swappiness = 180
vm.watermark_boost_factor = 0
vm.watermark_scale_factor = 125
vm.page-cluster = 0
~~~

~~~
sudo nano /etc/systemd/zram-generator.conf

[zram0]
zram-size = 4096
compression-algorithm = zstd
~~~

~~~
sudo reboot
~~~

(13) WebUIでの設定

各自お好みでOK。

~~~
- GROUPS
  デフォルトのものを削除
- SETTINGS
    - General
        - time between check -> 1 hour
      - random jitter seconds +- check -> 5 secconds
      - password
      - extract <title> from document and use as watch title -> checked
    - Notifications
        - Notifications URL list
        - Notification title ->cd.io - {{watch_title}}({{watch_url}})
        - Notification body -> (
                {{watch_title}} had a change.
                ---
                {{diff}}
            )
        - Fetching
            - Fetch Method -> Playwright
            - Wait seconds before extracting text -> 30
            - Number of fetch workers -> 1　　## 2GB RAM + ZRAM SWAP 1GB
        - UI Options
            - Open 'History' page in a new tab -> unchecked
~~~
