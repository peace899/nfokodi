#!/bin/bash

#my music folder structure is /mnt/storage/music/beets/genre/artist/album/track title.ext
#PHP required for urlencode

#config and lastfm api-key
apikey=''
config="" #change to your config.yaml normally '$HOME/.config/beets/config.yaml'
directory=`cat $config |awk '/directory:/ {$1=""; print $0}' |sed 's/^ *//g'` #get library/collection directory
nfs_dir='nfs://192.168.2.122/srv/nfs/music' #change to your smb or nfs correct directory

#add or delete based on your audio file types to search
audio_types="wma|mp3|wav|m4a|flac|aac|ogg" 

#music collection locations (al_folder: album folder, ar_folder: artist folder)
find "$directory" -type f | egrep "\.($audio_types)$" |grep  -oP '^/.*(?=/)' | uniq > /tmp/al_folders

#scrape for data
FILE=/tmp/al_folders
while read line; do
ar_folder=`echo $line | cut -d/ -f-7 | uniq`
artist_info=`beet -c "$config" info "$ar_folder"`
album_info=`beet -c "$config" info "$line"`
artist=`echo "$artist_info" | awk '/albumartist: / {$1=""; print $0}' |sed 's/^ *//g' | uniq | head -1`
artist_l=`echo "$artist" | php -R 'echo urlencode($argn);'`
artist_mbid=`echo "$artist_info" | awk '/mb_albumartistid: / {$1=""; print $0}' |sed 's/^ *//g' | uniq | head -1`
ar_albums=`echo "$artist_info"  |awk '/album: / {$1=""; print $0}' |sed 's/^ *//g' |sort -u | wc -l`
album=`echo "$album_info" | awk '/album: / {$1=""; print $0}' |sed 's/^ *//g' |sort -u | head -1`
album_l=`echo "$album" | php -R 'echo urlencode($argn);'`
year=`echo "$album_info" | awk '/original_year:/ {$1=""; print $0}' |sed 's/^ *//g' | uniq | head -1` 
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

	else
		if [ -f ".mb_artist.xml" ]; then
		echo "Artist file exist"
		else
		curl --silent https://musicbrainz.org/ws/2/artist/$artist_mbid?inc=tags > .mb_artist.xml
		fi

		if [ -f ".last_artist.xml" ]; then
		echo "Artist file exist"
		else
		curl --silent 'http://ws.audioscrobbler.com/2.0/?method=artist.getinfo&api_key='$apikey'&mbid='$artist_mbid'' > .last_artist.xml
		fi

bio=`cat .last_artist.xml | grep -oP '(?<=summary\>).+?(?=\&lt)'`
thumb=`cat .last_artist.xml | grep -oP '(?<=\<image size="extralarge">).+?(?=<)' | head -1`
genre=`echo "$artist_info" | awk '/genre: / {$1=""; print $0}' |sed 's/^ *//g' | uniq | head -1`
style=`cat .mb_artist.xml | grep -oP '(?<=\<tag-list\>).+?(\<\/tag-list\>)' | sed -e 's/<[^>]*>/\n/g' |sed '/^$/d' | sed -r 's/\<./\U&/g' | paste -s -d"/"`
ar_type=`cat .mb_artist.xml  | grep -oP '(?<=type=").+?(?=")' |head -1`

	if [ "$ar_type" == "Person" ];then
	born=`cat .mb_artist.xml | grep -oP '(?<=\<begin\>).+?(?=<)'`
	died=`cat .mb_artist.xml | grep -oP '(?<=\<end\>).+?(?=<)'`
	formed=""
	disbanded=""
	else
	born=""
	died=""
	formed=`cat .mb_artist.xml | grep -oP '(?<=\<begin\>).+?(?=<)'`
	disbanded=`cat .mb_artist.xml  | grep -oP '(?<=\<end\>).+?(?=<)'`
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
if [ -f "album.nfo" ] && [ "`cat album.nfo |grep -F "<track>" | wc -l`" -eq "`echo $tracks_album`" ]; then
echo "Album.nfo exists in "$line" ...exiting"
else
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

if [ -f ".last_album.xml" ]; then
echo "Album file exist"
else
curl --silent 'http://ws.audioscrobbler.com/2.0/?method=album.getinfo&api_key='$apikey'&artist='$artist_l'&album='$album_l'' > .last_album.xml
fi

if [ -f ".mb_album.xml" ]; then
echo "Album file exist"
else
curl --silent https://musicbrainz.org/ws/2/release/$album_id?inc=release-groups+ratings+tags > .mb_album.xml
fi

review=`cat .last_album.xml | grep -oP '(?<=summary\>).+?(?=\&lt)'`
path0=`echo "$al_folder" `
path1=`echo "$al_folder" |cut -d/ -f6-`
path2=`echo "$nfs_dir/$path1"`
style=`cat .mb_album.xml | grep -oP '(?<=\<tag-list\>).+?(\<\/tag-list\>)' | sed -e 's/<[^>]*>/\n/g' |sed '/^$/d' | sed -r 's/\<./\U&/g' |paste -s -d"/"`
thumb1=`cat .last_album.xml | grep -oP '(?<=\<image size="extralarge">).+?(?=<)' | head -1`
thumb2=`echo "$path2/folder.jpg"`
rating=`cat .mb_album.xml | grep -oP '(?=\<rating).+?(\<\/rating\>)' |sed -e 's/<[^>]*>//g'`

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
fi
}

album_tracks () {
for t in $(seq $tracks_album); do
track=`echo "$tracks" | head -$t |tail -1`
trackid=`echo "$track" | grep -oP '(?<=trackid: ).+?(?=;)'`
length=`echo "$track"| grep -oP '(?<=length: ).+?(?=;)'`
title=`echo "$track"| grep -oP '(?<=title: ).+?(?=;)'`
position=`echo "$track"| grep -oP '(?<=track: ).+?(?=;)'`
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
done < $FILE
