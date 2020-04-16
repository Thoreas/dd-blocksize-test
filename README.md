# dd-blocksize-test
Bash script to determinine the optimal blocksize for usage with 'dd', in both reading and writing.

Run with elevated privileges for optimal results (need to be able to clear kernel cache):
```bash
$ sudo dd-blocksize-test.sh [test_directory]
```

Optional argument `test_directory` points to the location where reading and writing takes place. If not specified, script's location is used.

