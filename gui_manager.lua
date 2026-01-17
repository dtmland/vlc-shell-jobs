local GuiManager = {}
GuiManager.__index = GuiManager

function GuiManager.new(dlg, initial_height, initial_width, jump_height, jump_width, min_height, max_height, min_width, max_width)
    local self = setmetatable({}, GuiManager)
    self.dlg = dlg
    self.height_in_chars = initial_height
    self.width_in_chars = initial_width
    self.jump_amount_height = jump_height
    self.jump_amount_width = jump_width
    self.min_height = min_height
    self.max_height = max_height
    self.min_width = min_width
    self.max_width = max_width
    self.pipe_labels = {}
    self.underscore_label = nil
    self.relevant_message = "Click 'Run' when ready. Click 'Refresh' to check run status"
    self.output_html = nil
    return self
end

function GuiManager:initialize_gui(start_column, pipe_row_start)
    local end_row = pipe_row_start + self.height_in_chars - 1
    local underscore_row = end_row

    -- Add pipe labels
    for i = pipe_row_start, end_row do
        local pipe_label = self.dlg:add_label("|", start_column + 1, i, 1, 1)
        table.insert(self.pipe_labels, pipe_label)
    end

    -- Add underscore label
    local underscore_line = string.rep("_", self.width_in_chars)
    self.underscore_label = self.dlg:add_label(underscore_line, start_column, underscore_row, 1, 1)

    -- Add output_html widget
    self.output_html = self.dlg:add_html(self.relevant_message, 1, 3, start_column, underscore_row - 1)
end

function GuiManager:redraw_gui(start_column, pipe_row_start)
    local end_row = pipe_row_start + self.height_in_chars - 1

    -- Adjust pipe labels
    local current_pipe_count = #self.pipe_labels
    local desired_pipe_count = self.height_in_chars

    if current_pipe_count > desired_pipe_count then
        for i = current_pipe_count, desired_pipe_count + 1, -1 do
            self.dlg:del_widget(self.pipe_labels[i])
            table.remove(self.pipe_labels, i)
        end
    elseif current_pipe_count < desired_pipe_count then
        for i = current_pipe_count + 1, desired_pipe_count do
            local pipe_label = self.dlg:add_label("|", start_column + 1, pipe_row_start + i - 1, 1, 1)
            table.insert(self.pipe_labels, pipe_label)
        end
    end

    -- Update underscore label
    local underscore_row = end_row
    local underscore_line = string.rep("_", self.width_in_chars)
    if self.underscore_label then
        self.underscore_label:set_text(underscore_line)
    else
        self.underscore_label = self.dlg:add_label(underscore_line, start_column, underscore_row, 1, 1)
    end

    -- Update output_html widget
    self.dlg:del_widget(self.output_html)
    self.output_html = self.dlg:add_html(self.relevant_message, 1, 3, start_column, underscore_row - 1)
end

function GuiManager:update_message(message)
    -- Ensure message is a string
    if type(message) ~= "string" then
        message = tostring(message)
    end
    self.relevant_message = "<p>" .. message:gsub("\n", "<br>") .. "</p>"
    if self.output_html then
        self.output_html:set_text(self.relevant_message)
    end
end

function GuiManager:adjust_height(delta)
    local new_height = self.height_in_chars + delta
    if new_height >= self.min_height and new_height <= self.max_height then
        self.height_in_chars = new_height
    end
end

function GuiManager:adjust_width(delta)
    local new_width = self.width_in_chars + delta
    if new_width >= self.min_width and new_width <= self.max_width then
        self.width_in_chars = new_width
    end
end

return GuiManager
