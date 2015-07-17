#! /bin/bash
# -x

# == delete_oldest
#
# Used to clean up the oldest files and folders in a specific folder.
#
# === Example (Deletes all but the newest 5 files in /var/log/httpd)
#
# ./delete_oldest.sh -p /var/log/httpd -k 5
#

STATE_OK=0
STATE_WARNING=1
STATE_CRITICAL=2
STATE_UNKNOWN=3
STATE_DEPENDENT=4
null="NULL"

usage()
{
cat >&2 <<EOUSAGE
    Deletes items in a specific folder based on age, keeping the number of files
    specified in the -k argument.

    Usage: $0 -p <path> -k <number>
    -p <path>   The path to the directory to clean.
    -k <number> The number of files to keep.
EOUSAGE
exit $STATE_CRITICAL
}

while getopts ":p:k:" o; do
    case "${o}" in
        p)
            p=${OPTARG}
            ;;
        k)
            k=${OPTARG}
            ;;
        *)
            usage
            ;;
    esac
done
shift $((OPTIND-1))

# Arguments weren't specified at all or are invalid
if [ -z "${p}" ] && [ -z "${k}" ]; then
    usage
fi

# Check $p input
if [ -z "${p}" ] || [ ! -d "${p}" ]; then
    echo "ERROR: Path not specified or does not exist."
    usage
fi

# Check $k input
if [[ $k != *[!0-9]* ]]; then
    echo "Processing... saving at most ${k} files in ${p}."
else
    echo "ERROR: -k option is non-numeric."
    usage
fi

NUMBER_OF_FILES_TO_SAVE=$k

NUMBER_OF_FILES=$(find ${p} -mindepth 1 -maxdepth 1 -printf x |wc -c)
if [ -z "${NUMBER_OF_FILES+xxx}" ]; then
    echo "ERROR: Couldn't calculate number of items in the folder."
    exit $STATE_CRITICAL
fi
if [ -z "$NUMBER_OF_FILES" ] && [ "${NUMBER_OF_FILES+xxx}" = "xxx" ]; then
    echo "ERROR: The number of files in the folder is blank."
    exit $STATE_CRITICAL
fi

case $NUMBER_OF_FILES in
    ''|*[!0-9]*) NUMBER_OF_FILES="NULL" ;;
    *) NUMBER_OF_FILES_isnumeric=true ;;
esac

if [ $NUMBER_OF_FILES != $null ]; then
    echo "Found $NUMBER_OF_FILES in ${p}."
else
    echo "ERROR: The number of items in the folder returned is non-numeric."
    exit $STATE_CRITICAL
fi

if (( $NUMBER_OF_FILES > $NUMBER_OF_FILES_TO_SAVE )); then
    echo "Number of files (${NUMBER_OF_FILES}) vs number of files to save (${NUMBER_OF_FILES_TO_SAVE})"
    counter=0
    while IFS= read -r -d '' -u 9
    do
        let ++counter
        if [[ counter -gt $NUMBER_OF_FILES_TO_SAVE ]]; then
            path="${REPLY#* }" # Remove the modification time
            # echo -e "rm: $path" # Test
            /bin/rm -v -- "$path"
        fi
    done 9< <(find "${p}" -mindepth 1 -maxdepth 1 -printf '%TY-%Tm-%TdT%TH:%TM:%TS %p\0' | sort -rz) # Find and sort by date, newest first

else
    echo "The number of items in ${p} is under the limit (${NUMBER_OF_FILES})."
fi

