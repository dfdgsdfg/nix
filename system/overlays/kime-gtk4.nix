{ pkgs, kime }:
pkgs.stdenv.mkDerivation {
  pname = "kime-gtk4";
  inherit (kime) version src;
  patches = (kime.patches or [ ]) ++ [ ./kime-gtk4-commit.patch ];

  nativeBuildInputs = [ pkgs.pkg-config ];
  buildInputs = [ pkgs.gtk4 ];
  dontConfigure = true;

  buildPhase = ''
    runHook preBuild
    $CC -shared -fPIC -I${kime}/include \
      src/frontends/gtk4/src/gtk4.c \
      src/frontends/gtk3/src/immodule.c \
      src/frontends/gtk3/src/str_buf.c \
      $(pkg-config --cflags --libs gtk4) \
      -L${kime}/lib -Wl,-rpath,${kime}/lib -lkime_engine \
      -o libkime-gtk4.so
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    install -Dm755 libkime-gtk4.so \
      $out/lib/gtk-4.0/4.0.0/immodules/libkime-gtk4.so
    runHook postInstall
  '';

  doInstallCheck = true;
  nativeInstallCheckInputs = [ pkgs.python3 pkgs.xvfb-run ];
  installCheckPhase = ''
    runHook preInstallCheck
    export XDG_CACHE_HOME=$TMPDIR/font-cache
    mkdir -p "$XDG_CACHE_HOME"
    GTK_IM_MODULE=kime GTK_PATH=$out/lib/gtk-4.0 \
      GTK_A11Y=none GDK_BACKEND=x11 GSK_RENDERER=cairo \
      G_DEBUG=fatal-criticals xvfb-run -a \
      python ${./tests/kime-gtk4.py} ${pkgs.gtk4}/lib/libgtk-4.so.1
    runHook postInstallCheck
  '';
}
