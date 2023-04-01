# Maintainer : Philip Müller <philm@manjaro.org>
# Maintainer : Bernhard Landauer <oberon@manjaro.org>

pkgname=manjaro-system
pkgver=20230401
pkgrel=1
pkgdesc="Manjaro Linux System - Update script"
arch=('any')
url="https://gitlab.manjaro.org/packages/core/manjaro-system"
license=('GPL')
depends=('initramfs' 'base')
install=manjaro-update-system.sh
source=('fsck.overlay'
        'networkmanager-connectivity.hook')
sha256sums=('e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855'
            'fc1fd9410f2b41726fac5b643c06f3324f3cd178a3533cc02ec656c3692ce90f')

pkgver() {
    date +%Y%m%d
}

package() {
   install -Dm755 "$srcdir/fsck.overlay" "$pkgdir/usr/bin/fsck.overlay"
   install -Dm644 "$srcdir/networkmanager-connectivity.hook" \
      "$pkgdir/usr/share/libalpm/hooks/networkmanager-connectivity.hook"
}
