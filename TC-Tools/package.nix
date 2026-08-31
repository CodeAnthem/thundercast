# ==================================================================================================
# ThunderCast - tc host CLI package
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
# Date: Created: 2026-08-31 | Modified: 2026-08-31
# Description: NDS-free host companion (switch / clean / restore / status / git-ssh)
# ==================================================================================================
{ stdenvNoCC, lib }:
stdenvNoCC.mkDerivation {
  pname = "tcast";
  version = lib.fileContents ./VERSION;

  src = ./.;

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out/bin $out/lib $out/commands
    cp -a lib/. $out/lib/
    cp -a commands/. $out/commands/
    cp VERSION $out/
    install -m755 bin/tcast $out/bin/tcast
    install -m755 bin/tcast-git-ssh $out/bin/tcast-git-ssh
    runHook postInstall
  '';

  meta = with lib; {
    description = "ThunderCast host CLI (tcast switch/clean/restore/status/git-ssh)";
    license = licenses.mit;
    platforms = platforms.linux;
    mainProgram = "tcast";
  };
}
