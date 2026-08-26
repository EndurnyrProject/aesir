defmodule Aesir.ZoneServer.Npc.Transpiler.ModuleNameTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Npc.Transpiler.ModuleName

  test "renewal helper and floating outputs use the renewal namespace" do
    assert ModuleName.module(:function, nil, "f_mode", :renewal) ==
             "Aesir.ZoneServer.Content.Npc.Re.Functions.FMode"

    assert ModuleName.path(:function, nil, "f_mode", :renewal) ==
             "lib/aesir/zone_server/content/npc/re/functions/f_mode.ex"

    assert ModuleName.module(:floating, nil, "floating_npc", :renewal) ==
             "Aesir.ZoneServer.Content.Npc.Re.Floating.FloatingNpc"

    assert ModuleName.path(:floating, nil, "floating_npc", :renewal) ==
             "lib/aesir/zone_server/content/npc/re/floating/floating_npc.ex"
  end

  test "pre-renewal helper and floating outputs use the pre-renewal namespace" do
    assert ModuleName.module(:function, nil, "f_mode", :pre_renewal) ==
             "Aesir.ZoneServer.Content.Npc.PreRe.Functions.FMode"

    assert ModuleName.path(:function, nil, "f_mode", :pre_renewal) ==
             "lib/aesir/zone_server/content/npc/pre_re/functions/f_mode.ex"

    assert ModuleName.module(:floating, nil, "floating_npc", :pre_renewal) ==
             "Aesir.ZoneServer.Content.Npc.PreRe.Floating.FloatingNpc"

    assert ModuleName.path(:floating, nil, "floating_npc", :pre_renewal) ==
             "lib/aesir/zone_server/content/npc/pre_re/floating/floating_npc.ex"
  end

  test "shared output APIs and placed-script outputs remain unchanged" do
    entry = %{file: "cities/morocc.txt"}

    assert ModuleName.module(:function, nil, "f_shared") ==
             "Aesir.ZoneServer.Content.Npc.Functions.FShared"

    assert ModuleName.path(:function, nil, "f_shared") ==
             "lib/aesir/zone_server/content/npc/functions/f_shared.ex"

    assert ModuleName.module(:floating, nil, "floating_npc") ==
             "Aesir.ZoneServer.Content.Npc.Floating.FloatingNpc"

    assert ModuleName.path(:floating, nil, "floating_npc") ==
             "lib/aesir/zone_server/content/npc/floating/floating_npc.ex"

    assert ModuleName.module(:script, entry, "guard", :renewal) ==
             "Aesir.ZoneServer.Content.Npc.Cities.Morocc.Guard"

    assert ModuleName.path(:script, entry, "guard", :pre_renewal) ==
             "lib/aesir/zone_server/content/npc/cities/morocc/guard.ex"
  end
end
