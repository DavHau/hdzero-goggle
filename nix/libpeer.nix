{
  stdenv,
  fetchFromGitHub,
  cmake,
  breakpointHook,
  vim,
  ripgrep
}:
stdenv.mkDerivation {
  pname = "libpeer";
  version = "2025-04-05";
  src = fetchFromGitHub {
    owner = "sepfy";
    repo = "libpeer";
    rev = "20c73ee276c379b56daa05ce4bc50fed7d29438e";
    hash = "sha256-wOiD8GtUz39/Xc6+5Fnat1jwgpsYavJqXo2nTk9EXVw=";
    fetchSubmodules = true;
  };
  nativeBuildInputs = [
    cmake
    breakpointHook
    vim
    ripgrep
  ];
}
