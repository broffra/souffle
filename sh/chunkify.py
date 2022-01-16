#!/usr/bin/env python3

import sys

n_tests, n_chunks, chunk_id = map(int, sys.stdin.readline().split())
d, m = divmod(n_tests, n_chunks)
print(f"{chunk_id * d + min(m, chunk_id) + 1},{(chunk_id+1) * d + min(m, chunk_id+1)}")
