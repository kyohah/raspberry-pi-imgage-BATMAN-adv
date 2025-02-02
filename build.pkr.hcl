variable "img_mount_path" {
  type    = string
  default = "/mnt/raspbian"
}

source "arm-image" "raspbian" {
  iso_url      = "https://downloads.raspberrypi.org/raspios_armhf/images/raspios_armhf-2024-11-19/2024-11-19-raspios-bookworm-armhf.img.xz"
  iso_checksum = "sha256:6af31270988e4e85e37162d9a07831c33c130e9e32d412ec6f7d16e38e8369d7"
  mount_path   = var.img_mount_path
}

build {
  sources = [
    "source.arm-image.raspbian"
  ]

  provisioner "shell" {
    inline = [
      "touch /boot/ssh"
    ]
  }

  provisioner "shell-local" {
    inline = [
      "curl -L https://github.com/itamae-kitchen/mitamae/releases/download/v1.14.2/mitamae-armhf-linux.tar.gz | tar xvz",
      "mv mitamae-armhf-linux mitamae",
      "sudo ./mitamae local -c /build/mitamae/recipe.rb --root ${var.img_mount_path}"
    ]
  }
}
