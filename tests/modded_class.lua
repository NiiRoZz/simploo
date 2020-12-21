TestModdedClass = {}

function TestModdedClass:testInstantiation()
    A_CALLED = false
    A_MODDED_1_CALLED = false
    A_MODDED_2_CALLED = false

    class "A" {
        public {
            func = function(self)
                A_CALLED = true
            end;
        };
    }

    class "A" moddedClass "" {
        public {
            modded {
                func = function(self)
                    self.A:func()
                    A_MODDED_1_CALLED = true
                end;
            };
        };
    }

    class "A" moddedClass "" {
        public {
            modded {
                func = function(self)
                    self.A:func()
                    A_MODDED_2_CALLED = true
                end;
            };
        };
    }

    local instanceA = A.new()
    instanceA:func()

    assertTrue(A_CALLED)
    assertTrue(A_MODDED_1_CALLED)
    assertTrue(A_MODDED_2_CALLED)

    C_CONSTRUCT_CALLED = false
    D_CONSTRUCT_CALLED = false

    class "C" {
        public {
            __construct = function(self)
                C_CONSTRUCT_CALLED = true
            end;
        }
    }

    class "D" extends "C" {
        public {
            __construct = function(self)
                D_CONSTRUCT_CALLED = true
            end;
        }
    }

    D:new()

    assertTrue(C_CONSTRUCT_CALLED)
    assertTrue(D_CONSTRUCT_CALLED)

    local success, err = pcall(function()
        class "Child" extends "A" moddedClass {

        }
    end)

    assertFalse(success)
    assertStrContains(err, "extends on modded class")
end

LuaUnit:run("TestModdedClass")