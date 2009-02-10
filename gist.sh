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
* Posting to GitHub via standard input:
  $ cat file|gist.sh
  $ gist.sh < file
or from a file:
  $ gist.sh -f file
or from the clipboard (xclip must be available):
  $ gist.sh -c

  * When reading from standard input or clipboard, the gist language can be set with -e:
    $ gist.sh -e java < file

  * When reading from a file, github guesses the language based on the filename extension

* Getting from GitHub:
  $ gist.sh 1234
or
  $ gist.sh -f file 1234
or
  $ gist.sh -c 1234

* Cloning a gist from GitHub (if -p is also specified make a clone using the private clone URL -- this
  requires the gist to have been created with authentication):
  $ gist.sh -l 1234

* Debug mode: Specify -d to show the command that would be used to retrieve or post a gist to github.

* Gists are public by default. Pass -p or --private to make a gist private.

* If your git config contains github.user and github.token (see https://github.com/account), they
  will be used to assign yourself as owner of the posted gist. Use the -a or --anon parameter to
  post anonymously.
'
}

gist_get ()
{
  URL="https://gist.github.com/$1.txt"
  log "* reading Gist from $URL"

  CMD="curl -s $URL"

  if [ "$_DEBUG" = "1" ]; then
    echo $CMD
    exit 0
  fi

  if [ "$_FILENAME" != "" ]; then
    if [ -f "$_FILENAME" ]; then
      log "* Filename $_FILENAME already exists, aborting."
      exit 1
    fi
    $CMD > $_FILENAME
    log "* Gist written to file $_FILENAME"
  elif [ "$_CLIP" = "1" ]; then
    $CMD | xclip -i -selection clipboard
    log "* Gist written to clipboard"
  else
    log "\n"
    echo "$($CMD)"
  fi
}

gist_clone ()
{
  if [ "$_PRIVATE" = "1" ]; then
    URL="git@gist.github.com:$1.git"
  else
    URL="git://gist.github.com/$1.git"
  fi

  log "* cloning Gist from $URL"

  CMD="git clone $URL gist-$1"

  if [ "$_DEBUG" = "1" ]; then
    echo $CMD
    exit 0
  fi

  $CMD
}

gist_post ()
{
  if [ "$_FILENAME" != "" ]; then
    log "* reading Gist from $_FILENAME"

    REQUEST_FILE="$_FILENAME"

    FILENAME=$(basename "$_FILENAME")

    if [ "$_FILEEXT" != "" ]; then
      log "* warning: -e specified with -f, ignoring -e"
    fi

    FILEEXT=""
  elif [ "$_CLIP" = "1" ]; then
    log "* reading Gist from clipboard"
    REQUEST_FILE=/tmp/gist.sh.req

    xclip -o -selection clipboard > $REQUEST_FILE

    FILENAME=""
    FILEEXT=".$_FILEEXT"
  else
    log "* reading Gist from stdin"
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
  fi

  if [ ! -s $REQUEST_FILE ]; then
    help && exit 0
  fi

  RESPONSE_FILE=/tmp/gist.sh.res

  #cleanup
  : > $RESPONSE_FILE

  if [ "$_DEBUG" = "1" ]; then
    DEBUG=echo
  fi

  if [ "$_PRIVATE" = "1" ]; then
    PRIVATE="--data-urlencode private=on"
  else
    PRIVATE=""
  fi

  if [ "$_ANON" != "1" ]; then
    require git

    USER=$(git config --global github.user)
    USERAVAIL=$?
    TOKEN=$(git config --global github.token)
    TOKENAVAIL=$?
    if [ $USERAVAIL -eq 0 -a $TOKENAVAIL -eq 0 ]; then
      AUTH="--data-urlencode login=$USER --data-urlencode token=$TOKEN"
    fi
  fi

  $DEBUG curl http://gist.github.com/gists \
       -i \
       --silent \
       $PRIVATE \
       $AUTH \
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
  -d|--debug)
      _DEBUG=1
  ;;
  -e|--ext)
      shift
      _FILEEXT="$1"
  ;;
  -f|--file)
      shift
      _FILENAME="$1"
  ;;
  -c|--clip)
      require xclip
      _CLIP=1
  ;;
  -p|--private)
      _PRIVATE=1
  ;;
  -a|--anon)
      _ANON=1
  ;;
  -l|--clone)
      require git
      _CLONE=1
  ;;
  *[a-zA-Z0-9]) # gist ID
      if [ "$_CLONE" = "1" ]; then
        gist_clone $1
      else
        gist_get $1
      fi
      exit 0
  ;;
  esac
  shift
done
gist_post
