W        = -Wall
OPT      = -O2 -g
STD      = -std=c++11
CXXFLAGS = -I.. -L.. $(STD) $(OPT) $(W) -fPIC $(XCXXFLAGS)
LDLIBS   = -lvmprobe
LDFLAGS  = -Wl,-rpath,..

TESTS    = take-snapshot parse-snapshot

.PHONY: all clean

all: $(TESTS)

clean:
	rm -f $(TESTS)

$(OBJS): %.cpp Makefile
