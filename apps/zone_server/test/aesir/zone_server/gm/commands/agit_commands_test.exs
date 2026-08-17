defmodule Aesir.ZoneServer.Gm.Commands.AgitCommandsTest do
  use ExUnit.Case, async: true
  use Mimic

  alias Aesir.ZoneServer.Gm.Commands.AgitEnd
  alias Aesir.ZoneServer.Gm.Commands.AgitStart
  alias Aesir.ZoneServer.Mmo.Woe.Server

  setup :verify_on_exit!
  setup :set_mimic_private

  test "AgitStart is a level-99 command that starts WoE and replies" do
    assert AgitStart.name() == "agitstart"
    assert AgitStart.required_level() == 99

    expect(Server, :start, fn -> :ok end)
    assert AgitStart.execute([], %{}) == {:ok, "WoE started."}
  end

  test "AgitEnd is a level-99 command that stops WoE and replies" do
    assert AgitEnd.name() == "agitend"
    assert AgitEnd.required_level() == 99

    expect(Server, :stop, fn -> :ok end)
    assert AgitEnd.execute([], %{}) == {:ok, "WoE ended."}
  end
end
