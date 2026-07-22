defmodule Aesir.ZoneServer.Unit.Mob.MobSessionDeferredSkillTest do
  @moduledoc """
  Covers the `{:skill, {:deferred, module, payload}}` dispatch clause on
  MobSession, mirroring PlayerSession's handler: `Skill.defer/3` arms this
  message on the calling process, so a mob-cast deferring skill (e.g.
  WZ_JUPITEL) sends it here.
  """

  use ExUnit.Case, async: true

  import ExUnit.CaptureLog

  alias Aesir.ZoneServer.Unit.Mob.MobSession

  defmodule Deferrer do
    @moduledoc false
    def deferred(%{reply_to: reply_to} = payload, mob_state) do
      send(reply_to, {:deferred_called, payload, mob_state})
      :ok
    end
  end

  defmodule Undeferrable do
    @moduledoc false
  end

  describe "session dispatch" do
    test "invokes deferred/2 with the payload and the mob's own state" do
      payload = %{reply_to: self(), skill: :example}
      state = %{instance_id: 1}

      assert {:noreply, ^state} =
               MobSession.handle_info({:skill, {:deferred, Deferrer, payload}}, state)

      assert_received {:deferred_called, ^payload, ^state}
    end

    test "logs and drops a deferred message for a module without deferred/2" do
      state = %{instance_id: 1}

      log =
        capture_log(fn ->
          assert {:noreply, ^state} =
                   MobSession.handle_info({:skill, {:deferred, Undeferrable, %{}}}, state)
        end)

      assert log =~ inspect(Undeferrable)
      assert log =~ "deferred/2"
    end
  end
end
