-- xspf_writer.lua
-- General XSPF (XML Shareable Playlist Format) writer module for VLC extensions
-- Provides reusable functions for creating XSPF playlist files

local xspf = {}

-- XML escape helper
local function xml_escape(str)
    if not str then return "" end
    str = tostring(str)
    return str:gsub("&", "&amp;")
              :gsub("<", "&lt;")
              :gsub(">", "&gt;")
              :gsub('"', "&quot;")
              :gsub("'", "&apos;")
end

-- Write XSPF playlist file
--
-- Parameters:
--   filepath: Full path where to save the XSPF file
--   uri: Media file URI
--   duration: Duration in seconds (optional)
--   vlc_options: Array of VLC-specific options (e.g., bookmarks) (optional)
--   
-- Returns:
--   success: boolean indicating if write succeeded
--   error: error message if failed, nil otherwise
function xspf.write(filepath, uri, duration, vlc_options)
    if not filepath then
        return false, "No filepath provided"
    end
    
    if not uri then
        return false, "No URI provided"
    end
    
    local file, err = io.open(filepath, "w")
    if not file then
        return false, "Failed to open file for writing: " .. (err or "unknown error")
    end
    
    -- Write XSPF structure
    file:write('<?xml version="1.0" encoding="UTF-8"?>\n')
    file:write('<playlist xmlns="http://xspf.org/ns/0/" xmlns:vlc="http://www.videolan.org/vlc/playlist/ns/0/" version="1">\n')
    file:write('    <title>Playlist</title>\n')
    file:write('    <trackList>\n')
    file:write('        <track>\n')
    file:write(string.format('            <location>%s</location>\n', xml_escape(uri)))
    
    if duration then
        file:write(string.format('            <duration>%d</duration>\n', math.floor(duration * 1000)))
    end
    
    -- VLC-specific extensions
    if vlc_options and #vlc_options > 0 then
        file:write('            <extension application="http://www.videolan.org/vlc/playlist/0">\n')
        file:write('                <vlc:id>0</vlc:id>\n')
        
        for _, option in ipairs(vlc_options) do
            file:write(string.format('                <vlc:option>%s</vlc:option>\n', xml_escape(option)))
        end
        
        file:write('            </extension>\n')
    end
    
    file:write('        </track>\n')
    file:write('    </trackList>\n')
    file:write('    <extension application="http://www.videolan.org/vlc/playlist/0">\n')
    file:write('        <vlc:item tid="0"/>\n')
    file:write('    </extension>\n')
    file:write('</playlist>')
    
    file:close()
    return true, nil
end

return xspf
