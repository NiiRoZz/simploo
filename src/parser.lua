local parser = {}
simploo.parser = parser

parser.instance = false
parser.modifiers = {"public", "private", "protected", "static", "const", "meta", "abstract", "modded"}

-- Parses the simploo class syntax into the following table format:
--
-- {
--     name = "ExampleClass",
--     parent = "ExampleParent1",
--     functions = {
--         exampleFunction = {value = function() ... end, modifiers = {public = true, static = true, ...}}
--     }
--     variables = {
--         exampleVariablt = {value = 0, modifiers = {public = true, static = true, ...}}
--     }
-- }

function parser:new()
    local object = {}
    object.className = ""
    object.classParent = ""
    object.classMembers = {}
    object.classUsings = {}
    object.classModded = false

    object.onFinishedData = false
    object.onFinished = function(self, output)
        self.onFinishedData = output
    end

    function object:setOnFinished(fn)
        if self.onFinishedData then
            -- Directly call the finished function if we already have a result available
            fn(self, self.onFinishedData)
        else
            self.onFinished = fn
        end
    end

    function object:modded()
        self.classModded = true
    end

    function object:class(className, classOperation)
        self.className = className

        for k, v in pairs(classOperation or {}) do
            if self[k] then
                self[k](self, v)
            else
                error("unknown class operation " .. k)
            end
        end
    end

    function object:extends(parentsString)
        local regex = "([^,^%s*]+)"

        local _, count = string.gsub(parentsString, regex, "%1")

        if (count > 1) then
            error("Can't extend from multiple parents")
        end

        local className = string.match(parentsString, regex)

        if className then
            self.classParent = className
        end
    end

    function object:register(classContent)
        if classContent then
            self:addMemberRecursive(classContent)
        end

        local output = {}
        output.name = self.className
        output.parent = self.classParent
        output.members = self.classMembers
        output.usings = self.classUsings
        output.modded = self.classModded
        
        self:onFinished(output)
    end

    -- Recursively compile and pass through all members and modifiers found in a tree like structured table.
    -- All modifiers applicable to the member inside a branch of this tree are defined in the __modifiers key.
    function object:addMemberRecursive(memberTable, activeModifiers)
        for _, modifier in pairs(activeModifiers or {}) do
            table.insert(memberTable["__modifiers"], 1, modifier)
        end

        for memberName, memberValue in pairs(memberTable) do
            local isModifierMember = memberName == "__modifiers"
            local containsModifierMember = (type(memberValue) == "table" and memberValue["__modifiers"])

            if not isModifierMember and not containsModifierMember then
                self:addMember(memberName, memberValue, memberTable["__modifiers"])
            elseif containsModifierMember then
                self:addMemberRecursive(memberValue, memberTable["__modifiers"])
            end
        end
    end

    -- Adds a member to the class definition
    function object:addMember(memberName, memberValue, modifiers)
	    if memberValue == simploo.syntax.null then
            memberValue = nil
        end
		
        self["classMembers"][memberName] = {
            value = memberValue,
            modifiers = {}
        }

        for _, modifier in pairs(modifiers or {}) do
            self["classMembers"][memberName].modifiers[modifier] = true
        end
    end

    function object:namespace(namespace)
        self.className = namespace .. "." .. self.className
    end

    function object:using(using)
        table.insert(self.classUsings, using)
    end

    local meta = {}
    local modifierStack = {}

    -- This method catches and stacks modifier definition when using native lua syntax.
    function meta:__index(key)
        table.insert(modifierStack, key)

        return self
    end

    -- This method catches assignments of members using native lua syntax.
    function meta:__newindex(key, value)
        self:addMember(key, value, modifierStack)

        modifierStack = {}
    end

    -- When using the normal syntax, the class method will be called with the members table as argument.
    -- This method passes through that call.
    function meta:__call(classContent)
        self:register(classContent)
    end

    return setmetatable(object, meta)
end

