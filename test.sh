#!/usr/bin/bash

for nb in *.md; 
do
        if [ "$nb" = "README.md" ] || [ "$nb" = "introduction.md" ] || [ ${nb} = "CHANGES.md" ] ; then 
                continue
        fi 
        nbroot=$(echo "${nb}" | cut -d. -f1)
        echo "Processing ${nbroot}"
        mkdir "${nbroot}.out" || echo "Outdir ${nbroot}.out already exists?"
        cd "${nbroot}.out"
        cp "../${nb}" .
        jupytext --to notebook "${nb}" "${nbroot}.ipynb"
        jupyter nbconvert --to notebook --execute "${nbroot}.ipynb"  > output.log 2>&1 || (echo "Exit Code: $?" | tee -ai output.log)

        cd ..
done
