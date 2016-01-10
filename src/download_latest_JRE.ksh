#!/bin/ksh
# modified from https://github.com/inetquestion/Java-JRE-JDK-Downloader

###################################
## Overview
###################################

# Find the most recent JRE and downloads the OSX tar.gz release
#
# Reference URLS:
# https://gist.github.com/P7h/9741922

###################################
## Usage
###################################

# downloadJavaAutomatic.ksh
# Finds and downloads current Java versions

# downloadJavaAutomatic.ksh [-f <file>]
# Skips version/build find routing, uses external <file>
# which contains a list of URLs to be downloaded.


###################################
## Config
###################################
version=99
build=30

set -A BASE 7
set -A PLATFORMS -- -macosx-x64.tar.gz
set -A TYPE jre

###################################
## Subroutines
###################################

doCountCurl() {
    ps -ef | egrep -ie "curl.*${cookie}" | grep -vi grep | wc -l
}

doGetURL() {
    printf "\n$URL\n"
    Cookie="Cookie:oraclelicense=accept-securebackup-cookie"
    curl -O -L -S -H "${Cookie}" --progress-bar --connect-timeout 55 --fail -k "${1}"
    if [[ $? -ne 0 ]]; then
        echo ERROR - download failed.
    fi
}

doTestURL() {
    uri_local=$1
    base_local=$2
    version_local=$3
    build_local=$4
    platform_local=$5
    type_local=$6

    Cookie="Cookie:oraclelicense=accept-securebackup-cookie"
    URL="http://download.oracle.com/${uri_local}${base_local}u${version_local}-b${build_local}/${type_local}-${base_local}u${version_local}${platform_local}"
    curl --output /dev/null -L -sS -H "${Cookie}" --head --connect-timeout 15 --max-time 30 --fail -k "${URL}" 2>/dev/null
    if [[ $? -eq 0 ]]; then
        echo $URL >> $urlFile
        printf  "$version_local" > $tmpVersion
        printf  "$build_local" > $tmpBuild
        printf  "${URL}" > $tmpFile
        break
    fi
}

doFindVersionBuild() {
    URI=$1
    BASE=$2
    PLATFORM=$3
    TYPE=$4

    ### If available use version to limit tree walking
    if [[ -e $tmpVersion ]]; then
        version_cnt=$(( `cat $tmpVersion` ))
    else
        version_cnt=$version
    fi

    while [[ $version_cnt -ge 1 ]] && [[ ! -e $tmpFile ]]; do

        ### If available use build to limit tree walking
	if [[ -e $tmpBuild ]]; then
            build_cnt=$(( 10 + `cat $tmpBuild` ))
        else
            build_cnt=$build
        fi

        ### Keep going until a version is found
	while [[ $build_cnt -ge 1 ]] && [[ ! -e $tmpFile ]]; do
            ### Limit HTTP connections to avoid saturating connection
	    maxHTTP=50; while [[ `doCountCurl` -ge ${maxHTTP} ]]; do sleep 1; done

            ### Send to background to speed up process
            doTestURL ${URI} ${BASE} ${version_cnt} ${build_cnt} ${PLATFORM} ${TYPE} &
            (( build_cnt-=1 ))
        done

        (( version_cnt -= 1 ));
        sleep 1
    done

    ### Wait for current version/build series to finish before starting next round
    while [[ `doCountCurl` -gt 0 ]]; do sleep 1; done

    ### Save results to VERSION array.  Highest version will be element #1
    set -A VERSION dummy `[[ -e $tmpFile ]] && sort -nr $tmpFile`
    if [[ "${VERSION[1]}" != "" ]]; then
        echo ${VERSION[1]}
    else
        printf -- "${TYPE}-${BASE}u??${PLATFORM} - No Version found.\n"
    fi

    ### Cleanup
    if [[ -e $tmpFile ]]; then
        rm $tmpFile
    else
        [[ -e $tmpVersion ]] && rm $tmpVersion
        [[ -e $tmpBuild ]] && rm $tmpBuild
    fi
}

doDownload() {
    printf "\nDownloading most recent version...\n"
    for URL in $( grep -vi "#" $urlFile | sort | tail -1 ); do
        doGetURL "$URL"
    done
}

#########################
### Main
#########################
tmpFile=$$-tmp.txt
tmpVersion=$$-version.txt
tmpBuild=$$-build.txt
urlFile=url.txt

printf "Searching for available JRE 1.7 releases...\n"

for base in ${BASE[@]}; do
    for type in ${TYPE[@]}; do
        printf "# `date`\n" > $urlFile
        for platform in ${PLATFORMS[@]}; do
            URI=otn-pub/java/jdk/
            doFindVersionBuild ${URI} ${base} ${platform} ${type}
        done
    done
    ### Delete version and build markers before attempting next BASE version.
    [[ -e $tmpVersion ]] && rm $tmpVersion
    [[ -e $tmpBuild ]] && rm $tmpBuild
done
doDownload

rm url.txt
