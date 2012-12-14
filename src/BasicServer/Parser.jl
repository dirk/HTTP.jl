module Parser
  using Base
  
  #using HTTP
  
  function parse_header(raw::String)
    header = Dict{String, Any}()
    field = nothing
    
    lines = split(raw, "\n")
    for line in lines
      line = strip(line)
      if isempty(line) continue end
      
      matched = false
      m = match(r"^([A-Za-z0-9!\#$%&'*+\-.^_`|~]+):\s*(.*?)\s*\z"m, line)
      if m != nothing
        field, value = m.captures[1], m.captures[2]
        if has(header, field)
          push(header[field], value)
        else
          header[field] = {value}
        end
        matched = true
        
        field = nothing
      end
      
      m = match(r"^\s+(.*?)\s*\z"m, line)
      if m != nothing && !matched
        value = m.captures[1]
        if field == nothing
          
          continue
        end
        ti = length(header[field])
        header[field][ti] = strcat(header[field[ti]], " ", value)
        matched = true
        
        field = nothing
      end
      
      if matched == false
        throw(strcat("Bad header: ", line))
      end
       
      
    end
    
    return header
  end
  
  function parse_request_line(request_line)
    ## m = match(r"^(\S+)\s+(\S+?)(?:\s+HTTP\/(\d+\.\d+))?"m, request_line)
    m = match(r"^(\S+)\s+(\S+)\s+HTTP\/(\d+\.\d+)"m, request_line)
    if m == nothing
      throw(strcat("Bad request: ", request_line))
      return
    else
      method = string(m.captures[1])
      path = string(m.captures[2])
      version = string((length(m.captures) > 2 && m.captures[3] != nothing) ? m.captures[3] : "0.9")
    end
    return vec([method, path, version])
  end
  
  # def parse_query(str)
  #   query = Hash.new
  #   if str
  #     str.split(%r[&;]/).each{|x|
  #       next if x.empty?
  #       key, val = x.split(%r=/,2)
  #       key = unescape_form(key)
  #       val = unescape_form(val.to_s)
  #       val = FormData.new(val)
  #       val.name = key
  #       if query.has_key?(key)
  #         query[key].append_data(val)
  #         next
  #       end
  #       query[key] = val
  #     }
  #   end
  #   query
  # end
  
  function parse_query(str)
    query = Dict{String,Any}()
    if isa(str, String)
      str = strip(str)
      parts = split(str, r"[&;]")
      for part in parts
        part = strip(part)
        if isempty(part) next; end
        
        key, value = split(part, "=", 2)
        key   = unescape_form(key)
        value = unescape_form(value)
        if has(query, key)
          push(query[key], value)
        else
          query[key] = [value]
        end
      end
    end
    return query
  end
  
  #function replace(str, _find, replace)
  #  return join(split(str, _find), replace)
  #end
  
  escaped_regex = r"%([0-9a-fA-F]{2})"
  function unescape(str)
    # def _unescape(str, regex) str.gsub(regex){ $1.hex.chr } end
    for m in each_match(escaped_regex, str)
      for capture in m.captures
        rep = string(char(parse_int(capture, 16)))
        str = replace(str, "%"*capture, rep)
      end
    end
    return str
  end
  function unescape_form(str)
    str = replace(str, "+", " ")
    return unescape(str)
  end
  
  # control+space+delims+unwise+nonascii
  # control  = (0x0..0x1f).collect{|c| c.chr }.join + "\x7f"
  # space    = " "
  # delims   = '<>#%"'
  # unwise   = '{}|\\^[]`'
  # nonascii = (0x80..0xff).collect{|c| c.chr }.join
  # reserved = ';/?:@&=+$,'
  # unescaped = control+space+delims+unwise+nonascii
  control_array = convert(Array{Uint8,1}, vec(0:(parse_int("1f", 16))))
  control = utf8(ascii(control_array)*"\x7f")
  space = utf8(" ")
  delims = utf8("%<>\"")
  unwise   = utf8("{}|\\^`")
  nonascii_array = convert(Array{Uint8,1}, vec(parse_int("80", 16):(parse_int("ff", 16))))
  #nonascii = utf8(string(nonascii_array))
  reserved = utf8(",;/?:@&=+\$![]'*#")
  # Strings to be escaped
  # (Delims goes first so '%' gets escaped first.)
  unescaped = delims * reserved * control * space * unwise# * nonascii
  unescaped_form = delims * reserved * control * unwise# * nonascii
  
  # Escapes chars (listed in second string); also escapes all non-ASCII chars.
  function escape_with(str, use)
    chars = split(use, "")
    
    for c in chars
      _char = c[1] # Character string as Char
      h = hex(int(_char))
      if strlen(h) < 2
        h = "0"*h
      end
      str = replace(str, c, "%" * h)
    end
    
    for i in nonascii_array
      str = replace(str, char(i), "%" * hex(i))
    end
    
    return str
  end
  
  function escape(str)
    return escape_with(str, unescaped)
  end
  function escape_form(str)
    str = escape_with(str, unescaped_form)
    return replace(str, " ", "+")
  end
  
  export parse_header, parse_request_line
  export unescape, unescape_form, escape, escape_form
  
end
