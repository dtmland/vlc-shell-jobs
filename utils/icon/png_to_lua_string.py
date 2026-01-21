import sys

def png_to_lua_string(png_file, lua_file):
    with open(png_file, 'rb') as f:
        byte_array = f.read()

    lua_string = 'png_data = "'
    line_length = len('png_data = "')  # Start with the length of the initial string

    for byte in byte_array:
        byte_str = f"\\{byte}"
        if line_length + len(byte_str) > 120:
            lua_string += '" ..\n           "'
            line_length = len('           "')  # Reset line length for the new line
        lua_string += byte_str
        line_length += len(byte_str)

    lua_string += '"'

    with open(lua_file, 'w') as f:
        f.write(lua_string)

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: python png_to_lua_string.py <input.png> <output.lua>")
    else:
        png_to_lua_string(sys.argv[1], sys.argv[2])
