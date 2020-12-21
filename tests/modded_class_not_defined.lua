TestModdedClassNotDefined = {}

function TestModdedClassNotDefined:testInstantiation()
    local success, err = pcall(function()
        class "DPKG" moddedClass "" {

        }
    end)

    assertFalse(success)
    assertStrContains(err, "can't mod a undefined class")
end

LuaUnit:run("TestModdedClassNotDefined")