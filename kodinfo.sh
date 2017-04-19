#!/bin/bash

#my music folder structure is /mnt/storage/music/beets/genre/artist/album/track title.ext
#PHP required for urlencode
#It requires a modified runafter.py plugin from m-urban (https://github.com/m-urban) to work


#config and lastfm api-key
apikey='ec61820ccf6e0c0c915c91dcb37eaf5f'
nfs_dir='nfs://192.168.2.122/srv/nfs/music' #change to your smb or nfs correct directory
sqlbeets='sqlite3 /home/stepper/.config/beets/library.blb'

line=`${sqlbeets} "select * from items" | tail -1 | awk -F"|" '{print $53}'|grep  -oP '^/.*(?=/)'`
ar_folder=`dirname "$line"`
artist_f=`basename "$ar_folder"`
artist_mbid=`beet info "$ar_folder" | awk '/mb_albumartistid:/ {$1=""; print $0}' |sed 's/^ *//g' | uniq`
album_mbid=`beet info "$line" | awk '/mb_albumid:/ {$1=""; print $0}' |sed 's/^ *//g' | uniq`

artistinfo=`${sqlbeets} "select year,album,albumartist,albumartist_sort,genre from albums where mb_albumartistid = '$artist_mbid'" |sort -u`
albuminfo=`${sqlbeets} "select track,title,year,album,genre,label,mb_releasegroupid,albumtype,comp,month,day,length,mb_trackid from items where mb_albumid = '$album_mbid'" |sort -u`

artistname=`echo "$artistinfo" |awk -F"|" '{print $3}' |sort -u | head -1`
artistname_sort=`echo "$artistinfo" |awk -F"|" '{print $4}' |sort -u | head -1`
artist_l=`echo "$artistname" | php -R 'echo urlencode($argn);'`
ar_albums=`echo "$artistinfo"  |awk -F"|" '{print $2}' |sort -u | wc -l`
album=`echo "$albuminfo" |awk -F"|" '{print $4}' |sort -u | head -1`
album_l=`echo "$album" | php -R 'echo urlencode($argn);'`
year=`echo "$albuminfo" |awk -F"|" '{print $1}' |sort -u` 


artist_info () {
if [ "$artist_f" == "Various Artists" ] || [ "$artist_f" == "Soundtracks" ]; then
#no nfo for 'Various Artists' or 'Soundtracks' folder
echo "skipping"
else
cd "${ar_folder}"
curl --silent https://musicbrainz.org/ws/2/artist/$artist_mbid?inc=tags > .mb_artist.xml
curl --silent 'http://ws.audioscrobbler.com/2.0/?method=artist.getinfo&api_key='$apikey'&mbid='$artist_mbid'' > .last_artist.xml

bio=`cat .last_artist.xml | grep -oP '(?<=summary\>).+?(?=\&lt)'`
thumb=`cat .last_artist.xml | grep -oP '(?<=\<image size="extralarge">).+?(?=<)' | head -1`
genre=`echo "$artistinfo" |awk -F"|" '{print $5}' |sort -u | head -1`
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
   <name>$artistname</name>
   <musicBrainzArtistID>$artist_mbid</musicBrainzArtistID>
   <sortname>$artistname_sort</sortname>
   <genre>$genre</genre>
   <style>$style</style>
   <yearsactive></yearsactive>
   <born>$born</born>
   <formed>$formed</formed>
   <biography>"$bio"</biography>
   <died>$died</died>
   <disbanded>$disbanded</disbanded>
   <thumb preview="$thumb">$thumb</thumb>
   <fanart>
        <thumb preview="$fanart">$fanart</thumb>
   </fanart>
EOT
artist_albums >> artist.nfo
	
fi
}

artist_albums () 
{
for n in $(seq $ar_albums); do
album=`echo "$artistinfo" | awk -F"|" '{print $2}' | head -$n | tail -1`
year_n=`echo "$artistinfo" | awk -F"|" '{print $1}' | head -$n | tail -1`
echo "   <album>" 
echo "      <title>$album</title>" 
echo "      <year>$year_n</year>"
echo "   </album>" 
done
echo "</artist>" 
}

album_info () {

cd "${line}"
al_folder=`echo $line`
title_a=`echo "$albuminfo" | awk -F"|" '{print $4}' |head -1`
#tracks=`echo "$albuminfo" | awk -F"|" '{print $1}'`
tracks_album=`echo "$albuminfo" | awk -F"|" '{print $1}' | wc -l`
label=`echo "$albuminfo" | awk -F"|" '{print $6}' |head -1`
rel_id=`echo "$albuminfo" | awk -F"|" '{print $7}' |head -1`
rel_date=`echo "$albuminfo" | awk -F"|" -v OFS='-' '{print $3, $10, $11}' |head -1`
comp=`echo "$albuminfo" | awk -F"|" '{print $9}' |head -1`
	if [ "$comp" -eq 0 ];then
	comp='False'
	else
	comp='True'
	fi
al_type=`echo "$albuminfo" | awk -F"|" '{print $8}' |head -1`
genre=`echo "$albuminfo" | awk -F"|" '{print $5}' |head -1`
year=`echo "$albuminfo" | awk -F"|" '{print $4}' |head -1`


curl --silent 'http://ws.audioscrobbler.com/2.0/?method=album.getinfo&api_key='$apikey'&artist='$artist_l'&album='$album_l'' > .last_album.xml
curl --silent https://musicbrainz.org/ws/2/release/$album_mbid?inc=release-groups+ratings+tags > .mb_album.xml

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
    <title>$title_a</title>
    <musicBrainzAlbumID>$album_mbid</musicBrainzAlbumID>
    <artist>$artistname</artist>
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
position=`echo "$albuminfo" | awk -F"|" '{print $1}'| head -$t |tail -1`
trackid=`echo "$albuminfo" | awk -F"|" '{print $13}'| head -$t |tail -1`
length=`echo "$albuminfo" | awk -F"|" '{print $12}'| head -$t |tail -1`
title=`echo "$albuminfo" | awk -F"|" '{print $2}'| head -$t |tail -1`
duration=`date -d@$length -u +%M:%S`
echo "    <track>"
echo "        <position>$position</position>"
echo "        <title>$title</title>"
echo "        <duration>$duration</duration>"
echo "        <musicBrainzTrackID>$trackid</musicBrainzTrackID>"
echo "    </track>"
done
echo "</album>"
}
sleep 10
echo "Creating kodi .nfo file for [$artistname-$album]"
artist_info
sleep 5 
album_info
texturecache ascan #update kodi music
#done < $FILE
