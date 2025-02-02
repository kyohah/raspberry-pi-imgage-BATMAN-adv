# frozen_string_literal: true

# 必要なパッケージのインストール
package 'batctl' do
  action :install
end

package 'dnsmasq' do
  action :install
end

package 'iptables-persistent' do
  action :install
end

# (必要に応じて) ブリッジを使わない場合は bridge-utils は不要です

# /home/pi/start-batman-adv.sh を作成（ゲートウェイ用スクリプト）
file '/home/pi/start-batman-adv.sh' do
  content <<~EOS
    #!/bin/bash
    # batman-adv interface to use
    sudo batctl if add wlan0
    sudo ifconfig bat0 mtu 1468
    # Tell batman-adv this is an internet gateway
    sudo batctl gw_mode server
    # Enable port forwarding
    sudo sysctl -w net.ipv4.ip_forward=1
    sudo iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
    sudo iptables -A FORWARD -i eth0 -o bat0 -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
    sudo iptables -A FORWARD -i bat0 -o eth0 -j ACCEPT
    # Activates batman-adv interfaces
    sudo ifconfig wlan0 up
    sudo ifconfig bat0 up
    sudo ifconfig bat0 192.168.199.1/24
  EOS
  owner 'root'
  group 'root'
  mode '0755'
end

# /etc/network/interfaces.d/wlan0 の作成（ワイヤレスインタフェース設定）
file '/etc/network/interfaces.d/wlan0' do
  content <<~EOS
    auto wlan0
    iface wlan0 inet manual
        wireless-channel 1
        wireless-essid call-code-mesh
        wireless-mode ad-hoc
  EOS
  owner 'root'
  group 'root'
  mode '0644'
end

# /etc/modules に "batman-adv" の記述を追加
ruby_block 'append batman-adv to /etc/modules' do
  block do
    file_path = '/etc/modules'
    line = 'batman-adv'
    if ::File.exist?(file_path)
      content = ::File.read(file_path)
      ::File.open(file_path, 'a') { |f| f.puts line } unless content.include?(line)
    else
      ::File.write(file_path, "#{line}\n")
    end
  end
  action :run
end

# /etc/dhcpcd.conf に "denyinterfaces wlan0" を追加（無線LAN管理を dhcpcd から除外）
ruby_block 'append denyinterfaces wlan0 to /etc/dhcpcd.conf' do
  block do
    file_path = '/etc/dhcpcd.conf'
    line = 'denyinterfaces wlan0'
    if ::File.exist?(file_path)
      content = ::File.read(file_path)
      ::File.open(file_path, 'a') { |f| f.puts line } unless content.include?(line)
    else
      ::File.write(file_path, "#{line}\n")
    end
  end
  action :run
end

# /etc/dnsmasq.conf に、bat0 用 DHCP 設定を追加
ruby_block 'append dnsmasq config for bat0 to /etc/dnsmasq.conf' do
  block do
    file_path = '/etc/dnsmasq.conf'
    config_lines = [
      'interface=bat0',
      'dhcp-range=192.168.199.2,192.168.199.99,255.255.255.0,12h'
    ]
    if ::File.exist?(file_path)
      content = ::File.read(file_path)
      config_lines.each do |line|
        ::File.open(file_path, 'a') { |f| f.puts line } unless content.include?(line)
      end
    else
      ::File.write(file_path, "#{config_lines.join("\n")}\n")
    end
  end
  action :run
end

# /etc/rc.local に起動時に start-batman-adv.sh を実行する設定を追加
ruby_block 'insert start-batman-adv.sh call in /etc/rc.local' do
  block do
    file_path = '/etc/rc.local'
    script_call = '/home/pi/start-batman-adv.sh &'
    if ::File.exist?(file_path)
      content = ::File.read(file_path)
      unless content.include?(script_call)
        # "exit 0" の直前にスクリプト呼び出し行を挿入
        new_content = content.sub(/^exit 0/, "#{script_call}\nexit 0")
        ::File.write(file_path, new_content)
      end
    else
      # /etc/rc.local が無い場合は新規作成
      rc_local = <<~EOS
        #!/bin/sh -e
        #{script_call}
        exit 0
      EOS
      ::File.write(file_path, rc_local)
      File.chmod(0o755, file_path)
    end
  end
  action :run
end

# dnsmasq サービスの有効化と起動
service 'dnsmasq' do
  action %i[enable start]
end

log 'batman-adv mesh network configuration (gateway mode) completed. Reboot the system to apply changes.' do
  level :info
end
