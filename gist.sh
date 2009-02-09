#!/bin/sh

log () 
{
  echo -e "$@" >&2
}

err_exit ()
{
  log "Error: $1" 
  exit 1
}

require ()
{
  which $1 > /dev/null || err_exit "$0 requires '$1'"
}

help () 
{
  log 'Usage: 
* Posting to GitHub:
  $ cat file|gist.sh
or
  $ gist.sh < file
or
  $ gist.sh -f file

  * When reading from standard input, the gist language can be set with -e:
    $ gist.sh -e java < file

  * When reading from a file, github guesses the language based on the filename extension

* Getting from GitHub:
  $ gist.sh 1234
or
  $ gist.sh -f file 1234
'
}

gist_get () 
{
  URL="https://gist.github.com/$1.txt"
  log "* reading Gist from $URL"
  CMD="curl -s $URL"

  if [ "$_FILENAME" = "" ]; then
    log "\n"
    echo "$($CMD)"
  else
    if [ -f "$_FILENAME" ]; then
      log "* Filename $_FILENAME already exists, aborting."
      exit 1
    fi
    $CMD > $_FILENAME
    log "* Gist written to file $_FILENAME"
  fi
}

gist_post ()
{
  if [ "$_FILENAME" = "" ]; then
    log "* readin Gist from stdin"
    REQUEST_FILE=/tmp/gist.sh.req

    #cleanup
    : > $REQUEST_FILE

    # read file content
    #TODO: improve
    OLDIFS="$IFS"
    IFS=""
    while read line; do
      echo "$line" >> $REQUEST_FILE
    done
    IFS="$OLDIFS"

    FILENAME=""
    FILEEXT=".$_FILEEXT"
  else
    log "* readin Gist from $_FILENAME"

    REQUEST_FILE="$_FILENAME"

    FILENAME=$(basename "$_FILENAME")

    if [ "$_FILEEXT" != "" ]; then
      log "* warning: -e specified with -f, ignoring -e"
    fi

    FILEEXT=""
  fi

  if [ ! -s $REQUEST_FILE ]; then
    help && exit 0
  fi

  RESPONSE_FILE=/tmp/gist.sh.res

  #cleanup
  : > $RESPONSE_FILE

  curl http://gist.github.com/gists \
       -i \
       --silent \
       --data-urlencode private=on  \
       --data-urlencode "file_name[gistfile1]=$FILENAME" \
       --data-urlencode "file_ext[gistfile1]=$FILEEXT" \
       --data-urlencode "file_contents[gistfile1]@$REQUEST_FILE" \
       -o $RESPONSE_FILE

  LOCATION=$(cat $RESPONSE_FILE|sed -ne '/Location/p'|cut -f2- -d:|tr -d ' ')
  log "* Gist location:"
  echo "$LOCATION"
}

require curl

while [ $# -gt 0 ]; do
  case $1 in
  -h|--help)
      help
      exit 0
  ;;
  -e|--ext)
      shift
      _FILEEXT="$1"
  ;;
  -f|--file)
      shift
      _FILENAME="$1"
  ;;
  *[a-zA-Z0-9]) # gist ID
      gist_get $1
      exit 0
  ;;
  esac
  shift
done
gist_post
