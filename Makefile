all: clean sipl

sipl: sipl.lex sipl.y
	flex sipl.lex
	yacc sipl.y
	gcc y.tab.c `pkg-config --cflags --libs glib-2.0` -o sipl

clean:
	rm -f y.tab.c lex.yy.c sipl


