#!/bin/sh

log () 
{
  echo "$@" >&2
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
  $ gist.sh  < file 

* Getting from GitHub:
  $ gist.sh 1234
'
}

gist_get () 
{
  URL="https://gist.github.com/$1.txt"
  GIST=$(curl -s $URL)

  log "* reading Gist from $URL\n\n" 
  echo "$GIST"
}

gist_post () 
{
  log "* readin Gist from stdin" 

  REQUEST_FILE=/tmp/gist.sh.req
  RESPONSE_FILE=/tmp/gist.sh.res

  #cleanup
  : > $RESPONSE_FILE
  : > $REQUEST_FILE

  # read file content
  #TODO: improve
  while read line; do
    echo "$line" >> $REQUEST_FILE
  done

  if [ ! -s $REQUEST_FILE ]; then
    help && exit 0
  fi
    
 curl http://gist.github.com/gists \
       -i \
       --silent \
       --data-urlencode private=on  \
       --data-urlencode 'file_name[gistfile1]=' \
       --data-urlencode 'file_ext[gistfile1]=' \
       --data-urlencode "file_contents[gistfile1]@$REQUEST_FILE" \
       -o $RESPONSE_FILE

  LOCATION=$(cat $RESPONSE_FILE|sed -ne '/Location/p'|cut -f2- -d:|tr -d ' ')
  log "* Gist location:"
  echo "$LOCATION"
}

require curl

case $1 in
  -h|--help)
    help
  ;;
  "")
    gist_post
  ;;
  *[a-zA-Z0-9]) # gist ID
    gist_get $1
  ;;
esac
