#!/bin/bash

#config and lastfm api-key
apikey=''
config="" #change to your config.yaml normally '$HOME/.config/beets/config.yaml'
directory=`cat $config |awk '/directory:/ {$1=""; print $0}' |sed 's/^ *//g'` #get library/collection directory
nfs_dir='nfs://192.168.2.122/srv/nfs/music' #change to your smb or nfs correct directory

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


#Scrape

FILE=/tmp/al_folders
while read line; do
ar_folder=`echo $line | cut -d/ -f-7 | uniq`
artist_info=`beet -c "$config" info "$ar_folder"`
album_info=`beet -c "$config" info "$line"`
artist=`echo "$artist_info" | awk '/albumartist: / {$1=""; print $0}' |sed 's/^ *//g' | uniq | head -1`
artist_mbid=`echo "$artist_info" | awk '/mb_albumartistid: / {$1=""; print $0}' |sed 's/^ *//g' | uniq | head -1`
ar_albums=`echo "$artist_info"  |awk '/album: / {$1=""; print $0}' |sed 's/^ *//g' |sort -u | wc -l`
album=`echo "$album_info" | awk '/album: / {$1=""; print $0}' |sed 's/^ *//g' |sort -u | head -1`
year=`echo "$album_info" | awk '/original_year:/ {$1=""; print $0}' |sed 's/^ *//g' | uniq | head -1` 
 #my file/directory structure is /mnt/storage/music/beets/genre/artist/album/track title.mp3
artist_f=`echo $ar_folder |awk -F/ '{print $7}'`

artist_info () {
if [ "$artist_f" == "Various Artists" ] || [ "$artist_f" == "Soundtracks" ]; then
#no nfo for 'Various Artists' or 'Soundtracks' folder
exit
else
cd "${ar_folder}"
if [ -f "artist.nfo" ]; then
#update artist.nfo with new album details by removing old ones
sed -i '/\<album\>/Q' artist.nfo
artist_albums >> artist.nfo

else #if artist.nfo doesn't exist create a new one
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

if [ "$bio" == "" ];then
bio=`echo "$bio2"`
fi
cat <<EOT > artist.nfo 
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
artist_albums >> artist.nfo
fi
fi
}

artist_albums () 
{
for n in $(seq $ar_albums); do
album=`echo "$artist_info" | awk '/album: / {$1=""; print $0}' |sed 's/^ *//g' |sort -u | head -$n | tail -1`
year=`echo "$artist_info" | awk '/original_year:/ {$1=""; print $0}' |sed 's/^ *//g' | uniq | head -$n | tail -1`
echo "<album>" 
echo "      <title>$album</title>" 
echo "        <year>$year</year>"
echo "</album>" 
done
echo "</artist>" 
}

album_info () {
cd "${line}"
al_folder=`echo $line`
title=`echo "$album_info" | awk '/album: / {$1=""; print $0}' |sed 's/^ *//g' |sort -u | sed -r 's/\<./\U&/g'`
tracks=`echo "$album_info" | sed -e 's/^[ \t]*//' |awk '$0 != "" {printf "%s; ",$0} $0 == "" {printf "\n"}'`
tracks_album=`echo "$tracks" | wc -l`
label=`echo "$album_info" | awk '/label: / {$1=""; print $0}' |sed 's/^ *//g' |sort -u`
rel_id=`echo "$album_info" | awk '/mb_releasegroupid: / {$1=""; print $0}' |sed 's/^ *//g' |sort -u`
album_id=`echo "$album_info" | awk '/albumid: / {$1=""; print $0}' |sed 's/^ *//g' |sort -u`
rel_date=`echo "$album_info" | awk '/original_date: / {$1=""; print $0}' |sed 's/^ *//g' |sort -u`
comp=`echo "$album_info" | awk '/comp: / {$1=""; print $0}' |sed 's/^ *//g' |sort -u`
al_type=`echo "$album_info" | awk '/albumtype: / {$1=""; print $0}' |sed 's/^ *//g' |sort -u | sed -r 's/\<./\U&/g'`
genre=`echo "$album_info" | awk '/genre: / {$1=""; print $0}' |sed 's/^ *//g' |sort -u | sed -r 's/\<./\U&/g'`
year=`echo "$album_info" | awk '/year: / {$1=""; print $0}' |sed 's/^ *//g' |sort -u | sed -r 's/\<./\U&/g'`
review=`curl --silent $url3/$rel_id/wikipedia-extract | grep wikipedia-extract |sed -e 's/<[^>]*>//g' | php -R 'echo html_entity_decode($argn);'`
curl --silent $url3/$rel_id > /tmp/album_info
path0=`echo "$al_folder" `
path1=`echo "$al_folder" |cut -d/ -f6-`
path2=`echo "$nfs_dir/$path1"`
style=`cat /tmp/album_info | grep -F "href=\"/tag" |sed -e 's/<[^>]*>//g' | php -R 'echo html_entity_decode($argn);' | sed -r 's/\<./\U&/g' |sed 's/^ *//g'`
thumb1=`cat /tmp/album_info | grep -F "thumbnail" | tail -1 |awk -F\" '{print $2}' |awk '$0="https:"$0'`
thumb2=`echo "$path2/folder.jpg"`
rating=`cat /tmp/album_info | grep -F "star-rating" |sed -e 's/<[^>]*>//g'|sed 's/^ *//g'|awk '{print $1}'`

cat <<EOT > album.nfo
<?xml version="1.0" encoding="UTF-8" standalone="yes" ?>
<album>
    <title>$title</title>
    <musicBrainzAlbumID>$album_id</musicBrainzAlbumID>
    <artist>$artist</artist>
    <genre>$genre</genre>
    <style>$style</style>
    <mood></mood>
    <theme></theme>
    <compilation>$comp</compilation>
    <review>$review</review>
    <type>$al_type</type>
    <releasedate>$rel_date</releasedate>
    <label>$label</label>
    <thumb>$thumb1</thumb>
    <thumb>$thumb2</thumb>
    <path>$path0/</path>
    <path>$path2/</path>
    <rating: max=5>$rating</rating>
    <year>$year</year>
    <albumArtistCredits>
        <artist>$artist</artist>
        <musicBrainzArtistID>$artist_mbid</musicBrainzArtistID>
    </albumArtistCredits>
EOT
album_tracks >> album.nfo
}

album_tracks () {
for t in $(seq $tracks_album); do
trackid=`echo "$tracks" | head -$t |tail -1| grep -oP '(?<=trackid: ).+?(?=;)'`
length=`echo "$tracks" | head -$t |tail -1| grep -oP '(?<=length: ).+?(?=;)'`
title=`echo "$tracks" | head -$t |tail -1| grep -oP '(?<=title: ).+?(?=;)'`
position=`echo "$tracks" | head -$t |tail -1| grep -oP '(?<=track: ).+?(?=;)'`
duration=`date -d@$length -u +%M:%S`
echo "<track>"
echo "        <musicBrainzTrackID>$trackid</musicBrainzTrackID>"
echo "        <title>$title</title>"
echo "        <position>$position</position>"
echo "        <duration>$duration</duration>"
echo "    </track>"
done
echo "</album>"
}
echo "processing....[$artist-$album]"
artist_info 
album_info
#echo "Done processing... with $tracks_album tracks"
done < $FILE
