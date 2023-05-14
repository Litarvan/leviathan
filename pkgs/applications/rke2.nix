{ lib, fetchurl, stdenv }:

stdenv.mkDerivation rec {
  pname = "rke2";
  version = "1.27.1+rke2r1";

  src = fetchurl {
    url = "https://github.com/rancher/rke2/releases/download/v${version}/rke2.linux-amd64.tar.gz";
    hash = "sha256-4Caq1fTKHZ9L7reDxou/nHjar/JUJSMWDcVpzL0Z4Lk=";
  };

  sourceRoot = ".";
  installPhase = ''
    install -Dm755 bin/rke2 $out/bin/rke2
    install -Dm755 bin/rke2-killall.sh $out/bin/rke2-killall.sh
    install -Dm644 share/rke2/LICENSE.txt $out/share/rke2/LICENSE.txt
  '';
}