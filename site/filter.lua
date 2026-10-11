-- Turns an article's markdown (written to read well on GitHub) into the body of
-- its web page: the page template supplies the title and the footer, and links
-- between articles point at the published .html names instead of the .md files.

local pages = {
  ["article_chatgpt_performance.md"] = "index.html",
  ["article_firefox_comparison.md"] = "firefox.html",
  ["article_followup_30_second_loop.md"] = "followup.html",
}

function Link(el)
  local target = el.target:gsub("^%./", "")
  local file, anchor = target:match("^([^#]+)(#?.*)$")
  if file and pages[file] then
    el.target = pages[file] .. anchor
  end
  return el
end

function Pandoc(doc)
  local blocks = doc.blocks
  -- The page template prints the title, so drop the markdown's own top heading.
  if #blocks > 0 and blocks[1].t == "Header" and blocks[1].level == 1 then
    blocks:remove(1)
  end
  -- The page footer carries the contact address, so drop the closing contact line.
  local last = blocks[#blocks]
  if last and last.t == "Para" and pandoc.utils.stringify(last):match("^Questions or similar findings%?") then
    blocks:remove(#blocks)
  end
  return doc
end
