for branch in `git branch -r --merged | grep -v HEAD`;do echo -e `git log --no-merges -n 1 --format="%ci, %cr, %an, %ae, "  $branch | head -n 1` \\t$branch; done | sort -r > stalebranches.csv
