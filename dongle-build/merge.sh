set -e
cd /w/kbuild/android-3.18
git config --global --add safe.directory '*'
git config --global user.email k@k; git config --global user.name k
B=$(cat /w/kbuild/android-base.txt)
rm -rf /k/merge; git worktree prune
git worktree add --detach /k/merge $B > /k/merge.log 2>&1
cd /k/merge
git merge --no-edit b1240304433 >> /k/merge.log 2>&1 || true
grep -rl "^<<<<<<< " --include=*.[chS] --include=Makefile --include=Kconfig . > /k/conflicts.txt || true; cat /k/conflicts.txt
true
sed -n 1,4p Makefile
