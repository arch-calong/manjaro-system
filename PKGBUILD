# Maintainer : Philip Müller <philm@manjaro.org>
# Maintainer : Bernhard Landauer <oberon@manjaro.org>

pkgname=manjaro-system
pkgver=20210321
pkgrel=1
pkgdesc="Manjaro Linux System - Update script"
arch=('any')
url="http://www.manjaro.org"
license=('GPL')
# groups=('base')
depends=('mkinitcpio>=0.12.0-2' 'pacman>=5.0' 'coreutils' 'sed' 'awk')
install=manjaro-update-system.sh
source=('fsck.overlay'
		'dtd-wayland'
		'dtd-wayland.desktop'
		'networkmanager-connectivity.hook')
sha256sums=('e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855'
            '445654f1a66d2a7edf631c1c9af0d9f0c6630b5586647d98c67f3e1e0dd9b02c'
            '1e8c6b709d915532f11ba39beedd3a9eebd3dc9658a7c343e20419417e2dbdf7'
            'fc1fd9410f2b41726fac5b643c06f3324f3cd178a3533cc02ec656c3692ce90f')

pkgver() {
    date +%Y%m%d
}

package() {
   install -Dm755 "$srcdir/fsck.overlay" "$pkgdir/usr/bin/fsck.overlay"
   install -Dm755 "$srcdir/dtd-wayland" "$pkgdir/usr/bin/dtd-wayland"
   install -Dm644 "$srcdir/dtd-wayland.desktop" "$pkgdir/etc/xdg/autostart/dtd-wayland.desktop"
   install -Dm644 "$srcdir/networkmanager-connectivity.hook" "$pkgdir/usr/share/libalpm/hooks/networkmanager-connectivity.hook"
}
