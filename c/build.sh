#!/bin/sh

tmpd="$PWD"; [ "$PWD" = "/" ] && tmpd=""
case "$0" in
  /*) cdir="$0";;
  *) cdir="$tmpd/${0#./}"
esac
cdir="${cdir%/*}"

cd "$cdir"
gcc -g -Wall -O3 -o pacextractor pacextractor.c crc16.c
