#!/usr/bin/env bash

if [[ "$(uname -s)" == "FreeBSD" ]]; then
    CORE_NUM=$(sysctl -n hw.ncpu)
else
    CORE_NUM=$(grep -c ^processor /proc/cpuinfo)
fi
USED_CORES=()
TASK_SET_CMD=""

for i in $(seq 0 $CORE_NUM); do
    USED_CORES[i]=0
done

# FreeBSD has no /proc by default: ask cpuset(1) which processes are pinned
# to a single core.
find_free_cores_freebsd() {
    for pid in $(ps -ax -o pid=); do
        # First line is "pid N mask: 0, 1, ..."; a second "domain policy" line follows.
        mask=$(cpuset -g -p "$pid" 2>/dev/null | awk '/^pid [0-9]+ mask: / {sub(/^.*mask: /, ""); print; exit}')
        if [[ "$mask" =~ ^[0-9]+$ ]]; then
            USED_CORES[$mask]=1
        fi
    done
}

find_free_cores() {
    if [[ "$(uname -s)" == "FreeBSD" ]]; then
        find_free_cores_freebsd
        return
    fi
    for FILE in /proc/[0-9]*/status; do
        # echo $FILE
        has_vm=$(cat $FILE | grep 'VmSize:')
        if [[ -z $has_vm ]]; then
            continue
        fi
        allow_list=$(cat $FILE | grep '^Cpus_allowed_list:' | awk '{print $NF}')
        # echo $allow_list
        if [[ $allow_list == *,* ]]; then
            #echo "has ,"
            continue
        fi
        if [[ $allow_list == *-* ]]; then
            # echo "has -"
            continue
        fi
        # FREE_CORES+=($allow_list)
        # echo "$allow_list is used"
        USED_CORES[$allow_list]=1
    done
}

find_core_for_task_set() {
    if [[ ! -z "${DOCKER_RUNNING:-}" ]]; then
        return
    fi
    find_free_cores
    echo "free cores: ${USED_CORES[@]}"

    for i in $(seq 0 $CORE_NUM); do
        if [ "${USED_CORES[$i]}" -eq "0" ]; then
            echo "core $i is free, set task to it"
            if [[ "$(uname -s)" == "FreeBSD" ]]; then
                TASK_SET_CMD="cpuset -l $i"
            else
                TASK_SET_CMD="taskset -c $i"
            fi
            break
        fi
    done
}
