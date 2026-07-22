defmodule Aesir.ZoneServer.Mmo.SkillDeferTest do
  @moduledoc """
  Covers the generic deferred-skill seam (`Skill.defer/3` plus the PlayerSession
  dispatch clause) that replaced the per-skill self-send tags.
  """

  use ExUnit.Case, async: true

  import ExUnit.CaptureLog

  alias Aesir.ZoneServer.Mmo.Skill
  alias Aesir.ZoneServer.Unit.Player.PlayerSession

  defmodule Deferrer do
    @moduledoc false
    def deferred(%{reply_to: reply_to} = payload, caster) do
      send(reply_to, {:deferred_called, payload, caster})
      :ok
    end
  end

  defmodule Undeferrable do
    @moduledoc false
  end

  describe "defer/3" do
    test "schedules the tagged message to the calling process after the delay" do
      payload = %{skill: :example}

      Skill.defer(Deferrer, payload, 20)

      refute_received {:skill, {:deferred, _module, _payload}}
      assert_receive {:skill, {:deferred, Deferrer, ^payload}}, 200
    end
  end

  describe "session dispatch" do
    test "invokes deferred/2 with the payload and the caster game state" do
      payload = %{reply_to: self(), skill: :example}
      state = %{game_state: :caster_game_state}

      assert {:noreply, ^state} =
               PlayerSession.handle_info({:skill, {:deferred, Deferrer, payload}}, state)

      assert_received {:deferred_called, ^payload, :caster_game_state}
    end

    test "logs and drops a deferred message for a module without deferred/2" do
      state = %{game_state: :caster_game_state}

      log =
        capture_log(fn ->
          assert {:noreply, ^state} =
                   PlayerSession.handle_info({:skill, {:deferred, Undeferrable, %{}}}, state)
        end)

      assert log =~ inspect(Undeferrable)
      assert log =~ "deferred/2"
    end
  end
end
