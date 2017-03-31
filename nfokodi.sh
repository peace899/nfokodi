#!/bin/bash

#config and lastfm api-key
apikey=''
config="" #change to your config.yaml normally '$HOME/.config/beets/config.yaml'
directory=`cat $config |awk '/directory:/ {$1=""; print $0}' |sed 's/^ *//g'` #get library/collection directory

#MusicBrainz URLs 1: artist page, 2: album page, 3: release-group page
url='https://musicbrainz.org/artist' 
url2='https://musicbrainz.org/release'
url3='https://musicbrainz.org/release-group'
#Last.FM artist page URL
#url4="http://ws.audioscrobbler.com/2.0/?method=artist.getinfo&api_key='$apikey'&mbid='$artist_mbid'"

#add or delete based on your audio file types to search
audio_types="wma|mp3|wav|m4a|flac|aac|ogg" 

#music collection locations (al_folder: album folder, ar_folder: artist folder)
find "$directory" -type f | egrep "\.($audio_types)$" |grep  -oP '^/.*(?=/)' | uniq > /tmp/al_folders
cat /tmp/al_folders | cut -d/ -f-7 | uniq | head -2 > /tmp/ar_folders
artists=`cat /tmp/ar_folders |wc -l` #number of album artists

#Scrape
#for i in $(seq $artists); do
FILE=/tmp/ar_folders
while read line; do
ar_folder=`echo $line`
artist=`beet -c "$config" info "$ar_folder" | awk '/albumartist: / {$1=""; print $0}' |sed 's/^ *//g' | uniq | head -1`
artist_mbid=`beet -c "$config" info "$ar_folder" | awk '/mb_albumartistid: / {$1=""; print $0}' |sed 's/^ *//g' | uniq | head -1`

bio=`curl --silent $url/$artist_mbid/wikipedia-extract | grep wikipedia-extract |sed -e 's/<[^>]*>//g' | perl -MHTML::Entities -pe 'decode_entities($_);'`
curl --silent $url/$artist_mbid > /tmp/mb_info
curl --silent 'http://ws.audioscrobbler.com/2.0/?method=artist.getinfo&api_key='$apikey'&mbid='$artist_mbid'' > /tmp/lastfm_info
bio2=`cat /tmp/lastfm_info | grep -oP '(?<=summary\>).+?(?=\&lt)'`
thumb=`cat /tmp/lastfm_info | grep -oP '(?<=\<image size="extralarge">).+?(?=<)' | head -1`
genre=`cat /tmp/lastfm_info  | grep -oP '(?<=\<tag><name>).+?(?=<)' | sed -r 's/\<./\U&/g' | head -1`
style=`cat /tmp/lastfm_info | grep -oP '(?<=\<tag><name>).+?(?=<)' | sed -r 's/\<./\U&/g' | paste -s -d"/"`
ar_type=`cat /tmp/mb_info  | grep -oP '(?<=type":\[").+?(?=")' |head -1`
born=`cat /tmp/mb_info | grep -oP '(?<=Born:).+?(?=,)'`
died=`cat /tmp/mb_info  | grep -oP '(?<=Died:).+?(?=,)'`
formed=`cat /tmp/mb_info  | grep -oP '(?<=Founded:).+?(?=,)'`
disbanded=`cat /tmp/mb_info  | grep -oP '(?<=Dissolved:).+?(?=,)'`
ar_albums=`cat /tmp/al_folders  | grep -F "$artist" | wc -l`
if [ "$bio" == "" ];then
bio=`echo "$bio2"`
fi

artist_albums () 
{
for n in $(seq $ar_albums); do
 album=`beet -c "$config" info "$ar_folder" | awk '/album: / {$1=""; print $0}' |sed 's/^ *//g' |sort -u | head -$n | tail -1`
 year=`beet -c "$config" info "$ar_folder" | awk '/original_year:/ {$1=""; print $0}' |sed 's/^ *//g' | uniq | head -$n | tail -1`
echo "<album>" 
echo "      <title>$album</title>" 
echo "        <year>$year</year>"
echo "</album>" 
done
echo "</artist>" 
}

artist_info () {
cat <<EOT > $artist.nfo 
<?xml version="1.0" encoding="UTF-8" standalone="yes" ?>
<artist>
   <name>$artist</name>
   <musicBrainzArtistID>$artist_mbid</musicBrainzArtistID>
    <sortname></sortname>
    <genre>$genre</genre>
    <style>$style</style>
    <yearsactive></yearsactive>
    <born>$born</born>
   <formed>$formed</formed>
    <biography>$bio</biography>
   <died>$died</died>
    <disbanded>$disbanded</disbanded>
    <thumb preview="$thumb">$thumb</thumb>
    <fanart>
        <thumb preview="$fanart">$fanart</thumb>
    </fanart>
EOT
}
artist_info 
artist_albums >> $artist.nfo
done < $FILE
