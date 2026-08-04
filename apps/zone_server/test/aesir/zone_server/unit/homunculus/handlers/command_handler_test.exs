defmodule Aesir.ZoneServer.Unit.Homunculus.Handlers.CommandHandlerTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Unit.Homunculus.Handlers.CommandHandler
  alias Aesir.ZoneServer.Unit.Homunculus.Runtime
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.SessionState

  test "clear_companion_runtime cancels and clears every transient ref and stale event" do
    refs = for _field <- 1..9, do: :erlang.start_timer(60_000, self(), :stale)

    [active, cooldown, hunger, checkpoint, ai, movement, separation, cast, explosion] = refs

    runtime = %Runtime{
      active_expiry_timer_ref: active,
      active_deadline_ms: 1,
      clocks_online: true,
      cooldown_timer_ref: cooldown,
      hunger_timer_ref: hunger,
      checkpoint_timer_ref: checkpoint,
      ai_timer_ref: ai,
      movement_timer_ref: movement,
      separation_timer_ref: separation,
      cast_timer_ref: cast,
      bio_explosion_timer_ref: explosion,
      bio_explosion_descriptor: %{token: make_ref()},
      movement_path: [{1, 1}],
      last_basic_attack_at_ms: 1,
      hp_regen_deadline_ms: 1,
      sp_regen_deadline_ms: 1,
      private_dirty: true
    }

    session = %SessionState{
      connection_pid: self(),
      game_state: %PlayerState{},
      homunculus_runtime: runtime
    }

    cleared = CommandHandler.clear_companion_runtime(session)
    assert cleared.homunculus_runtime == %Runtime{private_dirty: false}
    assert Enum.all?(refs, &(&1 |> :erlang.read_timer() == false))

    events = [
      {:active_expired, active},
      {:cooldowns_expired, cooldown},
      {:hunger_tick, hunger},
      {:checkpoint, checkpoint},
      {:ai_tick, ai},
      {:movement_tick, movement},
      {:separation_timeout, separation},
      {{:cast_complete, make_ref()}, cast},
      {:bio_explosion, explosion}
    ]

    Enum.each(events, fn {event, ref} ->
      assert {:noreply, ^cleared} = CommandHandler.info(event, ref, cleared)
    end)

    refute_receive {:timeout, _ref, :stale}
  end
end
