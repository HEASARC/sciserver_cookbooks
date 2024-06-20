#!/usr/bin/bash

for nb in *.md; 
do
    if [ "$nb" = "README.md" ] || [ "$nb" = "introduction.md" ] || [ ${nb} = "CHANGES.md" ] ; then 
        continue
    fi 
    nbroot=$(echo "${nb}" | cut -d. -f1)
    printf "================\nProcessing ${nbroot}\n"
    date
    if [ ! -d "${nbroot}.out" ]; then
        mkdir "${nbroot}.out"
    fi
    cd "${nbroot}.out"
    if [ -f "00_success" ]; then
        echo "Found previous successful run;  skipping" 
        cd ..
        continue
    elif [ -f "00_failure" ]; then 
        echo "Found previous failed run;  skipping" 
        cd ..
        continue
    fi
    cp "../${nb}" . || (echo "Cannot find ../${nb}; exiting" ; exit 1)
    jupytext --execute --to notebook "${nb}" "${nbroot}.ipynb" > output.log 2>&1 || (echo "ERROR:  Exit Code: $?" ; tail output.log ; touch 00_failure; exit 1)
    touch 00_success
    cd ..
done
date
echo "\n============\nDone"
