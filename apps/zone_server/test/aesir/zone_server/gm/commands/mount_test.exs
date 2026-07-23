defmodule Aesir.ZoneServer.Gm.Commands.MountTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Gm.Commands.Mount
  alias Aesir.ZoneServer.Mmo.Option
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  @riding_bit Option.id(:riding)

  defp ctx(option),
    do: %{game_state: %PlayerState{character_name: "Gm", option: option}, connection_pid: self()}

  test "name and required_level" do
    assert Mount.name() == "mount"
    assert Mount.required_level() == 60
  end

  test "not mounted casts the gm toggle and reports Mounted" do
    assert {:ok, "Mounted"} = Mount.execute([], ctx(0))
    assert_received {:"$gen_cast", {:mount, :gm_toggle}}
  end

  test "mounted casts the gm toggle and reports Dismounted" do
    assert {:ok, "Dismounted"} = Mount.execute([], ctx(@riding_bit))
    assert_received {:"$gen_cast", {:mount, :gm_toggle}}
  end
end
