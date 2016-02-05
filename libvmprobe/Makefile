AR       = ar
W        = -Wall
OPT      = -O2 -g
STD      = -std=c++11
CXXFLAGS = $(STD) $(OPT) $(W) -fPIC $(XCXXFLAGS)
LDFLAGS  =

OBJS     = crawler.o snapshot.o summary.o file.o cache.o varuint64.o

.PHONY: all clean
all: libvmprobe.a libvmprobe.so

clean:
	rm -f *.o *.so *.a

libvmprobe.a: $(OBJS)
	$(AR) rs $@ $(OBJS)

libvmprobe.so: $(OBJS)
	$(CXX) $(LDFLAGS) -Wl,-soname,libvmprobe.so -shared -o $@ $(OBJS)

%: %.o Makefile
	$(CXX) $(CXXFLAGS) $(LDFLAGS) $^ $(LDLIBS) -o $@

%.o: %.cpp *.h Makefile
	$(CXX) $(CXXFLAGS) -c $<
