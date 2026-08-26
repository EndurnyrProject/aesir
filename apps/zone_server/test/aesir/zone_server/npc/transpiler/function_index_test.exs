defmodule Aesir.ZoneServer.Npc.Transpiler.FunctionIndexTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Npc.Transpiler.FunctionIndex

  test "resolves a shared helper statically for every caller scope" do
    assert {:ok, index} =
             FunctionIndex.build([
               %{name: "F_Shared", scope: :shared, module: "Content.Npc.Functions.FShared"}
             ])

    assert FunctionIndex.resolve(index, "F_Shared", :shared) ==
             {:static, "Content.Npc.Functions.FShared"}

    assert FunctionIndex.resolve(index, "F_Shared", :renewal) ==
             {:static, "Content.Npc.Functions.FShared"}

    assert FunctionIndex.resolve(index, "F_Shared", :pre_renewal) ==
             {:static, "Content.Npc.Functions.FShared"}
  end

  test "allows mutually exclusive overlays and resolves them by caller scope" do
    assert {:ok, index} =
             FunctionIndex.build([
               %{name: "F_Mode", scope: :renewal, module: "Content.Npc.Re.Functions.FMode"},
               %{
                 name: "F_Mode",
                 scope: :pre_renewal,
                 module: "Content.Npc.PreRe.Functions.FMode"
               }
             ])

    assert FunctionIndex.resolve(index, "F_Mode", :shared) ==
             {:runtime,
              %{
                renewal: "Content.Npc.Re.Functions.FMode",
                pre_renewal: "Content.Npc.PreRe.Functions.FMode"
              }}

    assert FunctionIndex.resolve(index, "F_Mode", :renewal) ==
             {:static, "Content.Npc.Re.Functions.FMode"}

    assert FunctionIndex.resolve(index, "F_Mode", :pre_renewal) ==
             {:static, "Content.Npc.PreRe.Functions.FMode"}
  end

  test "returns missing for unknown or opposite-overlay helpers" do
    assert {:ok, index} =
             FunctionIndex.build([
               %{name: "F_Re", scope: :renewal, module: "Content.Npc.Re.Functions.FRe"}
             ])

    assert FunctionIndex.resolve(index, "F_Re", :shared) ==
             {:runtime, %{renewal: "Content.Npc.Re.Functions.FRe"}}

    assert FunctionIndex.resolve(index, "F_Re", :pre_renewal) == :missing
    assert FunctionIndex.resolve(index, "F_Unknown", :shared) == :missing
    assert FunctionIndex.resolve(index, "F_Unknown", :renewal) == :missing
  end

  test "rejects duplicate helpers within one scope" do
    assert {:error, [{:duplicate_helper, "F_Dupe", :renewal}]} =
             FunctionIndex.build([
               %{name: "F_Dupe", scope: :renewal, module: "Content.Npc.Re.Functions.First"},
               %{name: "F_Dupe", scope: :renewal, module: "Content.Npc.Re.Functions.Second"}
             ])
  end

  test "rejects a shared helper combined with an overlay helper" do
    assert {:error, [{:ambiguous_helper, "F_Ambiguous", :shared, :renewal}]} =
             FunctionIndex.build([
               %{name: "F_Ambiguous", scope: :shared, module: "Content.Npc.Functions.Shared"},
               %{
                 name: "F_Ambiguous",
                 scope: :renewal,
                 module: "Content.Npc.Re.Functions.Overlay"
               }
             ])

    assert {:error, [{:ambiguous_helper, "F_Ambiguous", :shared, :pre_renewal}]} =
             FunctionIndex.build([
               %{
                 name: "F_Ambiguous",
                 scope: :pre_renewal,
                 module: "Content.Npc.PreRe.Functions.Overlay"
               },
               %{name: "F_Ambiguous", scope: :shared, module: "Content.Npc.Functions.Shared"}
             ])
  end
end
