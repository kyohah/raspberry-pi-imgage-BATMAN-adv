# frozen_string_literal: true

# recipe.rb

# 必要なパッケージのインストール
package 'gpsd' do
  action :install
end

package 'gpsd-clients' do
  action :install
end

package 'pps-tools' do
  action :install
end

# /boot/cmdline.txt の更新
# 既存の設定行をコメントアウトし、新たな行を追加します。
file '/boot/cmdline.txt' do
  content <<~EOF.chomp
    #dwc_otg.lpm_enable=0 console=serial0,115200 console=tty1 root=PARTUUID=2924e30a-02 rootfstype=ext4 elevator=deadline fsck.repair=yes rootwait
    dwc_otg.lpm_enable=0 console=tty1 root=/dev/mmcblk0p2 rootfstype=ext4 elevator=deadline rootwait
  EOF
  owner 'root'
  group 'root'
  mode '0644'
end

# /boot/config.txt に、GPSの1PPS信号用設定を追記
ruby_block 'append pps-gpio overlay to /boot/config.txt' do
  block do
    file_path = '/boot/config.txt'
    overlay_line = 'dtoverlay=pps-gpio,gpiopin=18,assert_falling_edge=true'
    content = ::File.exist?(file_path) ? ::File.read(file_path) : ''
    unless content.include?(overlay_line)
      content << "\n" unless content.end_with?("\n")
      content << "#{overlay_line}\n"
      ::File.write(file_path, content)
    end
  end
  action :run
end

# /etc/default/gpsd に、gpsd の設定を追記
ruby_block 'append gpsd configuration to /etc/default/gpsd' do
  block do
    file_path = '/etc/default/gpsd'
    lines_to_add = [
      'START_DAEMON="true"',
      'DEVICES="/dev/ttyS0 /dev/pps0"',
      'GPSD_OPTIONS="-n"'
    ]
    content = ::File.exist?(file_path) ? ::File.read(file_path) : ''
    lines_to_add.each do |line|
      unless content.include?(line)
        content << "\n" unless content.end_with?("\n")
        content << "#{line}\n"
      end
    end
    ::File.write(file_path, content)
  end
  action :run
end

# gpsd.socket の有効化（systemctl enable および start）
service 'gpsd.socket' do
  action %i[enable start]
end
