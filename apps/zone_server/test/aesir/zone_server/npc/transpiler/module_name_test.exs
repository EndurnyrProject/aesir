defmodule Aesir.ZoneServer.Npc.Transpiler.ModuleNameTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Npc.Transpiler.ModuleName

  test "renewal helper and floating outputs use the renewal namespace" do
    entry = %{file: "re/cities/izlude.txt"}

    assert ModuleName.module(:function, nil, "f_mode", :renewal) ==
             "Aesir.ZoneServer.Content.Npc.Re.Functions.FMode"

    assert ModuleName.path(:function, nil, "f_mode", :renewal) ==
             "lib/aesir/zone_server/content/npc/re/functions/f_mode.ex"

    assert ModuleName.module(:floating, entry, "guard_izlude", :renewal) ==
             "Aesir.ZoneServer.Content.Npc.Re.Floating.Cities.Izlude.GuardIzlude"

    assert ModuleName.path(:floating, entry, "guard_izlude", :renewal) ==
             "lib/aesir/zone_server/content/npc/re/floating/cities/izlude/guard_izlude.ex"
  end

  test "pre-renewal helper and floating outputs use the pre-renewal namespace" do
    entry = %{file: "pre-re/cities/izlude.txt"}

    assert ModuleName.module(:function, nil, "f_mode", :pre_renewal) ==
             "Aesir.ZoneServer.Content.Npc.PreRe.Functions.FMode"

    assert ModuleName.path(:function, nil, "f_mode", :pre_renewal) ==
             "lib/aesir/zone_server/content/npc/pre_re/functions/f_mode.ex"

    assert ModuleName.module(:floating, entry, "guard_izlude", :pre_renewal) ==
             "Aesir.ZoneServer.Content.Npc.PreRe.Floating.Cities.Izlude.GuardIzlude"

    assert ModuleName.path(:floating, entry, "guard_izlude", :pre_renewal) ==
             "lib/aesir/zone_server/content/npc/pre_re/floating/cities/izlude/guard_izlude.ex"
  end

  test "shared floating output mirrors its source file, keeping the scope directory" do
    entry = %{file: "re/cities/izlude.txt"}

    assert ModuleName.module(:floating, entry, "guard_izlude") ==
             "Aesir.ZoneServer.Content.Npc.Floating.Re.Cities.Izlude.GuardIzlude"

    assert ModuleName.path(:floating, entry, "guard_izlude") ==
             "lib/aesir/zone_server/content/npc/floating/re/cities/izlude/guard_izlude.ex"
  end

  test "invisible rAthena names keep their name for slugs but stay unnamed for display" do
    assert ModuleName.script_name("#Gate_manager_main") == "Gate_manager_main"
    assert ModuleName.script_name("Gate01#gq_main") == "Gate01"
    assert ModuleName.script_name("::Guard_izlude") == "Guard_izlude"
    # a few reference rows indent the name or prefix it with a marker before the `#`
    assert ModuleName.script_name(" #paypuzz1") == "paypuzz1"
    assert ModuleName.script_name("\u00a1\u00a1#crypt") == "crypt"

    assert ModuleName.slug(ModuleName.script_name("#Gate_manager_main")) == "gate_manager_main"
    assert ModuleName.display_name("#Gate_manager_main") == ""
  end

  test "shared output APIs and placed-script outputs remain unchanged" do
    entry = %{file: "cities/morocc.txt"}

    assert ModuleName.module(:function, nil, "f_shared") ==
             "Aesir.ZoneServer.Content.Npc.Functions.FShared"

    assert ModuleName.path(:function, nil, "f_shared") ==
             "lib/aesir/zone_server/content/npc/functions/f_shared.ex"

    assert ModuleName.module(:floating, entry, "floating_npc") ==
             "Aesir.ZoneServer.Content.Npc.Floating.Cities.Morocc.FloatingNpc"

    assert ModuleName.path(:floating, entry, "floating_npc") ==
             "lib/aesir/zone_server/content/npc/floating/cities/morocc/floating_npc.ex"

    assert ModuleName.module(:script, entry, "guard", :renewal) ==
             "Aesir.ZoneServer.Content.Npc.Cities.Morocc.Guard"

    assert ModuleName.path(:script, entry, "guard", :pre_renewal) ==
             "lib/aesir/zone_server/content/npc/cities/morocc/guard.ex"
  end
end
