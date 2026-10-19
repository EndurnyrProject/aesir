defmodule Aesir.ZoneServer.Mmo.Skill.PortalAccessTest do
  use ExUnit.Case, async: true

  import Mimic

  alias Aesir.ZoneServer.Map.MapCache
  alias Aesir.ZoneServer.Mmo.Skill.PortalAccess
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.Player.Stats.PlayerProgression

  setup :set_mimic_private

  test "reads a real player's typed stats without requiring map-local data for a remote destination" do
    player = %PlayerState{stats: %Stats{progression: %PlayerProgression{job_id: 4}}}
    stub(MapCache, :get, fn "izlude" -> {:error, :not_found} end)
    assert PortalAccess.allowed?(player, "izlude")
  end

  test "job entry uses a strict group-level bypass and intersects restricted zones" do
    restriction = %{"zone" => 4112, "group_level" => 100}
    flags = %{gvg_te: true}
    assert PortalAccess.job_allowed?(restriction, 101, flags, 0)
    refute PortalAccess.job_allowed?(restriction, 100, flags, 0)
    refute PortalAccess.job_allowed?(restriction, 0, %{}, 4096)
    assert PortalAccess.job_allowed?(restriction, 0, %{}, 32)
  end
end
