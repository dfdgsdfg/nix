final: prev: {
  kime = prev.kime.overrideAttrs (oldAttrs: rec {
    version = "3.2.0";

    src = final.fetchFromGitHub {
      owner = "Riey";
      repo = "kime";
      rev = "v${version}";
      hash = "sha256-YQQ27pSyuznqOI5o5oqLQIdUPqnrw8UTmD65KL9su3c=";
    };

    cargoDeps = final.rustPlatform.fetchCargoVendor {
      inherit src;
      hash = "sha256-FP7uHsLVozB6kpwCuNFrYY2j6RQUL6n41hfvlFN5/qI=";
    };

    nativeBuildInputs = final.lib.unique (
      (oldAttrs.nativeBuildInputs or [ ])
      ++ (with final; [
        llvmPackages_18.bintools
        llvmPackages_18.clang
        llvmPackages_18.libclang.lib
        meson
        ninja
        python3
      ])
    );

    buildInputs = final.lib.unique (
      (oldAttrs.buildInputs or [ ])
      ++ (with final; [
        libGL
        libxkbcommon
        wayland
      ])
    );

    LIBCLANG_PATH = "${final.llvmPackages_18.libclang.lib}/lib";

    configurePhase = ''
      runHook preConfigure
      # Keep the Qt5 setup hook while exposing Qt6 directly to Meson. Loading
      # both setup hooks in one derivation is rejected as a mixed Qt ABI.
      export PATH="${final.qt6.qtbase}/bin:$PATH"
      export PKG_CONFIG_PATH="${final.qt6.qtbase}/lib/pkgconfig''${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}"
      meson setup build \
        --prefix=$out \
        -Dcargo_profile=release \
        -Dgtk3=enabled \
        -Dgtk4=enabled \
        -Dqt5=enabled \
        -Dqt6=enabled \
        -Dqt5_plugindir=$out/${final.qt5.qtbase.qtPluginPrefix} \
        -Dqt6_plugindir=$out/${final.qt6.qtbase.qtPluginPrefix}
      runHook postConfigure
    '';

    buildPhase = ''
      runHook preBuild
      ninja -C build
      runHook postBuild
    '';

    checkPhase = ''
      runHook preCheck
      cargo test --release --frozen
      runHook postCheck
    '';

    installPhase = ''
      runHook preInstall
      ninja -C build install
      runHook postInstall
    '';
  });
}
