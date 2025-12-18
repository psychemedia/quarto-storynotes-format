-- verse.lua
-- Quarto filter for verse/poetry formatting
local function normalize_verse_content(content)
  local normalized = {}

  for _, block in ipairs(content) do
    if block.t == "Para" then
      local lines = {}
      local current = {}

      for _, inline in ipairs(block.content) do
        if inline.t == "SoftBreak" or inline.t == "LineBreak" then
          table.insert(lines, current)
          current = {}
        else
          table.insert(current, inline)
        end
      end

      if #current > 0 then
        table.insert(lines, current)
      end

      -- Convert paragraph into LineBlock
      if #lines > 0 then
        table.insert(normalized, pandoc.LineBlock(lines))
      end

    else
      -- Preserve stanza breaks (blank lines → new Para)
      table.insert(normalized, block)
    end
  end

  return normalized
end




function Div(div)
  -- Check if this is a verse div
  if div.classes:includes('verse') then
    
    -- Extract options from div attributes
    local options = {
      indentafter = div.attributes['indentafter'],
      vindent = div.attributes['vindent'],
      --versewidth = div.attributes['versewidth'],
      title = div.attributes['title'],
      linenumbers = div.attributes['linenumbers'],
      linenumside = div.attributes['linenumside'],
      firstlinenum = div.attributes['firstlinenum'],
      startnumsat = div.attributes['startnumsat']
    }
    
    -- Get the content
    --local content = div.content
    local content = normalize_verse_content(div.content)
    
    -- Format based on output type
    if quarto.doc.is_format("html") then
      return format_verse_html(content, options)
    elseif quarto.doc.is_format("latex") then
      return format_verse_latex(content, options)
    else
      -- For other formats (Word, etc.), return simple block
      return format_verse_plain(content, options)
    end
  end
end

function format_verse_html(content, options)
  local blocks = {}

  -- Determine numbering options
  local linenumbers = tonumber(options.linenumbers)
  local linenumside = options.linenumside or "right"
  local firstlinenum = tonumber(options.firstlinenum) or 1
  local startnumsat = tonumber(options.startnumsat) or firstlinenum

  -- Outer container
  local classes = { "verse" }
  if linenumbers then
    table.insert(classes, "line-numbered")
    table.insert(classes, "linenums-" .. linenumside)
  end

  table.insert(blocks, pandoc.RawBlock(
    "html",
    '<div class="' .. table.concat(classes, " ") .. '" ' ..
    'style="counter-reset: verseline ' .. (startnumsat - 1) .. '">'
  ))

  -- Title
  if options.title then
    table.insert(blocks, pandoc.RawBlock(
      "html",
      '<div class="verse-title">' .. options.title .. '</div>'
    ))
  end

  -- Content
  for _, block in ipairs(content) do
    if block.t == "LineBlock" then
      table.insert(blocks, pandoc.RawBlock("html", '<div class="stanza">'))

      for _, line in ipairs(block.content) do
        table.insert(blocks, pandoc.RawBlock(
          "html",
          '<div class="verse-line">' ..
          pandoc.utils.stringify(line) ..
          '</div>'
        ))
      end

      table.insert(blocks, pandoc.RawBlock("html", '</div>'))
    end
  end

  table.insert(blocks, pandoc.RawBlock("html", '</div>'))

  return blocks
end


function format_verse_latex(content, options)
  -- Measure width from first verse line
  local first_line = nil
  for _, block in ipairs(content) do
    if block.t == "LineBlock" and #block.content > 0 then
      first_line = pandoc.write(
        pandoc.Pandoc({ pandoc.Plain(block.content[1]) }),
        'latex'
      ):gsub('\n+$', '')
      break
    end
  end

  local latex = ""

  -- Title
  if options.title then
    latex = latex .. '\\poemtitle{' ..
             pandoc.utils.stringify(options.title) .. '}\n'
  end
  

  -- Start verse environment
  if first_line then
    latex = latex .. '\\settowidth{\\versewidth}{' .. first_line .. '}\n'
    --latex = latex .. '\\begin{multicols*}{2}\n'
    latex = latex .. '\\begin{verse}[\\versewidth]\n'
  else
    latex = latex .. '\\begin{verse}\n'
  end
  
  latex = latex .. '\n'
  
  -- Set line numbering
  if options.linenumbers then
    local freq = tonumber(options.linenumbers) or 1
    latex = latex .. '\\poemlines{' .. freq .. '}\n'
    
    if options.linenumside == 'left' then
      latex = latex .. '\\verselinenumbersleft\n'
    end
    
    if options.firstlinenum then
      local firstnum = tonumber(options.firstlinenum) or 1
      local startnum = tonumber(options.startnumsat) or firstnum
      latex = latex .. '\\setverselinenums{' .. firstnum .. '}{' .. startnum .. '}\n'
    end
  end
  
  -- Verse-specific settings
  if options.vindent then
    latex = latex .. '\\setlength{\\vindent}{' .. options.vindent .. '}\n'
  end
  
  -- Process content
  local first_stanza = true
  for _, block in ipairs(content) do
    if block.t == "LineBlock" then

      -- ✅ stanza break (LEGAL and visible)
      if not first_stanza then
        latex = latex .. '\\par\\vspace{\\baselineskip}\n'
      end
      first_stanza = false

      for _, line in ipairs(block.content) do
        local text = pandoc.write(
          pandoc.Pandoc({ pandoc.Plain(line) }),
          'latex'
        ):gsub('\n+$', '')
        latex = latex .. text .. '\\\\\n'
      end
    end
  end
  
  -- Turn off line numbering
  if options.linenumbers then
    latex = latex .. '\\poemlines{0}\n'
  end
  
  latex = latex .. '\\end{verse}\n'
  --latex = latex .. '\\end{multicols*}'

  return pandoc.RawBlock('latex', latex)
end


function format_verse_plain(content, options)
  -- For formats like Word, docx, etc.
  local blocks = {}
  
  if options.title then
    table.insert(blocks, pandoc.Para({
      pandoc.Strong({pandoc.Str(pandoc.utils.stringify(options.title))})
    }))
  end
  
  -- Return content in a blockquote
  table.insert(blocks, pandoc.BlockQuote(content))
  
  return blocks
end