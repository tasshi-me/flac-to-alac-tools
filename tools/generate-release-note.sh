#!/bin/bash
pkg_version=$(cat .version)
RELEASE_NOTES_DIR=docs/release-notes
set -o noclobber

mkdir -p ${RELEASE_NOTES_DIR}
cat << EOS > ${RELEASE_NOTES_DIR}/${pkg_version}.md
# Release v${pkg_version} :tada:

## Changes in this Release

- Write changes in this release
- hoge
- fuga

EOS