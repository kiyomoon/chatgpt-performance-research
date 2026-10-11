#!/bin/zsh
# Regenerates the web pages from the markdown articles. The .md files are the
# only thing to edit; run this afterwards and commit both.
#   ./build.sh
# Page chrome (CSS, header, footer) lives in site/template.html; link rewriting
# and title/contact stripping in site/filter.lua.
set -e
cd "${0:A:h}"

REPO='<a href="https://github.com/kiyomoon/chatgpt-performance-research">Repository</a>'
CONTACT='Contact: toneverdo@gmail.com'

page() {
  local md=$1 out=$2 title=$3 subtitle=$4 description=$5 footer=$6
  # title goes through metadata (pandoc escapes it); the rest are HTML and go
  # in verbatim as template variables.
  pandoc "$md" --from=gfm-strikeout --to=html5 --syntax-highlighting=none --wrap=none \
    --template=site/template.html --lua-filter=site/filter.lua \
    --metadata=title:"$title" \
    --variable=subtitle:"$subtitle" --variable=description:"$description" \
    --variable=footer:"$footer" \
    --output="$out"
  echo "built $out"
}

page article_chatgpt_performance.md index.html \
  "Why ChatGPT Freezes on Long Conversations" \
  "An investigation from inside the browser engine &middot; April 2026 &middot; updated October 2026" \
  "An investigation from inside the browser engine. The bottleneck isn't JavaScript or React — it's WebKit repeatedly rebuilding every CSS style on the page. Updated October 2026 with what actually drives the repetition." \
  "Follow-ups: <a href=\"firefox.html\">Firefox Comparison</a> &middot; <a href=\"followup.html\">The 30-Second Loop</a> &middot; Reports: $REPO &middot; $CONTACT"

page article_firefox_comparison.md firefox.html \
  "How Three Browser Engines Handle Font Loading on Large Pages" \
  "A follow-up comparison of WebKit, Gecko, and Blink &middot; April 2026" \
  "A follow-up comparison of WebKit, Gecko, and Blink. Why Firefox stays responsive on long ChatGPT conversations while WebKit freezes." \
  "Original Investigation: <a href=\"index.html\">WebKit Article</a> &middot; Repository: <a href=\"https://github.com/kiyomoon/chatgpt-performance-research\">GitHub</a> &middot; $CONTACT"

page article_followup_30_second_loop.md followup.html \
  "The 30-Second Loop Wasn't Fonts" \
  "A follow-up, six months later &middot; October 2026" \
  "Re-testing the WebKit fix six months later: the repeating full style rebuilds on long ChatGPT conversations came from WebKit's memory-pressure handling on the Mac, not from web fonts." \
  "Original Investigation: <a href=\"index.html\">WebKit Article</a> &middot; <a href=\"firefox.html\">Firefox Comparison</a> &middot; Repository: $REPO &middot; $CONTACT"
