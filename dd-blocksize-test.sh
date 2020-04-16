#!/bin/bash

# Since we're dealing with dd, abort if any errors occur
set -e

# Block sizes to test
# 512b 1K 2K 4K 8K 16K 32K 64K 128K 256K 512K 1M 2M 4M 8M 16M 32M 64M 128M 256M
BLOCK_SIZES="512 1024 2048 4096 8192 16384 32768 65536 131072 262144 524288 1048576 2097152 4194304 8388608 16777216 33554432 67108864 134217728 268435456"
# Test file name
TEST_FILE="$(basename $0 .sh).testfile"
# Size of test file is 2*MAX(BLOCK_SIZES)
TEST_FILE_SIZE=$(($(echo "$BLOCK_SIZES" | tr " " "\n" | sort -nr | head -n1)*2))
# Maximum number of transfers dd can make. Smaller value = faster but more inaccurate. Default = 30
MAX_COUNT=30

# Check if argument is folder, user argument as source/destination, otherwise use current folder
if [ -d "$1" ]; then
  TARGET_FOLDER=$1
else
  TARGET_FOLDER=$(pwd)
fi

# Test if file already exists
if [ -e "$TARGET_FOLDER/$TEST_FILE" ] ; then
  echo "Test file $TARGET_FOLDER/$TEST_FILE exists, aborting."
  exit 1
fi

# Check if root, show warning if not
if [ $EUID -ne 0 ] ; then
  echo "WARNING: Kernel cache will not be cleared between tests. This will likely cause inaccurate results."
  echo "To avoid this, use the following:"
  echo "    $ sudo $0"
  echo ""
fi

# Info
echo "Sit back and relax, this script can run for a long time :)"
echo ""

# Create test file
echo -n "Generating test file..."
BLOCK_SIZE=8192
COUNT=$(($TEST_FILE_SIZE / $BLOCK_SIZE))
dd if=/dev/zero of=$TARGET_FOLDER/$TEST_FILE bs=$BLOCK_SIZE count=$COUNT conv=fsync > /dev/null 2>&1
echo " done."
echo ""

# Header
echo "READ"
PRINTF_FORMAT="%12s : %10s\n"
printf "$PRINTF_FORMAT" "block size" "transfer rate"

# Perform optimal read block size test
for BS in $BLOCK_SIZES
do
  # Clear kernel cache, if able
  [ $EUID -eq 0 ] && [ -e /proc/sys/vm/drop_caches ] && echo 3 > /proc/sys/vm/drop_caches

  # Read test file out to /dev/null with specified block size
  COUNT=$(echo "$(($TEST_FILE_SIZE / $BS)) $MAX_COUNT" | tr " " "\n" | sort -n | head -n1)
  DD_RESULT=$(dd if=$TARGET_FOLDER/$TEST_FILE of=/dev/null bs=$BS count=$COUNT 2>&1 1>/dev/null)
  
  # Extract and print transfer rate
  TRANSFER_RATE=$(echo $DD_RESULT | awk {' print $(NF-1) " " $NF '})
  BS_PRETTY=$BS
  if [ "$BS_PRETTY" -gt "1000" ] ; then
    BS_PRETTY=$(($BS_PRETTY / 1024))
    if [ "$BS_PRETTY" -gt "1000" ] ; then
      BS_PRETTY="$(($BS_PRETTY / 1024))M"
    else
      BS_PRETTY="${BS_PRETTY}k"
    fi
  fi  
  printf "$PRINTF_FORMAT" "$BS_PRETTY" "$TRANSFER_RATE"
done
echo ""

# Cleanup
echo -n "Removing test file..."
rm -f $TARGET_FOLDER/$TEST_FILE
echo " done."
echo ""

# Header
echo "WRITE"
printf "$PRINTF_FORMAT" "block size" "transfer rate"

# Perform optimal write block size test
for BS in $BLOCK_SIZES
do
  # Clear kernel cache, if able
  [ $EUID -eq 0 ] && [ -e /proc/sys/vm/drop_caches ] && echo 3 > /proc/sys/vm/drop_caches

  # Write from /dev/zero to test file with specified block size
  COUNT=$(echo "$(($TEST_FILE_SIZE / $BS)) $MAX_COUNT" | tr " " "\n" | sort -n | head -n1)
  DD_RESULT=$(dd if=/dev/zero of=$TARGET_FOLDER/$TEST_FILE bs=$BS count=$COUNT conv=fsync 2>&1 1>/dev/null)

  # Extract and print transfer rate
  TRANSFER_RATE=$(echo $DD_RESULT | awk {' print $(NF-1) " " $NF '})
  BS_PRETTY=$BS
  if [ "$BS_PRETTY" -gt "1000" ] ; then
    BS_PRETTY=$(($BS_PRETTY / 1024))
    if [ "$BS_PRETTY" -gt "1000" ] ; then
      BS_PRETTY="$(($BS_PRETTY / 1024))M"
    else
      BS_PRETTY="${BS_PRETTY}k"
    fi
  fi
  printf "$PRINTF_FORMAT" "$BS_PRETTY" "$TRANSFER_RATE"
  rm -f $TARGET_FOLDER/$TEST_FILE
done
echo ""

