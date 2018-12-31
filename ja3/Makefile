TITLE=Fingerprinting TLS clients with JA3
PANDOC_COMMAND=pandoc -f markdown -t html5 --template=template.html -V pagetitle="${TITLE}"

all: index.html

index.html: index.md template.html
	${PANDOC_COMMAND} index.md -o index.html