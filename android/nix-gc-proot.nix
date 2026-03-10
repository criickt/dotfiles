{ stdenv }:

stdenv.mkDerivation {
  pname = "proc-eperm-shim";
  version = "0.1.0";
  src = ./proc-eperm-shim.c;
  dontUnpack = true;
  buildPhase = ''
    $CC -shared -fPIC -o proc-eperm-shim.so $src -ldl
  '';
  installPhase = ''
    install -Dm755 proc-eperm-shim.so $out/lib/proc-eperm-shim.so
  '';
}
