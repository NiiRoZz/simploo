parser = {}
simploo.parser = parser

parser.instance = false
parser.hooks = {}
parser.modifiers = {"public", "private", "protected", "static", "const", "meta", "abstract"}

-- Parses the simploo class syntax into the following table format:
--
-- {
--     name = "ExampleClass",
--     parents = {"ExampleParent1", "ExampleParent2"},
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
    object.classparents = {}
    object.classMembers = {}
    object.classUsings = {}

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
        for className in string.gmatch(parentsString, "([^,^%s*]+)") do
            -- Update class cache
            table.insert(self.classparents, className)
        end
    end

    -- This method compiles all gathered data and passes it through to the finaliser method.
    function object:register(classContent)
        if classContent then
            self:addMemberRecursive(classContent)
        end

        local output = {}
        output.name = self.className
        output.parents = self.classparents
        output.members = self.classMembers
        output.usings = self.classUsings
        
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
            local containsModifierMember = (type(memberValue) == "table" and memberValue['__modifiers'])

            if not isModifierMember and not containsModifierMember then
                self:addMember(memberName, memberValue, memberTable["__modifiers"])
            elseif containsModifierMember then
                self:addMemberRecursive(memberValue, memberTable["__modifiers"])
            end
        end
    end

    -- Adds a member to the class definition
    function object:addMember(memberName, memberValue, modifiers)
        self['classMembers'][memberName] = {
            value = memberValue == null and nil or memberValue,
            modifiers = {}
        }

        for _, modifier in pairs(modifiers or {}) do
            self['classMembers'][memberName].modifiers[modifier] = true
        end
    end

    function object:appendNamespace(namespace)
        self.className = namespace .. "." .. self.className
    end

    function object:addUsing(using)
        table.insert(self.classUsings, using)
    end

    local meta = {}
    local modifierStack = {}

    -- This method catches and stacks modifier definition when using alternative syntax.
    function meta:__index(key)
        table.insert(modifierStack, key)

        return self
    end

    -- This method catches assignments of members using alternative syntax.
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

function parser:addHook(hookName, callbackFn)
    table.insert(self.hooks, {hookName, callbackFn})
end

function parser:fireHook(hookName, ...)
    for _, v in pairs(self.hooks) do
        if v[1] == hookName then
            local ret = {v[2](...)}

            -- Return data if there was a return value
            if ret[0] then
                return unpack(ret)
            end
        end
    end
end


-- Add modifiers as global functions
for _, modifierName in pairs(parser.modifiers) do
    _G[modifierName] = function(body)
        body["__modifiers"] = body["__modifiers"] or {}
        table.insert(body["__modifiers"], modifierName)

        return body
    end
end

-- Add additional globals
function class(className, classOperation)
    if not parser.instance then
        parser.instance = parser:new(onFinished)
        parser.instance:setOnFinished(function(self, output)
            parser.instance = nil -- Set to nil first, before calling the instancer, so that if the instancer errors out it's not going to reuse the old parser again

            if simploo.instancer then
                simploo.instancer:initClass(output)
            end
        end)
    end

    parser.instance:class(className, classOperation)

    if parser.activeNamespace then
        parser.instance:appendNamespace(parser.activeNamespace)
    end

    if parser.activeUsings then
        for _, v in pairs(parser.activeUsings) do
            parser.instance:addUsing(v)
        end
    end

    return parser.instance
end

function extends(parents)
   if not parser.instance then
        error("calling extends without calling class first")
    end

    parser.instance:extends(parents)

    return parser.instance
end

parser.activeNamespace = ""
parser.activeUsings = {}

function namespace(namespaceName)
    parser.activeNamespace = namespaceName
    parser.activeUsings = {}

    parser:fireHook("onNamespace", namespaceName)
end

function using(namespaceName)
    -- Save our previous namespace and usings, incase our callback loads new classes in other namespaces
    local previousNamespace = parser.activeNamespace
    local previousUsings = parser.activeUsings

    parser.activeNamespace = ""
    parser.activeUsings = {}

    -- Fire the hook
    local returnNamespace = parser:fireHook("onUsing", namespaceName)

    -- Restore the previous namespace and usings
    parser.activeNamespace = previousNamespace
    parser.activeUsings = previousUsings

    -- Add the new using to our table
    table.insert(parser.activeUsings, returnNamespace or namespaceName)
end

null = "NullVariable_WgVtlrvpP194T7wUWDWv2mjB" -- Parsed into nil value when assigned to member variables

