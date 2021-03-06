# gcc -D defines a macro to be used by the preprocessor
CFLAGS=-g -O2 -Wall -Wextra -Isrc -rdynamic -DNDEBUG -Wl,--no-as-needed -ldl $(OPTFLAGS)
# Link the library
LIBS=-ldl $(OPTLIBS)
# default prefix
PREFIX?=/usr/local

# wildcard is used for looking for all files match the given pattern
SOURCES=$(wildcard src/**/*.c src/*.c)
# patsubst is for string subsitute i.e. foo.c -> foo.o
OBJECTS=$(patsubst %.c,%.o,$(SOURCES))

TEST_SRC=$(wildcard tests/*_tests.c)
TESTS=$(patsubst %.c,%,$(TEST_SRC))

TARGET=build/liblcthw.a
SO_TARGET=$(patsubst %.a,%.so,$(TARGET))

# The Target Build
all: $(TARGET) $(SO_TARGET) tests

dev: CFLAGS=-g -Wall -Isrc -Wall -Wextra $(OPTFLAGS)
dev: all

# -fPIC generate position-independent code(PIC)
# In computing, position-independent code (PIC) or position-independent 
# executable (PIE) is a body of machine code that, being placed somewhere 
# in the primary memory, executes properly regardless of its absolute 
# address. PIC is commonly used for shared libraries, so that the same library 
# code can be loaded in a location in each program address space where 
# it will not overlap any other uses of memory (for example, other shared 
# libraries). (from wiki)
# ar is used to do the packaging for a static library. With ar, you can 
# push all object files into a single archive. Or multiple archives 
# together. So instead of a 1000 source files, you get a single archive, 
# which you can use with gcc.
# [r] replace existing or insert new file(s) into the archive
# [c] do not warn if the library had to be created
# [s] create an archive index(cf. ranlib)
#
# This archive needs an index for gcc to make use of. So, ranlib can do 
# that. Often ar can do it too, so ranlib just exists for history sake.
$(TARGET): CFLAGS += -fPIC
$(TARGET): build $(OBJECTS)
	ar rcs $@ $(OBJECTS)
	ranlib $@

# -shared flag produce a shared object which can then be linked wih other 
#  objects to form an executable. Not all systems support this option. 
#  For predictable results, you must also specify the same set of 
#  options used for compilation(-fPIC)when you specify this linker option

$(SO_TARGET): $(TARGET) $(OBJECTS)
	$(CC) -shared -o $@ $(OBJECTS)

build:
	@mkdir -p build
	@mkdir -p bin

# The Unit Tests
# .PHONY means tests is not a file
.PHONY: tests
tests: CFLAGS += $(SO_TARGET)
tests: $(TESTS)
	sh ./tests/runtests.sh

# Generate valgrind log file
valgrind:
	VALGRIND="valgrind --log-file=/tmp/valgrind-%p.log" $(MAKE)

# The Cleaner
clean:
	rm -rf build $(OBJECTS) $(TESTS)
	rm -f tests/tests.log
	find . -name "*.gc*" -exec rm {} \;
	rm -rf `find . -name "*.dSYM" -print`

# The Install
install: all
	install -d $(DESTDIR)/$(PREFIX)/lib/
	install $(TARGET) $(DESTDIR)/$(PREFIX)/lib/

# The Checker
BADFUNCS='[^_.>a-zA-Z0-9](str(n?cpy|n?cat|xfrm|n?dup|str|pbrk|tok|_)|stpn?cpy|a?sn?printf|byte_)'
check:
	@echo Files with potentially dangerous functions.
	@egrep $(BADFUNCS) $(SOURCES) || true
