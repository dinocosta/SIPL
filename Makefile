IDIR = examples
ODIR = demos

_DEMOS = avg_max.vm max.vm maxof3.vm while.vm array.vm test.vm func.vm logical.vm
DEMOS = $(patsubst %,$(ODIR)/%,$(_DEMOS))

all: sipl demos

sipl: sipl.lex sipl.y
	flex sipl.lex
	yacc sipl.y
	gcc y.tab.c `pkg-config --cflags --libs glib-2.0` -o sipl

demos: sipl.lex sipl.y $(DEMOS)

$(ODIR)/%.vm: $(IDIR)/%.sil sipl.lex sipl.y
	./sipl < $< > $@

clean:
	rm -f y.tab.c lex.yy.c sipl
	rm -f demos/*.vm
