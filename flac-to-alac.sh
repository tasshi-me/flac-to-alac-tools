#!/bin/bash

# ------------------------------------------------------
# FLAC to ALAC tool
# (c) 2020 tasshi. All rights reserved.
# ------------------------------------------------------

# init
ECHO=/bin/echo
FFMPEG=/usr/local/bin/ffmpeg
ATOMICPARSLEY=/usr/local/bin/AtomicParsley
INTERACTIVE=0

function show_help () {
  command_name=$(basename "${0}")
  ${ECHO} "Usage: ${command_name} [-h] [-i]" 1>&2
  ${ECHO} "Options:" 1>&2
  ${ECHO} "    -h      -- print basic options" 1>&2
  ${ECHO} "    -i      -- interactive mode" 1>&2
}

# info
${ECHO} "FLAC to ALAC tool Copyright (c) 2020 tasshi"

# parse args
while getopts ih OPT
do
  case $OPT in
    "i" ) INTERACTIVE=1 ;;
    "h" ) show_help ${CMDNAME}; exit 1 ;;
    * ) show_help ${CMDNAME}; exit 1 ;;
  esac
done

shift `expr $OPTIND - 1`

if [ ${INTERACTIVE} -eq 1 ]; then
  ${ECHO} "interactive mode: on"
fi
${ECHO};

# src dir
if [ -n "${1}" ]; then
  src_dir=${1}
else
  if [ ${INTERACTIVE} -eq 0 ]; then
    ${ECHO} "Source directory have to be specified."
    ${ECHO} "Abort."
    exit
  fi
  ${ECHO} "Input source directory (empty to exit)."
  ${ECHO} -n "src dir: "
  read input_src_dir
  ${ECHO};
  if [ -n "${input_src_dir}" ]; then
    src_dir=${input_src_dir}
  else
    ${ECHO} "Abort."
    exit
  fi
fi

# dst dir
parent_dir=$(dirname "${src_dir}")
base_dir=$(basename "${src_dir}")
dst_dir="${parent_dir}/ALAC/${base_dir}"
if [ -n "${2}" ]; then
  dst_dir=${2}
else
  if [ ${INTERACTIVE} -eq 1 ]; then
    ${ECHO} "Input destination directory (empty to use default)."
    ${ECHO} "Default: ${dst_dir}"
    ${ECHO} -n "dst dir: "
    read input_dst_dir
    ${ECHO};
    if [ -n "${input_dst_dir}" ]; then
      dst_dir=${input_dst_dir}
    fi
  fi
fi

# Count FLAC files
${ECHO} "Search FLAC files..."
flac_file_count=($( ls -1UR "${src_dir}" | grep .flac | wc -l ))
${ECHO};
if [ ${flac_file_count} -eq 0 ]; then
  ${ECHO} "FLAC file not found in src dir."
  ${ECHO} "Abort."
  exit
fi

# confirmation
${ECHO} "Convert FLAC files to ALAC"
${ECHO} "------------------------------------------------------"
${ECHO} "src: $src_dir"
${ECHO} "dst: $dst_dir"
${ECHO} "------------------------------------------------------"
${ECHO} "After this operation, ${flac_file_count} files will be converted."

if [ ${INTERACTIVE} -eq 1 ]; then
  ${ECHO} -n "Do you want to continue? [Y/n] "
  read confirmation
  if [ "${confirmation}" != "y" -a "${confirmation}" != "Y" -a "${confirmation}" != "yes" -a "${confirmation}" != "YES" ];then
    ${ECHO} "Abort."
    exit
  fi
fi
${ECHO};

# check if src_dir exists
if [[ ! -d "$src_dir" ]]; then
  ${ECHO} "src_dir not exists. (${src_dir})"
  ${ECHO} "Abort."
  exit
fi

# clone directory tree
mkdir -p "${dst_dir}"
rsync --quiet -avz --include "*/" --exclude "*" "${src_dir}/" "${dst_dir}"

# WIP
#find "${src_dir}" -print|grep flac|sort
# flac_files=($(find "${src_dir}" -type f -print| grep -i flac| sed -e "s/$/\"/g" -e "s/^/\"/g"| sort))
# flac_files=($(find "${src_dir}" -name '*.flac' -print | sort))
# flac_files=()
# while IFS=  read -r -d $'\0'; do
#   flac_files+=("$REPLY")
# done < <(find "${src_dir}" -name '*.flac' -print0)
#for FILE in "${flac_files[@]}"
# for ((i = 0; i < "${#flac_files[@]}"; i++))
# for FILE in ${src_dir}
# flac_files=$(find "${src_dir}" -name '*.flac' -print | sort)
# echo ${flac_files} | while read FILE
#find "${src_dir}" -name '*.flac' -print | while read FILE
# file=$FILE

# covert
flac_files=()
while IFS=  read -r -d $'\0'; do
  flac_files+=("$REPLY")
done < <(find "${src_dir}" -name '*.flac' -print | sort -n | tr '\n' '\0' )

for ((i = 0; i < "${#flac_files[@]}"; i++))
do
  file="${flac_files[i]}"
  echo "src: $file"
  src_file_dir=$(dirname "${file}")
  src_file_basename=$(basename "${file}" .flac)
  src_file_path="${src_file_dir}/${src_file_basename}"
  pattern=$(echo "${src_dir}" |  sed -e 's/\//\\\//g')
  dst_file_relative=$(echo "${src_file_path}" | sed -e "s/${pattern}//g")
  dst_file_path="${dst_dir}${dst_file_relative}"
  
  # convert to flac
  ${FFMPEG} -y -loglevel panic -i "${src_file_path}.flac" -vn -acodec alac "${dst_file_path}.m4a"
  # export thumbnail
  ${FFMPEG} -y -loglevel panic -i "${src_file_path}.flac" "${dst_file_path}.jpg"
  # import thumbnail
  ${ATOMICPARSLEY} "${dst_file_path}.m4a" --artwork "${dst_file_path}.jpg" --overWrite > /dev/null
done
