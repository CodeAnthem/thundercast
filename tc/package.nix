# ==================================================================================================
# ThunderCast - tc host CLI package
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date: Created: 2026-08-31 | Modified: 2026-08-31
# Description: NDS-free host companion (switch / clean / status / git-ssh / config)
# ==================================================================================================
{ stdenvNoCC, lib }:
stdenvNoCC.mkDerivation {
  pname = "tc";
  version = lib.fileContents ./VERSION;

  src = ./.;

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out/bin $out/lib
    cp -a lib/. $out/lib/
    cp VERSION $out/
    install -m755 bin/tc $out/bin/tc
    install -m755 bin/tc-git-ssh $out/bin/tc-git-ssh
    runHook postInstall
  '';

  meta = with lib; {
    description = "ThunderCast host CLI (tc switch/clean/status/git-ssh/config)";
    license = licenses.mit;
    platforms = platforms.linux;
    mainProgram = "tc";
  };
}
