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

FILE=/tmp/al_folders
while read line; do
#get album and artist ids from path
ar_folder=`echo $line | cut -d/ -f-7 | uniq`
al_folder=`echo $line`
artist_f=`echo $line |awk -F/ '{print $NF}'`
artist_mbid=`beet info "$ar_folder" | awk '/mb_albumartistid: / {$1=""; print $0}' |sed 's/^ *//g' | uniq`
album_id=`beet info "$al_folder" | awk '/mb_albumid: / {$1=""; print $0}' |sed 's/^ *//g' | uniq`

#artist info
artistname=`${sqlbeets} "select albumartist from albums where mb_albumartistid = '$artist_mbid'" |sort -u`
artistname_sort=`${sqlbeets} "select albumartist_sort from albums where mb_albumartistid = '$artist_mbid'" |sort -u`
bio=`${sqlhp} "select Summary from descriptions where ArtistID = '$artist_mbid'" | sed -e 's/<[^>]*>/\n/g'`
genre=`${sqlbeets} "select genre from items where mb_albumartistid = '$artist_mbid'" | head -1`
style=`${sqlbeets} "select genre from albums where mb_albumartistid = '$artist_mbid'" |uniq | paste -s -d"/"`
thumb1=`${sqlhp} "select ThumbURL from artists where ArtistID = '$artist_mbid'" |sed -e 's/64s/128s/g'`
albums=`${sqlbeets} "select album,year from albums where mb_albumartistid = '$artist_mbid'"`

#album info
albumname=`${sqlbeets} "select album from albums where mb_albumid = '$album_id'"`
thumb2=`${sqlbeets} "select artpath from albums where mb_albumid = '$album_id'"`
thumb3=`${sqlhp} "select ArtworkURL from albums where AlbumID = '$album_id'" |sed -e 's/arQ/300x300/g'`
review=`${sqlhp} "select Summary from descriptions where ReleaseGroupID = '$rel_id'";`
tracks=`${sqlbeets} "select track,mb_trackid,length,title from items where mb_albumid = '$album_id'"`
genre=`${sqlbeets} "select genre from items where mb_albumid = '$album_id'" |head -1`
style=`${sqlbeets} "select genre from items where mb_albumid = '$album_id'" |uniq | paste -s -d"/"`
year=`${sqlbeets} "select year from items where mb_albumid = '$album_id'" |sort -u`
label=`${sqlbeets} "select label from items where mb_albumid = '$album_id'" |sort -u`
albumtype=`${sqlbeets} "select albumtype from albums where mb_albumid = '$album_id'"`
path_nfs=`echo "$al_folder" |cut -d/ -f6- | sed -e 's/^/nfs\:\/\/192.168.2.122\/srv\/nfs\/music\//'`
path=`echo "$al_folder"`
thumb4=`echo "$path_nfs/folder.jpg"`
rating=`${sqlhp} "select UserScore from albums where AlbumID = '$album_id'"`
rel_id=`${sqlbeets} "select mb_releasegroupid from albums where mb_albumid = '$album_id'"`
rel_date=`${sqlhp} "select ReleaseDate from albums where AlbumID = '$album_id'"`

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
for n in $(seq `echo "$albums" |wc -l`); do
album=`echo "$albums" |awk -F"|" '{print $1}' | head -$n | tail -1`
year1=`echo "$albums" |awk -F"|" '{print $2}' | head -$n | tail -1`
echo "		<album>" 
echo "      		<title>$album</title>" 
echo "       		 <year>$year1</year>"
echo "		</album>" 
done
echo "	</artist>" 
}

album_info () {
cd "${line}"
if [ -f "album.nfo" ] && [ "`cat album.nfo |grep -F "<track>" | wc -l`" -eq "`echo $tracks_album`" ]; then
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
	album_tracks >> album.nfo
	fi
	}

album_tracks () {
for t in $(seq `echo "$tracks" |wc -l`); do
track=`echo "$tracks" | head -$t |tail -1`
trackid=`echo "$track" |awk -F"|" '{print $2}'`
length=`echo "$track" |awk -F"|" '{print $3}'`
title=`echo "$track" |awk -F"|" '{print $4}'`
position=`echo "$track"|awk -F"|" '{print $1}'`
duration=`date -d@$length -u +%M:%S`
echo "		<track>"
echo "     	   	<musicBrainzTrackID>$trackid</musicBrainzTrackID>"
echo "        		<title>$title</title>"
echo "        		<position>$position</position>"
echo "        		<duration>$duration</duration>"
echo "   	 	</track>"
done
echo "	</album>"
}

echo "processing....[$artistname-$albumname]"
artist_info 
album_info
done < $FILE
