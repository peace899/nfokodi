#!/bin/bash

#kodi nfo creator for music with data from headphones and beets recursively

#db files
headphonesdb=/opt/headphones/headphones.db #location of headphones DB
beetdb="/home/stepper/.config/beets/library.blb" #location of beets library | DB
directory=/mnt/storage/Music/Sorted #music directory

#commands
sqlbeets='sqlite3 '$beetdb''
sqlhp='sqlite3 '$headphonesdb''

#get paths
audio_types="wma|mp3|wav|m4a|flac|aac|ogg" 
find "$directory" -type f | egrep "\.($audio_types)$" |grep  -oP '^/.*(?=/)' | uniq > /tmp/al_folders
lines=`cat /tmp/al_folders | wc -l`

FILE=/tmp/al_folders

artist_info () {
if [ "$artist_f" == "Various Artists" ] || [ "$artist_f" == "Soundtracks" ]; then
	#no nfo for 'Various Artists' or 'Soundtracks' folder
	echo "No artist.nfo necessary...skipping"
	else
	cd "${ar_folder}"
		curl --silent --output artist.tbn "$thumb1"
		if [ -f "artist.nfo" ]; then
		#update artist.nfo with new album details by removing old ones
		sed -i '/\<album\>/Q' artist.nfo
		artist_albums >> artist.nfo
		else
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
    		<biography>$bio</biography>
   		<died>$died</died>
    		<disbanded>$disbanded</disbanded>
		<thumb>$path_nfs1/artist.tbn</thumb>
    		<thumb preview="$thumb1">$thumb1</thumb>
    		<fanart>
        		<thumb preview="$fanart">$fanart</thumb>
    		</fanart>
EOT
artist_albums >> artist.nfo
		fi 
fi
}

artist_albums () {
for n in $(seq `echo "$artistinfo" |wc -l`); do
album=`echo "$artistinfo" |awk -F"|" '{print $2}' | head -$n | tail -1`
year1=`echo "$artistinfo" |awk -F"|" '{print $1}' | head -$n | tail -1`
echo "		<album>" 
echo "      		<title>$album</title>" 
echo "       		 <year>$year1</year>"
echo "		</album>" 
done
echo "	</artist>" 
}

album_info () {
cd "${line}"
if [ -f "album.nfo" ] && [ "`cat album.nfo |grep -F "<track>" | wc -l`" -eq "`echo "$artistinfo" |wc -l`" ]; then
echo "Album.nfo exists in "$line" ...exiting"
else
cat <<EOT > album.nfo
<?xml version="1.0" encoding="UTF-8" standalone="yes" ?>
	<album>
		<title>$albumname</title>
    		<musicBrainzAlbumID>$album_id</musicBrainzAlbumID>
    		<artist>$artistname</artist>
    		<genre>$genre</genre>
    		<style>$style</style>
    		<mood></mood>
   		<theme></theme>
    		<compilation>$comp</compilation>
    		<review>$review</review>
   		<type>$albumtype</type>
    		<releasedate>$rel_date</releasedate>
   		<label>$label</label>
   		<thumb>$thumb2</thumb>
   		<thumb>$thumb3</thumb>
		<thumb>$thumb4</thumb>
    		<path>$path/</path>
   		<path>$path_nfs/</path>
    		<rating: max=10>$rating</rating>
    		<year>$year</year>
    		<albumArtistCredits>
        		<artist>$artistname</artist>
        		<musicBrainzArtistID>$artist_mbid</musicBrainzArtistID>
    		</albumArtistCredits>
EOT
	#album_tracks >> album.nfo
	fi
	}

album_tracks () {
for t in $(seq `echo "$albuminfo2" |wc -l`); do #
trackid=`echo "$albuminfo2" |awk -F"|" '{print $5}' | head -$t | tail -1`
length=`echo "$albuminfo2" |awk -F"|" '{print $6}' | head -$t | tail -1`
title=`echo "$albuminfo2" |awk -F"|" '{print $7}' | head -$t | tail -1`
position=`echo "$albuminfo2"|awk -F"|" '{print $1}' | head -$t | tail -1`
duration=`date -d@$length -u +%M:%S`
echo "		<track>"
echo "     	   	<position>$position</position>"
echo "        		<title>$title</title>"
echo "        		<duration>$duration</duration>"
echo "        		<musicBrainzTrackID>$trackid</musicBrainzTrackID>"
echo "   	 	</track>"
done
echo "	</album>"
}

while read line; do
#get album and artist ids from path
ar_folder=`echo "$line" | cut -d/ -f-7 | uniq`
al_folder=`echo "$line"`
artist_f=`basename "$ar_folder"` # |awk -F/ '{print $7}'`
artist_mbid=`beet info "$ar_folder" | awk '/mb_albumartistid: / {$1=""; print $0}' |sed 's/^ *//g' | uniq`
album_id=`beet info "$al_folder" | awk '/mb_albumid: / {$1=""; print $0}' |sed 's/^ *//g' | uniq`

#artist info
artistinfo=`${sqlbeets} "select year,album,albumartist,albumartist_sort,genre from albums where mb_albumartistid = '$artist_mbid'" |sort -u`
genre=`${sqlbeets} "select genre from items where mb_albumartistid = '$artist_mbid'" | head -1`
bio=`${sqlhp} "select Summary from descriptions where ArtistID = '$artist_mbid'" |sed '/^$/d' |awk -F"<" '{print $1}'`
thumb1=`${sqlhp} "select ThumbURL from artists where ArtistID = '$artist_mbid'" |sed -e 's/64s/128s/g'`
artistname=`echo "$artistinfo" |awk -F"|" '{print $3}' |sort -u | head -1`
artistname_sort=`echo "$artistinfo" |awk -F"|" '{print $4}' |sort -u | head -1`
style=`echo "$artistinfo" |awk -F"|" '{print $5}' |uniq | paste -s -d"/"`
path1=`echo "$ar_folder" |cut -d/ -f6- | sed -e 's/^/nfs\:\/\/192.168.2.122\/srv\/nfs\/music\//'`
path_nfs1=`echo "$ar_folder" |cut -d/ -f6- | sed -e 's/^/nfs\:\/\/192.168.2.122\/srv\/nfs\/music\//'`
thumb0=`echo "$path_nfs1/artist.tbn"`
#album info
albuminfo=`${sqlbeets} "select album,artpath,albumtype,mb_releasegroupid  from albums where mb_albumid = '$album_id'"`
albuminfo2=`${sqlbeets} "select track,genre,year,label,mb_trackid,length,title from items where mb_albumid = '$album_id'"`
albuminfo3=`${sqlhp} "select ReleaseID,ReleaseDate,UserScore from albums where AlbumID = '$album_id'"`
rel_id=`echo "$albuminfo" | awk -F"|" '{print $4}' |sort -u | head -1`
review=`${sqlhp} "select Summary from descriptions where ReleaseGroupID = '$rel_id'" |sed '/^$/d' |awk -F"<" '{print $1}'`
rel_date=`echo "$albuminfo3" | awk -F"|" '{print $2}'`
albumname=`echo "$albuminfo" | awk -F"|" '{print $1}' |sort -u | head -1`
year=`echo "$albuminfo2" | awk -F"|" '{print $3}' |sort -u | head -1`
label=`echo "$albuminfo2" | awk -F"|" '{print $4}' |sort -u | head -1`
albumtype=`echo "$albuminfo" | awk -F"|" '{print $3}' |sort -u | head -1`
rating=`${sqlhp} "select UserScore from albums where AlbumID = '$album_id'"`
thumb2=`echo "$albuminfo" | awk -F"|" '{print $2}' |sort -u | head -1`
thumb3u=`${sqlhp} "select ArtworkURL from albums where ReleaseID = '$rel_id'"` #
thumb3=`echo "$thumb3u" | sed 's/arQ/300x300/g'`
genre=`echo "$albuminfo2" | awk -F"|" '{print $2}' |sort -u | head -1`
style=`echo "$albuminfo2" | awk -F"|" '{print $2}' | uniq | paste -s -d"/"`
path_nfs=`echo "$al_folder" |cut -d/ -f6- | sed -e 's/^/nfs\:\/\/192.168.2.122\/srv\/nfs\/music\//'`
path=`echo "$al_folder"`
thumb4=`echo "$path_nfs/folder.jpg"`

artist_info 
album_info
procd=`grep -n "$line" /tmp/al_folders | cut -d : -f 1`
progress=`echo $lines  $procd | awk '{ pec=100*$2/$1 ; printf"%.0f\n", pec}'`
echo "$progress% Albums done | Finished ["$artistname"-"$albumname"]"

done < $FILE
