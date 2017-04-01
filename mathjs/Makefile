TITLE=How we exploited a remote execution vulnerability in math.js

all: index.md template.html
	pandoc index.md -f markdown -t html5 -o index.html --template=template.html -V pagetitle="${TITLE}"