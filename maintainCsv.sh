#!/bin/bash

function showhelp() {
   cat << EOF

Params:
[-f FILENAME][-m MergeFromFile | -g | -p PARAM -i ID][-s][-h][-d]
= = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =

-f FILENAME      Name or path to CSV file
-m MergeFromFile   csv file to merge. suggesting to add -s
-g         Guided Mode (Text only)
-i         ID(s) to work with. Separated with ','
-p         Either Anton or Theo; d to remove line.
-s         Silent mode.
-h         This nice text.

Nothing         Starts GUIDED mode.
-d         Writes down a Dummy for testing purpose.

EOF
}

# Optional TODOs:
# dd for writing - Faster, File datetime...
# create Error-function (echo and returncode)
# TUI?
# $linesDummy as optarg, but it's only for testing.

if [  ${BASH_VERSION%%[^0-9]*} != 4 ]; then
   echo;echo "Needs Bash 4.x"
   echo "Current is $BASH_VERSION";echo
   exit 1
fi

mergefrom="";tochange="";changeto="" #We don't need to "declare" them. They are here in order to illustrate the scope.
mainfile="toEdit.csv"
silent=0
mode="GUIDED" #TUI, MERGE, GUIDED, ARGS // TUI isn't here yet.
linesDummy=100

declare -A current
declare -A toadd

function main() {
   if [ ! -f $mainfile ]; then
      echo "File $mainfile does not exist!"
      echo "Please create one or give me the right name. I could touch it, but I wont."
      exit 1
   else
      #Read CSV to an associative array.
      parseCSV $mainfile current
   fi

   #The modes can be extended individually
   case $mode in 
      TUI)
         #StartTUI
      ;;
      MERGE)
         if [ ! -f $mergefrom ]; then   
            echo "File $mergefrom does not exist!"
            exit 1
         fi
         parseCSV $mergefrom toadd
         mergeArrs
         writeCSV
         #That's it.
      ;;
      GUIDED)
         echo "Welcome to the guided editor!"
         read -p "First, please tell me the 9 digit alphanum ID to edit: " -r; echo
         if [[ "$REPLY" =~ [^a-z0-9] ]] || [ ${#REPLY} != 9 ]; then
            echo "Wrong format for ID. Exiting."
            exit 1
         else
            tochange="$REPLY"
            read -p "Now, please give me the one-letter Value shortcuts:" -n 1 -r changeto; echo
            normalizeVal
            toadd["$tochange"]="$changeto"
            mergeArrs
            writeCSV
         fi
      ;;
      ARGS)
         if [ -z "$tochange" ] || [ -z "$changeto" ]; then
            echo "Im missing some information about what to change to which value."
            echo "Use -h for help."
            exit 1
         fi
         normalizeVal
         #This allows to touch multiple ID-lines
         arr=$(echo $tochange | tr "," "\n")
         local added=0
         for x in $arr
         do
            isThere=1
            #We only take alphanum 9 chars.
            if [[ "$x" =~ [^a-z0-9] ]] || [ ${#x} != 9 ]; then
               echo;echo "ID $x is invalid! exp.: alphanum, 9 chars."
               echo "Ignoring."
               #exit 1
            else
               toadd["$x"]="$changeto"
               added=1
            fi
         done
         if [ $added == 1 ]; then
            mergeArrs
            writeCSV
         fi
      ;;
   esac
}

#parseCSV Args: $1:File-To-Read, $2:Varname-To-Write
function parseCSV() {
   local towrite=$2
   local IFS=","
   while read id val
   do
      if ! ( [ -z "$id" ] || [ -z "$val" ] ); then eval $towrite["$id"]="$val"; fi
   done < $1
}

function normalizeVal(){
   #We don't want the arguments to be case-sensitive (Wortspiel)
   #Simply extend this case to add more possible values.
   case "${changeto,,}" in
      a|anton) changeto="ASAP.xml";;
      t|theo) changeto="Tcap.xml";;
      d|delete) changeto="";;
      *)
         echo "Please use one of the predefined values. Use -h for help."
         exit 1
      ;;
   esac
}

#mergeArrs doesn't take arguments because there are problems iterating through a "pointed" associative array.
function mergeArrs() {
   for x in "${!toadd[@]}"
   do
      if [ -z "${current[$x]}" ] || [ $silent == 1 ]; then
         current["$x"]=${toadd[$x]}
      elif [ "${current[$x]}" == "${toadd[$x]}" ]; then
         echo "$x is already ${toadd[$x]}."
      else
         if [ -z "${toadd[$x]}" ]; then
            targ="Should I delete $x which is ${current[$x]}? (Y/N)"
         else
            targ="Should I overwrite $x which is ${current[$x]} with ${toadd[$x]}? (Y/N)"
         fi
         read -p "$targ" -n 1 -r; echo
         if [[ $REPLY =~ ^[Yy]$ ]]; then current["$x"]=${toadd[$x]}; fi
      fi
   done
}

#This could be well done with dd, but only if the line length doesn't change with different values.
function writeCSV() {
   if [ $silent == 0 ]; then echo "Writing to disk..."; fi
   rm $mainfile
   lines=0
   for x in "${!current[@]}"
   do
      #If current[$x] is still a zero string, user wants it to go away.
      if [ ! -z "${current[$x]}" ]; then
         echo "$x,${current[$x]}">>$mainfile
         #since the format is very simple, we are just echoing an interpolated string to our mainfile.
         lines=$((lines+1))
      fi
   done
   echo "Result has $lines entries."
}


#retrieving arguments
while getopts :df:m:gi:p:sh opts; do
    case ${opts} in
      h) showhelp; exit 0;;
      f) mainfile=${OPTARG};;
      m) mergefrom=${OPTARG}; mode="MERGE";;
      g) mode="GUIDED";;
      i) mode="ARGS"; tochange=${OPTARG};;
      p) mode="ARGS"; changeto=${OPTARG};;
      s) silent=1;;
      d)
         #this is a quick solution for testing purposes
         echo "Generating Dummy Data... (not so fast)"
         for i in `seq 1 $linesDummy`
         #for i in 'seq 1 ${OPTARG}'
         do
            #rand string comes from https://gist.github.com/earthgecko/3089509
            tmprand="$(cat /dev/urandom | tr -dc 'a-z0-9' | fold -w 9 | head -n 1)"

            if [ $(( $RANDOM % 2 )) == 0 ]; then
               changeto="Anton"
            else
               changeto="Theo"
            fi
            current["$tmprand"]="$changeto"
         done
         if [ ! -f $mainfile ] || [ $silent == 1 ]; then
            writeCSV
         else
            read -p "$mainfile is already existing. Should I overwrite? (Y/N)" -n 1 -r;echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then writeCSV; fi
         fi
         exit 0
      ;;
      *) 
         echo "Ignoring invalid option ${opts}!"
      ;;
    esac
done

main

echo
