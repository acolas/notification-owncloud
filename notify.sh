#!/bin/bash
# monitor file changes in a Owncloud directory
# and notify changes (create / update) with sendEmail

#Usage : ./notify.sh /DATA/owncloud/data/acolas/files/ &
if [ "$*" = "" ]; then
 echo "File Monitoring"
 echo "USAGE: $0 <target directory>"
 echo ""
 exit 0
fi

LOGDIR="/var/log/notify/" 
TARGET_DIR="$*"
LOGNAME="$LOGDIR/`date -I`.log"

#example of events to retrieve : 2013-07-06 10:33:30 CLOSE_WRITE,CLOSE /DATA/owncloud/data/acolas/files/sync/Notes 
inotifywait -m -r --format '%T %e %w%f' --timefmt '%F %T' -e close_write -e create -e move $TARGET_DIR | while read date time file
do
echo "$date $time $file" >> $LOGNAME

#build special path with IFS
oldIFS="$IFS"
IFS='/'
ary=($file)
length=${#ary[@]}
chemin="/" 
for key in "${!ary[@]}"
do 
if [[ $key -gt 6 ]] && [[ $key -ne $length-1 ]]
then 
   chemin+="${ary[$key]}/"
fi
done
filename=${ary[length-1]}

#Owncloud add (XX) to the filename when you version it, so we remove it.
nomfichier=$(echo $filename | sed -r 's/ \([0-9]+\)//g')

encodeDirUrl=$(php -r "echo rawurlencode(\"$chemin\");")
encodeFileUrl=$(php -r "echo rawurlencode(\"$nomfichier\");")

#email message for files
message="le répertoire partagé <b>$chemin</b><br><br>Nom du fichier: <b>$nomfichier</b><br><br>URL d'accès au répertoire: https://files.my-owncloud.fr/index.php/apps/files?dir=$encodeDirUrl<br><br>URL de téléchargement du fichier: https://files.my-owncloud.fr/index.php/apps/files/download$encodeDirUrl$encodeFileUrl<br><br>Date et heure: <b>$date</b> à <b>$time</b><br><br>"

#email message for directories
messagerep="le répertoire partagé <b>$chemin</b><br><br>Nom du répertoire: <b>$nomfichier</b><br><br>URL du répertoire: https://files.my-owncloud.fr/index.php/apps/files?dir=$encodeDirUrl$encodeFileUrl<br><br>Date et heure: <b>$date</b> à <b>$time</b><br><br>"

STATUT=""
FLAG=""

#email message according to retrieval inotify event
if [[ "$file" == *CREATE* ]] && [[ "$file" == *ISDIR* ]]
then
  STATUT="<br>Un répertoire a été créé dans $messagerep"
  FLAG="CREATE"
else
	if [[ "$file" == *CREATE* ]]
	then
	  if [[ "$nomfichier" =~ .*\([0-9]+\).*  ]] 
	  then
	        echo $nomfichier | sed -r 's/ \([0-9]+\)//g'	
		STATUT="<br>Un fichier a été mis à jour dans $message"
	  else
	        STATUT="<br>Un nouveau fichier a été créé dans $message" 
	  fi 
	  FLAG="CREATE"
	fi
fi

if [[ "$file" == *CLOSE_WRITE* ]]
then
  STATUT="<br>Un fichier a été modifié dans $message"
  FLAG="CLOSE_WRITE"
fi

if [[ "$file" == *MOVED_FROM* ]]
then
  MOVE="<br>Un fichier a été déplacé de <b>$chemin</b>"
  FLAG="MOVED_FROM"
fi

if [[ "$file" == *MOVED_TO* ]]
then
  STATUT="$MOVE vers $message"
  FLAG="MOVED_FROM"
fi

#we don't want to send email when we receive this event
if [[ "$file" =~ "MOVED_FROM" ]]
then
    oldnomfichier=$nomfichier 
	elif [[ "$OLDFLAG" =~ "CREATE" ]] && [[ "$FLAG" =~ "CLOSE_WRITE" ]] || [[ "$oldnomfichier" =~ .*([0-9]+).* ]]
	then
	   sleep 1 
	else
	sendEmail -q -f sender@gmail.com -t receiver@gmail.com -bcc bcc@gmail.com -u "Notification de changement sur le répertoire $chemin" -m "<html><body>Bonjour,<br>$STATUT<br>Cordialem
	ent.</html>" -s smtp.url.com -o tls=yes -xu accountsmtp@gmail.com -xp passwordsmtp
fi
OLDFLAG=$FLAG;
IFS="$oldIFS"
done
exit 0