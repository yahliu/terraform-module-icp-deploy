#!/bin/bash
LOGFILE=/tmp/loadimage.log
exec  > $LOGFILE 2>&1

echo "Got first parameter $1"
echo "Second parameter $2"
echo "Third parameter $3"
image=$1
image_file=$2
image_location=$3
sourcedir=/opt/ibm/cluster/images

source /tmp/icp-bootmaster-scripts/functions.sh


# Figure out the version
# This will populate $org $repo and $tag
parse_icpversion ${image}
echo "registry=${registry:-not specified} org=$org repo=$repo tag=$tag"

if [[ "${image_location}" != "false" ]]
then
  # Decide which protocol to use
  if [[ "${image_location:0:3}" == "nfs" ]]
  then
    # Separate out the filename and path
    nfs_mount=$(dirname ${image_location:4})
    image_file="${sourcedir}/$(basename ${image_location})"
    sudo mkdir -p ${sourcedir}
    sudo chown $(whoami):$(whoami) -R ${sourcedir}
    # Mount
    sudo mount.nfs $nfs_mount $sourcedir
  elif [[ "${image_location:0:4}" == "http" ]]
  then
    # Figure out what we should name the file
    filename="ibm-cloud-private-x86_64-${tag%}.tar.gz"
    sudo mkdir -p ${sourcedir}
    sudo chown $(whoami):$(whoami) -R ${sourcedir}
    sudo wget --continue -O ${sourcedir}/${filename} "${image_location#http:}"
    image_file="${sourcedir}/${filename}"
  fi
fi
nfs_mount=`mount | grep $sourcedir | wc -l`
if [[ ${nfs_mount} == 1 ]]
then
  sudo tar xf ${image_file} -O | sudo docker load
else
  # If we don't have an image locally we'll pull from docker registry
  if [[ -z $(docker images -q ${registry}${registry:+/}${org}/${repo}:${tag}) ]]; then
    # If this is a private registry we may need to log in
    if [[ ! -z "$username" ]]; then
      sudo docker login -u ${username} -p ${password} ${registry}
    fi
    # ${registry}${registry:+/} adds <registry>/ only if registry is specified
    sudo docker pull ${registry}${registry:+/}${org}/${repo}:${tag}
  fi
fi
