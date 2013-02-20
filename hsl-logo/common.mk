AS	= ca65
ASFLAGS	= -l -t nes
LD	= ld65
LDFLAGS	= -m $(PROGRAM).map $(CONFIG_FLAGS)
CL	= cl65
CLFLAGS	= --listing $(PROGRAM) --lib-path /usr/lib/cc65/lib/ -t nes -g $(CLCONFIG_FLAGS) -m $(PROGRAM).map -Ln $(PROGRAM).lbl


OBJECTS = $(SOURCES:.asm=.o)

all: $(PROGRAM).nes

$(PROGRAM).nes:
	$(CL) $(CLFLAGS) -o $@ $(SOURCES)

open: $(PROGRAM).nes
	open $(PROGRAM).nes

clean:
	$(RM) *.o *.lst $(PROGRAM).nes $(PROGRAM).map $(PROGRAM).lbl

.PHONY: all clean open $(PROGRAM).nes
