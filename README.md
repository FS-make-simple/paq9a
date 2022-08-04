`ORG.FSMS:`
![GitHub release (latest by date)](https://img.shields.io/github/v/release/FS-make-simple/paq9a)
![GitHub Release Date](https://img.shields.io/github/release-date/FS-make-simple/paq9a)
![GitHub repo size](https://img.shields.io/github/repo-size/FS-make-simple/paq9a)
![GitHub all releases](https://img.shields.io/github/downloads/FS-make-simple/paq9a/total)
![GitHub](https://img.shields.io/github/license/FS-make-simple/paq9a)  

# paq9a archiver
Dec. 31, 2007 (C) 2007, Matt Mahoney

## LICENSE

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License as
published by the Free Software Foundation; either version 3 of
the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
General Public License for more details at
Visit <http://www.gnu.org/copyleft/gpl.html>.

## Intro

`paq9a` is an experimental file compressor and archiver.

## Usage
```sh
 paq9a {a|x|l} archive [[-opt] files...]...
```
Commands:
```
 a = create archive and compress named files.
 x = extract from archive.
 l = list contents.
```
Archives are "solid". You can only create new archives. You cannot
modify existing archives. File names are stored and extracted exactly as
named when the archive is created, but you have the option to rename them
during extraction. Files are never clobbered.

The "a" command creates a new archive and adds the named files.
Wildcards are permitted if compiled with g++. Options
and filenames may be in any order. Options apply only to filenames
after the option, and override previous options.
Options are:
```
 -s = store without compression.
 -c = compress (default).
 -1 through -9 selects memory level from 18 MB to 1.5 GB Default is -7
   using 405 MB. The memory option must be set before the first file.
   Decompression requires the same amount of memory.
```
For example:
```
 paq9a a foo.paq9a a.txt -3 -s b.txt -c c.txt tmp/d.txt /tmp/e.txt
```
creates the archive foo.paq9a with 5 files. The file b.txt is
stored without compression. The other 4 files are compressed
at memory level 3. Extraction requires the same memory as compression.

If any named file does not exist, then it is omitted from the archive
with a warning and the remaining files are added. An existing
archive cannot be overwritten. There must be at least one filename on
the command line.

The "x" command extracts the archive contents, creating files exactly
as named when the archive was created. Files cannot be overwritten.
If a file already exists or cannot be created, then it is skipped.
For example, "tmp/d.txt" would be skipped if either the current
directory does not have a subdirectory tmp, or tmp is write
protected, or tmp/d.txt already exists.

If "x" is followed by one or more file names, then the output files
are renamed in the order they were added to the archive and any remaining
contents are extracted without renaming.
For example:
```sh
 paq9a x foo.paq9a x.txt y.txt
```
would extract a.txt to x.txt and b.txt to y.txt, then extract c.txt, 
tmp/d.txt and /tmp/e.txt. If the command line has more filenames than
the archive then the extra arguments are ignored. Options are not
allowed.

The "l" (letter l) command lists the contents. Any extra arguments
are ignored.

Any other command, or no command, displays a help message.

## ARCHIVE FORMAT
```
 "lPq" 1 mem [filename {'\0' mode usize csize contents}...]...
```
The first 4 bytes are "lPq\x01" (1 is the version number).

`mem` is a digit '1' through '9', where '9' uses the most memory (1.5 GB).

A file is stored as one or more blocks. The filename is stored
only in the first block as a NUL terminated string. Subsequent
blocks start with a 0.

The mode is 's' if the block is stored and 'c' if compressed.

`usize` = uncompressed size as a 4 byte big-endian number (MSB first).

`csize` = compressed size as a 4 byte big-endian number.

The contents is copied from the file itself if mode is 's' or the
compressed contents otherwise. Its length is exactly csize bytes.

## COMPRESSED FORMAT

Files are preprocessed with LZP and then compressed with a context
mixing compressor and arithmetic coded one bit at a time. Model
contents are maintained across files.

The LZP stage predicts the next byte by matching the current context
(order 12 or higher) to a rotating buffer. If a match is found
then the next byte after the match is predicted. If the next byte
matches the prediction, then a 1 bit is coded and the context is extended.
Otherwise a 0 is coded followed by 8 bits of the actual byte in MSB to 
LSB order.

A 1 bit is modeled using the match length as context, then refined
in 3 stages using sucessively longer contexts. The predictions are 
adjusted by 2 input neurons selected by a context hash with the second 
input fixed.

If the LZP prediction is missed, then the literal is coded using a chain
of predicions which are mixed using neurons, where one input is the
previous prediction and the second input is the prediction given the
current context. The current context is mapped to an 8 bit state
representing the bit history, the sequence of bits previously observed
in that context. The bit history is used both to select the neuron
and is mapped to a prediction that provides the second input. In addition,
if the known bits of the current byte match the LZP incorrectly predicted
byte, then this fact is used to select one of 2 sets of neurons (512 total).

The contexts, in order, are sparse order-1 with gaps of 3, 2, and 1
byte, then orders 1 through 6, then word orders 0 and 1, where a word
is a sequenece of case insensitive letters (useful for compressing text).
Contexts longer than 1 are hashed. Order-n contexts consist of a hash
of the last n bytes plus the 0 to 7 known bits of the current byte.
The order 6 context and the word order 0 and 1 contexts also include
the LZP predicted byte.

All mixing is in the logistic or "stretched" domain: stretch(p) = ln(p/(1-p)),
then "squashed" by the inverse function: squash(p) = 1/(1 + exp(-p)) before
arithmetic coding. A 2 input neuron has 2 weights (w0 and w1)
selected by context. Given inputs x0 and x1 (2 predictions, or one
prediction and a constant), the output prediction is computed:
p = w0*x0 + w1*x1. If the actual bit is y, then the weights are updated
to minimize its coding cost:
```
 error = y - squash(p)
 w0 += x0 * error * L
 w1 += x1 * error * L
```
where L is the learning rate, normally 1/256, but increased by a factor
of 4 an 2 for the first 2 training cycles (using the 2 low bits
of w0 as a counter). In the implementation, p is represented by a fixed
point number with a 12 bit fractional part in the linear domain (0..4095)
and 8 bits in the logistic domain (-2047..2047 representing -8..8).
Weights are scaled by 24 bits. Both weights are initialized to 1/2,
expecting 2 probabilities, weighted equally). However, when one input
(x0) is fixed, its weight (w0) is initialized to 0.

A bit history represents the sequence of 0 and 1 bits observed in a given
context. An 8 bit state represents all possible sequences up to 4 bits
long. Longer sequences are represented by a count of 0 and 1 bits, plus
an indicator of the most recent bit. If counts grow too large, then the
next state represents a pair of smaller counts with about the same ratio.
The state table is the same as used in PAQ8 (all versions) and LPAQ1.

A state is mapped to a prediction by using a table. A table entry
contains 2 values, p, initialized to 1/2, and n, initialized to 0.
The output prediciton is p (in the linear domain, not stretched).
If the actual bit is y, then the entry is updated:
```
 error = y - p
 p += error/(n + 1.5)
 if n < limit then n += 1
```
In practice, p is scaled by 22 bits, and n is 10 bits, packed into
one 32 bit integer. The limit is 255.

Every 4 bits, contexts are mapped to arrays of 15 states using a 
hash table. The first element is the bit history for the current
context ending on a half byte boundary, followed by all possible
contexts formed by appending up to 3 more bits.

A hash table accepts a 32 bit context, which must be a hash if
longer than 4 bytes. The input is further hashed and divided into
an index (depending on the table size, a power of 2), and an 8 bit
checksum which is stored in the table and used to detect collisions
(not perfectly). A lookup tests 3 adjacent locations within a single
64 byte cache line, and if a matching checksum is not found, then the
entry with the smallest value in the first data element is replaced
(LFU replacement policy). This element represents a bit history
for a context ending on a half byte boundary. The states are ordered
so that larger values represent larger total bit counts, which
estimates the likelihood of future use. The initial state is 0.

Memory is allocated from MEM = pow(2, opt+22) bytes, where opt is 1 through
9 (user selected). Of this, MEM/2 is for the hash table for storing literal
context states, MEM/8 for the rotating LZP buffer, and MEM/8 for a 
hash table of pointers into the buffer, plus 12 MB for miscellaneous data.
Total memory usage is 0.75*MEM + 12 MB.

## ARITHMETIC CODING

The arithmetic coder codes a bit with probability p using log2(1/p) bits.
Given input string y, the output is a binary fraction x such that
P(< y) <= x < P(<= y) where P(< y) means the total probability of all inputs
lexicographically less than y and P(<= y) = P(< y) + P(y). Note that one
can always find x with length at most log2(P(y)) + 1 bits.

x can be computed efficiently by maintaining a range, low <= x < high
(initially 0..1) and expressing P(y) as a product of predictions:
P(y) = P(y1) P(y2|y1) P(y3|y1y2) P(y4|y1y2y3) ... P(yn|y1y2...yn-1)
where the term P(yi|y0y1...yi-1) means the probability that yi is 1
given the context y1...yi-1, the previous i-1 bits of y. For each
prediction p, the range is split in proportion to the probabilities
of 0 and 1, then updated by taking the half corresponding to the actual
bit y as the new range, i.e.
```
 mid = low + (high - low) * p(y = 1)
 if y = 0 then (low, high) := (mid, high)
 if y = 1 then (low, high) := (low, mid)
```
As low and high approach each other, the high order bits of x become
known (because they are the same throughout the range) and can be
output immediately.

For decoding, the range is split as before and the range is updated
to the half containing x. The corresponding bit y is used to update
the model. Thus, the model has the same knowledge for coding and
decoding.
