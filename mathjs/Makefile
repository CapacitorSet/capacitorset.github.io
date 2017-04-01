TITLE=How we exploited a remote execution vulnerability in math.js
PANDOC_COMMAND=pandoc -f markdown -t html5 --template=template.html -V pagetitle="${TITLE}"

all: en it

en: index.md template.html
	${PANDOC_COMMAND} index.md -o index.html

it: index.it.md template.html
	${PANDOC_COMMAND} index.it.md -o index.it.html