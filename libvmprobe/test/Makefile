W        = -Wall
OPT      = -O2 -g
STD      = -std=c++11
CXXFLAGS = -I.. -L.. $(STD) $(OPT) $(W) -fPIC $(XCXXFLAGS)
LDLIBS   = -lvmprobe
LDFLAGS  = -Wl,-rpath,..

TESTS    = take-snapshot restore-snapshot parse-snapshot delta-snapshots union-snapshots

.PHONY: all clean test

all: test

build: $(TESTS)

test: build
	perl test.pl

clean:
	rm -rf $(TESTS)

$(OBJS): %.cpp Makefile
