defmodule Aesir.ZoneServer.Mmo.PetManagement.SupportScriptTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.PetManagement.SupportScript

  test "each support buildin becomes an op in script order" do
    source = """
    petskillbonus bStr,5,10,50;
    petrecovery SC_POISON,60;
    petloot 40;
    petskillattack "SM_BASH",15,1,5;
    petskillattack2 SM_BASH,100,2,1,5;
    petskillsupport 28,2,60,50,50;
    petloot 0;
    """

    assert SupportScript.transpile(source) == [
             {:petskillbonus, :str, 5, 10, 50},
             {:petrecovery, :sc_poison, 60},
             {:petloot, 30},
             {:petskillattack, 5, 10, 1, 5},
             {:petskillattack2, 5, 100, 2, 1, 5},
             {:petskillsupport, 28, 2, 60, 50, 50},
             {:petloot, 1}
           ]
  end

  test "support arguments use the reference unsigned field widths" do
    assert SupportScript.transpile("""
           petskillbonus bStr,-1,65536,50;
           petrecovery SC_POISON,-1;
           petskillattack SM_BASH,-1,65536,-1;
           petskillattack2 SM_BASH,-1,65536,-1,65536;
           petskillsupport 28,-1,65536,-1,65536;
           """) == [
             {:petskillbonus, :str, 65_535, 0, 50},
             {:petrecovery, :sc_poison, 65_535},
             {:petskillattack, 5, 65_535, 0, 65_535},
             {:petskillattack2, 5, 65_535, 0, 65_535, 0},
             {:petskillsupport, 28, 65_535, 0, 65_535, 0}
           ]
  end

  test "an unknown command raises" do
    assert_raise ArgumentError, ~r/unsupported SupportScript/, fn ->
      SupportScript.transpile("petheal 1,2,3,4;")
    end
  end
end
