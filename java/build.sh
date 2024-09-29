#!/bin/sh

tmpd="$PWD"; [ "$PWD" = "/" ] && tmpd=""
case "$0" in
  /*) cdir="$0";;
  *) cdir="$tmpd/${0#./}"
esac
cdir="${cdir%/*}"

cd "$cdir"
mkdir out

javac -sourcepath . -d out com/sprd/pacextractor/PacExtractor.java
cp -r com ../c ../python ../README.md out/
jar cfm PacExtractor-build.jar pacextractor.mf -C out/ .

#dx --dex --output=PacExtractor-dexed.jar PacExtractor-build.jar
