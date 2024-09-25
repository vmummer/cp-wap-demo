# 2024 - Check Point Software - WAF LAB
# cp_api_trainer.sh 
# The following script was created to train the WAF API to learn the API Scheme of VAMPI application to demontrate
# the auto learning
# Write by Vince Mammoliti - vincem@checkpoint.com
# Version 0.5  - Sept 25, 2024
#
#/usr/bin/bash

set -euo pipefail

declare vResponse='silentResponse'   # This is method for creating verbose debug info. When more verbose is required this will be set to the 'echo' command
function silentResponse () {
       	:
}

VFLAG=0
REPEAT=1
HOST="http://juiceshop.local:8500"
DOCKER_HOST="`hostname -I| awk ' {print $1}'`"
LINE=10
CHAR=$(( 80 * $LINE))
RED='\033[0;31m'
NC='\033[0m' # No Color
BFLAG=0
SFLAG=0	

usage(){
>&2 cat << EOF
$0 is an API training tool to demonstrate the API learning capability of the Check Point Cloud Guard WAF
Written by Vince Mammoliti - vincem@checkpoint.com - Sept 2024

Usage: $0 [OPTIONS...] [URL of VAMPI host - defaults to $HOST] 
  -v | --verbose             provides details of commands excuited against host  
  -m | --malicious           send malicious type traffic (Default will be know good training traffic)
  -r | --repeat              repeat the number of times to send api training requests. defaults to 1 
  -s | --sql		     uses sqlmap to attempt to dump database
  -h | --help                this help screen is displayed
EOF
exit 1
}

gettoken(){
TOKEN=$(curl -sS -X POST   ${HOST}/users/v1/login   -H 'accept: application/json' \
	                  -H 'Content-Type: application/json'  \
                          -d '{ "password": "pass1", "username": "admin" }' \
			   | jq -r '.auth_token')		       
return 0
} 

sqldump(){
# The follow was removed because sqlmap was added to the tester container to run
#if ! [ -x "$(command -v sqlmap)" ]; then
#	        echo "sqlmap is not installed - please install 'apt-get install sqlmap'" >&2
#		        exit 1
#f
$vResponse "HOST: ${HOST}"
gettoken
#sqlmap -u ${HOST}"/users/v1/*name1*" --method=GET --headers="Accept: application/json\nAuthorization: Bearer $TOKEN \nHost: ${TOKEN} " --dbms=sqlite --dump

docker run -it --rm --add-host juiceshop.local:$DOCKER_HOST appsec-demo-test-host sqlmap -u $HOST"/users/v1/*name1*" --method=GET --headers="Accept: a
pplication/json\nAuthorization: Bearer $TOKEN \n
Host: ${TOKEN} " --dbms=sqlite --dump --batch

exit 0
}

ifblocked(){
  if echo "$OUTPUT" |  grep -q -o -P '.{0,20}Application Security.{0,4}'; then
        echo -e "${RED}Check Point - Application Security Blocked ${NC}"
  fi
}


traffic_bad(){
if [ ! -z "$@" ]; then     # Check to see if there is a URL on the command, if so replace
		         HOST=$@
fi
$vResponse "REPEAT: ${REPEAT}" 
echo -e "\n WAF API - Training Traffic - Simulator - $0 -h for options \n"
echo -e " Sending Malicious API Traffic"

for (( i=0; i < $REPEAT ; ++i));
do
  loop=$(($i+1))
  echo "Loop: $loop"
  gettoken
  # Create a Bad Book Lookup
  echo "1) Send a bad book lookup - sending /books/v1/cp-GCWAF-102x "
  OUTPUT=$(curl -sS -X GET  ${HOST}/books/v1/cp-GCWAF-102x   -H 'accept: application/json'  -H "Authorization: Bearer $TOKEN" )
  ifblocked
  $vResponse -e ${OUTPUT:0:$CHAR} "\n"

  #Create and account attact "user1'"
  echo "2) Send an attempt to exploit account - send /users/v1/user1' "
  OUTPUT=$(curl -sS -X GET "${HOST}/users/v1/user1'"  -H 'Content-Type: application/json' \
               -H "Authorization: Bearer $TOKEN"
                )
  ifblocked
  $vResponse -e ${OUTPUT:0:$CHAR} "\n"


  #Create and account attact /users/v1/_debug'"
  echo "3) Send an attempt to exploit of developer testing tool send /users/v1/_debug "
  OUTPUT=$(curl -sS -X GET "${HOST}/users/v1/_debug"  -H 'Content-Type: application/json' \
         -H "Authorization: Bearer $TOKEN"
               )
  ifblocked
  $vResponse -e ${OUTPUT:0:$CHAR} "\n"
done
exit 1
}

args=$(getopt -a -o vr:sm --long help,verbose,repeat:,sql,malicious -- "$@")



#if [[ $? -gt 0 ]]; then
#if [[ $# -eq 0 ]]; then
#  usage
#fi

eval set -- ${args}
while :
do
  case $1 in
	-v | --verbose)   VFLAG=1 ; vResponse='echo' ; shift   ;;
	-h | --help)      usage   ; shift   ;;
	-r | --repeat)    REPEAT=$2  ; shift 2 ;;
	-s | --sql )      SFLAG=1 ; shift  ;;
	-m | --malicious)       BFLAG=1  ; shift ;; 
	--) shift; break ;;
	 *)   usage; exit 1 ;;
   esac
done

if [ ! -z "$@" ]; then     # Check to see if there is a URL on the command, if so replace
	 HOST=$@
fi

echo "HOST: ${HOST}"
$vResponse "BFLAG: ${BFLAG}"

if [ $BFLAG -eq  1 ]; then 
	traffic_bad
	exit 1
elif [ $SFLAG -eq 1 ] ; then
	sqldump
	exit 1
else 
echo -e "\n WAF API - Training Traffic - Simulator - $0 -h for options \n"
for (( i=0; i < $REPEAT ; ++i));
do
   loop=$(($i+1))
   echo "Loop: $loop"
   OUTPUT=$(curl -sS -H 'accept: application/json' -X 'GET' ${HOST}/)
   echo "1) GET /"; $vResponse $OUTPUT ; # If -v is enabled - prints out result of curl
   OUTPUT=$(curl -sS -H 'accept: application/json' -X 'GET' ${HOST}/books/v1)
   echo "2) GET /books/v1"; $vResponse $OUTPUT
   OUTPUT=$(curl -sS -H 'accept: application/json' -X 'GET' ${HOST}/users/v1)
   echo "3) GET /users/v1"; $vResponse $OUTPUT
   TOKEN=$(curl -sS -X POST   ${HOST}/users/v1/login   -H 'accept: application/json' \
	        -H 'Content-Type: application/json'  \
			-d '{ "password": "pass1", "username": "name1" }' \
				| jq -r '.auth_token')
   echo "4) POST /user/v1/login" ; $vResponse $OUTPUT 
   OUTPUT=$(curl -sS -H 'accept: application/json' -X 'GET' ${HOST}/users/v1/admin)
   echo "5) GET /users/v1/admin" ; $vResponse $OUTPUT
   OUTPUT=$(curl -sS -X 'POST'   ${HOST}/books/v1   -H 'accept: application/json' -H 'Content-Type: application/json'          -d '{
               "book_title": "cp-GCWAF-102",
               "secret": "cp-secret"
             }' -H "Authorization: Bearer $TOKEN "
	   )
   echo "6) POST /books/v1 - new book added"; $vResponse $OUTPUT  
   OUTPUT=$(curl -sS -X GET  ${HOST}/books/v1/cp-GCWAF-102   -H 'accept: application/json'  -H "Authorization: Bearer $TOKEN" )
   echo "7) books/v1/cp-GCWAF-102 - book details"; $vResponse $OUTPUT
#   OUTPUT=$(curl -sS -X GET  ${HOST}/books/v1/cp-GCWAF-102x   -H 'accept: application/json'  -H "Authorization: Bearer $TOKEN" )
#   echo "8) books/v1/cp-GCWAF-102x - bad book lookup "; $vResponse $OUTPUT
   OUTPUT=$(curl -sS -X 'POST'   ${HOST}/users/v1/register   -H 'accept: application/json' -H 'Content-Type: application/json'          -d '{
  			"email": "user@cpcgwaf.com",
    			"password": "pass1",
      			"username": "cgwaf2"
		      }'
	  )
   echo "9) POST /users/v1/register - add a new users "; $vResponse $OUTPUT
   OUTPUT=$(curl -sS -X PUT   ${HOST}/users/v1/cgwaf2/email   -H 'accept: */*' -H 'Content-Type: application/json' \
	 -d '{
          	"email": "use3@cp.com"
	     }' -H "Authorization: Bearer $TOKEN"
	  )
   echo "10) GET /users/v1/cpgwaf2/email - update email of user "; $vResponse $OUTPUT
   OUTPUT=$(curl -sS -X DELETE   ${HOST}/users/v1/cgwaf2  -H 'Content-Type: application/json' \
		               -H "Authorization: Bearer $TOKEN"
           )
   echo "11) DELETE /users/v1/cgwaf2 "; $vResponse $OUTPUT
   TOKEN=$(curl -sS -X POST   ${HOST}/users/v1/login   -H 'accept: application/json' \
	         -H 'Content-Type: application/json'  \
		         -d '{ "password": "pass1", "username": "admin" }' \
			         | jq -r '.auth_token')
   echo "12) POST /user/v1/login - login as admin user"
   OUTPUT=$(curl -sS -X DELETE   ${HOST}/users/v1/cgwaf2  -H 'Content-Type: application/json' \
                 -H "Authorization: Bearer $TOKEN"
                )
   echo "11) DELETE /users/v1/cgwaf2 - as an admin user"; $vResponse $OUTPUT


done
fi
exit 0



