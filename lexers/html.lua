-- Copyright 2006-2015 Mitchell mitchell.att.foicica.com. See LICENSE.
-- HTML LPeg lexer.

local l = require('lexer')
local token, word_match = l.token, l.word_match
local P, R, S, V = lpeg.P, lpeg.R, lpeg.S, lpeg.V

local M = {_NAME = 'html'}

case_insensitive_tags = true

-- Whitespace.
local ws = token(l.WHITESPACE, l.space^1)

-- Comments.
local comment = token(l.COMMENT, '<!--' * (l.any - '-->')^0 * P('-->')^-1)

-- Strings.
local sq_str = l.delimited_range("'")
local dq_str = l.delimited_range('"')
local string = l.last_char_includes('=') * token(l.STRING, sq_str + dq_str)

-- TODO: performance is terrible on large files.
local in_tag = P(function(input, index)
  local before = input:sub(1, index - 1)
  local s, e = before:find('<[^>]-$'), before:find('>[^<]-$')
  if s and e then return s > e and index or nil end
  if s then return index end
  return input:find('^[^<]->', index) and index or nil
end)

-- Numbers.
local number = l.last_char_includes('=') *
               token(l.NUMBER, l.digit^1 * P('%')^-1) --* in_tag

-- Elements.
local known_element = token('element', word_match({
  'a', 'abbr', 'address', 'area', 'article', 'aside', 'audio', 'b', 'base',
  'bdi', 'bdo', 'blockquote', 'body', 'br', 'button', 'canvas', 'caption',
  'cite', 'code', 'col', 'colgroup', 'content', 'data', 'datalist', 'dd',
  'decorator', 'del', 'details', 'dfn', 'div', 'dl', 'dt', 'element', 'em',
  'embed', 'fieldset', 'figcaption', 'figure', 'footer', 'form', 'h1', 'h2',
  'h3', 'h4', 'h5', 'h6', 'head', 'header', 'hr', 'html', 'i', 'iframe', 'img',
  'input', 'ins', 'kbd', 'keygen', 'label', 'legend', 'li', 'link', 'main',
  'map', 'mark', 'menu', 'menuitem', 'meta', 'meter', 'nav', 'noscript',
  'object', 'ol', 'optgroup', 'option', 'output', 'p', 'param', 'pre',
  'progress', 'q', 'rp', 'rt', 'ruby', 's', 'samp', 'script', 'section',
  'select', 'shadow', 'small', 'source', 'spacer', 'spacer', 'span', 'strong',
  'style', 'sub', 'summary', 'sup', 'table', 'tbody', 'td', 'template',
  'textarea', 'tfoot', 'th', 'thead', 'time', 'title', 'tr', 'track', 'u', 'ul',
  'var', 'video', 'wbr'
}, nil, case_insensitive_tags))
local unknown_element = token('unknown_element', l.word)
local element = l.last_char_includes('</') * (known_element + unknown_element)

-- Attributes
local known_attribute = token('attribute', word_match({
  'accept', 'accept-charset', 'accesskey', 'action', 'align', 'alt', 'async',
  'autocomplete', 'autofocus', 'autoplay', 'bgcolor', 'border', 'buffered',
  'challenge', 'charset', 'checked', 'cite', 'class', 'code', 'codebase',
  'color', 'cols', 'colspan', 'content', 'contenteditable', 'contextmenu',
  'controls', 'coords', 'data', 'data-', 'datetime', 'default', 'defer', 'dir',
  'dirname', 'disabled', 'download', 'draggable', 'dropzone', 'enctype', 'for',
  'form', 'headers', 'height', 'hidden', 'high', 'href', 'hreflang',
  'http-equiv', 'icon', 'id', 'ismap', 'itemprop', 'keytype', 'kind', 'label',
  'lang', 'language', 'list', 'loop', 'low', 'manifest', 'max', 'maxlength',
  'media', 'method', 'min', 'multiple', 'name', 'novalidate', 'open', 'optimum',
  'pattern', 'ping', 'placeholder', 'poster', 'preload', 'pubdate',
  'radiogroup', 'readonly', 'rel', 'required', 'reversed', 'role', 'rows',
  'rowspan', 'sandbox', 'spellcheck', 'scope', 'scoped', 'seamless', 'selected',
  'shape',   'size', 'sizes', 'span', 'src', 'srcdoc', 'srclang', 'start',
  'step', 'style', 'summary', 'tabindex', 'target', 'title', 'type', 'usemap',
  'value', 'width', 'wrap'
}, '-', case_insensitive_tags) + ((P('data-') + 'aria-') * (l.alnum + '-')^1))
local unknown_attribute = token('unknown_attribute', l.word)
local attribute = (known_attribute + unknown_attribute) * #(l.space^0 * '=')

-- Tags.
local tag = token('tag', '<' * P('/')^-1 + P('/')^-1 * '>')

-- Equals.
local equals = token(l.OPERATOR, '=') --* in_tag

-- Entities.
local entity = token('entity', '&' * (l.any - l.space - ';')^1 * ';')

-- Doctype.
local doctype = token('doctype', '<!' *
                      word_match({'doctype'}, nil, case_insensitive_tags) *
                      (l.any - '>')^1 * '>')

M._rules = {
  {'whitespace', ws},
  {'comment', comment},
  {'doctype', doctype},
  {'tag', tag},
  {'element', element},
  {'attribute', attribute},
--  {'equals', equals},
  {'string', string},
  {'number', number},
  {'entity', entity},
}

M._tokenstyles = {
  tag = l.STYLE_KEYWORD,
  element = l.STYLE_KEYWORD,
  unknown_element = l.STYLE_KEYWORD..',italics',
  attribute = l.STYLE_TYPE,
  unknown_attribute = l.STYLE_TYPE..',italics',
  entity = l.STYLE_OPERATOR,
  doctype = l.STYLE_COMMENT
}

-- Tags that start embedded languages.
M.embed_start_tag = tag * element *
                    (ws^1 * attribute * ws^0 * equals * ws^0 * string)^0 *
                    ws^0 * tag
M.embed_end_tag = tag * element * tag

-- Embedded CSS.
local css = l.load('css')
local style_element = word_match({'style'}, nil, case_insensitive_tags)
local css_start_rule = #(P('<') * style_element *
                        ('>' + P(function(input, index)
  if input:find('^%s+type%s*=%s*(["\'])text/css%1', index) then
    return index
  end
end))) * M.embed_start_tag -- <style type="text/css">
local css_end_rule = #('</' * style_element * ws^0 * '>') *
                     M.embed_end_tag -- </style>
l.embed_lexer(M, css, css_start_rule, css_end_rule)

-- Embedded JavaScript.
local js = l.load('javascript')
local script_element = word_match({'script'}, nil, case_insensitive_tags)
local js_start_rule = #(P('<') * script_element *
                       ('>' + P(function(input, index)
  if input:find('^%s+type%s*=%s*(["\'])text/javascript%1', index) then
    return index
  end
end))) * M.embed_start_tag -- <script type="text/javascript">
local js_end_rule = #('</' * script_element * ws^0 * '>') *
                    M.embed_end_tag -- </script>
l.embed_lexer(M, js, js_start_rule, js_end_rule)

-- Embedded CoffeeScript.
local cs = l.load('coffeescript')
local script_element = word_match({'script'}, nil, case_insensitive_tags)
local cs_start_rule = #(P('<') * script_element * P(function(input, index)
  if input:find('^[^>]+type%s*=%s*(["\'])text/coffeescript%1', index) then
    return index
  end
end)) * M.embed_start_tag -- <script type="text/coffeescript">
local cs_end_rule = #('</' * script_element * ws^0 * '>') *
                    M.embed_end_tag -- </script>
l.embed_lexer(M, cs, cs_start_rule, cs_end_rule)

M._foldsymbols = {
  _patterns = {'</?', '/>', '<!%-%-', '%-%->'},
  tag = {['<'] = 1, ['/>'] = -1, ['</'] = -1},
  [l.COMMENT] = {['<!--'] = 1, ['-->'] = -1}
}

return M
