# Maintainer : Philip Müller <philm@manjaro.org>
# Maintainer : Bernhard Landauer <oberon@manjaro.org>

pkgname=manjaro-system
pkgver=20210101
pkgrel=1
pkgdesc="Manjaro Linux System - Update script"
arch=('any')
url="http://www.manjaro.org"
license=('GPL')
# groups=('base')
depends=('mkinitcpio>=0.12.0-2' 'linux>=3.4' 'pacman>=5.0' 'coreutils' 'sed' 'awk')
install=manjaro-update-system.sh
source=('fsck.overlay'
		'dtd-wayland'
		'dtd-wayland.desktop')
sha256sums=('e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855'
            '464b12b29788d2e69a8020d8d51a9005e7091857b4cb874f6b5c72506ca5c69e'
            '1e8c6b709d915532f11ba39beedd3a9eebd3dc9658a7c343e20419417e2dbdf7')

pkgver() {
    date +%Y%m%d
}

package() {
   install -Dm755 "$srcdir/fsck.overlay" "$pkgdir/usr/bin/fsck.overlay"
   install -Dm755 "$srcdir/dtd-wayland" "$pkgdir/usr/bin/dtd-wayland"
   install -Dm644 "$srcdir/dtd-wayland.desktop" "$pkgdir/etc/xdg/autostart/dtd-wayland.desktop"
}
