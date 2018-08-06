TITLE=Google Summer of Code 2018: contributing to Honeytrap
PANDOC_COMMAND=pandoc -f markdown -t html5 --template=template.html -V pagetitle="${TITLE}"

all: index.html

index.html: index.md template.html
	${PANDOC_COMMAND} index.md -o index.html