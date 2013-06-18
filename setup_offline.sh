LOCAL_RESOURCE_ROOT=public/offline
function grab_remote () {
  for c in $1; do 
    LOCAL_FILE=$2/${c#//}
    LOCAL_FILE=${LOCAL_FILE%%[#\?]*}
    if [[ "$c" != //* ]]; then
      c=http://${2#$LOCAL_RESOURCE_ROOT/}/${c#//}
    else
      c=http:$c
    fi
    # deal with css ../ paths
    while [[ $c =~ ([^/][^/]*/\.\./) ]]
    do
      c=${c/${BASH_REMATCH[0]}/}
    done
    echo fetching $c into $LOCAL_FILE
    curl $c -# -o $LOCAL_FILE --create-dirs
  done
}

function sed_exec () {
  if hash gsed 2>/dev/null; then
    gsed "$@"
  else
    sed "$@"
  fi
}
rm -rf $LOCAL_RESOURCE_ROOT
mkdir -p $LOCAL_RESOURCE_ROOT

REMOTE_SCRIPTS=`cat views/scripts.erb | tr -d '\n'  | grep -o '"//[^"]*"' | tr -d \" `
grab_remote "$REMOTE_SCRIPTS" $LOCAL_RESOURCE_ROOT

LOCAL_SCRIPTS=`cat ../mindmup/views/scripts.erb | tr -d '\n'  | grep -o '"/[^/][^"]*"' | tr -d \"`

REMOTE_CSS=`sed 's/<%=load_prefix%>//g' views/editor.erb | grep -o "//[^\"]*.css"`
grab_remote "$REMOTE_CSS" $LOCAL_RESOURCE_ROOT

for cssfile in `find $LOCAL_RESOURCE_ROOT -name '*.css'`; do
  echo processing CSS file $cssfile
  REMOTE_RESOURCES=`grep -o 'url([^)]*)' $cssfile | sed s/url//g | tr -d \'\"\)\(`
  grab_remote "$REMOTE_RESOURCES" `dirname $cssfile`
  sed_exec -i 's/\(url.*\)\/\//\1/g' $cssfile
done

