defmodule Aesir.CharServer.Config.NewCharacterTest do
  use ExUnit.Case, async: true

  import Mimic

  alias Aesir.CharServer.Config.NewCharacter
  alias Aesir.Commons.GameMode

  setup :set_mimic_private
  setup :verify_on_exit!

  test "uses the renewal start location when configuration is unset" do
    stub_resolved_config([])
    stub(GameMode, :mode, fn -> :renewal end)

    assert NewCharacter.start_map() == "iz_int"
    assert NewCharacter.start_x() == 18
    assert NewCharacter.start_y() == 26
  end

  test "uses the pre-renewal start location when configuration is unset" do
    stub_resolved_config([])
    stub(GameMode, :mode, fn -> :pre_renewal end)

    assert NewCharacter.start_map() == "new_1-1"
    assert NewCharacter.start_x() == 53
    assert NewCharacter.start_y() == 111
  end

  test "uses an explicit start map independently of the mode" do
    stub_resolved_config(start_map: "prontera")
    stub(GameMode, :mode, fn -> :pre_renewal end)

    assert NewCharacter.start_map() == "prontera"
  end

  test "uses an explicit start x independently of the mode" do
    stub_resolved_config(start_x: 100)
    stub(GameMode, :mode, fn -> :renewal end)

    assert NewCharacter.start_x() == 100
  end

  test "uses an explicit start y independently of the mode" do
    stub_resolved_config(start_y: 200)
    stub(GameMode, :mode, fn -> :pre_renewal end)

    assert NewCharacter.start_y() == 200
  end

  defp stub_resolved_config(overrides) do
    config =
      [start_map: nil, start_x: nil, start_y: nil, start_zeny: 0]
      |> Keyword.merge(overrides)

    stub(Application, :fetch_env!, fn :char_server, :new_character -> config end)
  end
end
