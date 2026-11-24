defmodule Aesir.ZoneServer.MobTouchNpcIntegrationTest do
  @moduledoc """
  A monster walking into an NPC's trigger area runs its `OnTouchNPC` with the
  monster attached, and `unitwarp 0, "this", x, y` there moves the monster.
  """

  use Aesir.ZoneServer.IntegrationCase

  alias Aesir.ZoneServer.Map.Cell
  alias Aesir.ZoneServer.Npc.Registry, as: NpcRegistry
  alias Aesir.ZoneServer.Unit.Mob.MobSession

  defmodule MobWarperNpc do
    use Aesir.ZoneServer.Npc,
      spawn: [%{map: "prontera", x: 150, y: 156, sprite: 45, name: "MobWarper", trigger: {1, 1}}]

    @impl true
    def on_talk(ctx), do: ctx

    @impl true
    def on_event("OnTouchNPC", ctx) do
      send(:mob_touch_npc_probe, {:touched, ctx.attached_unit})
      {ctx, _result} = unitwarp(ctx, 0, "this", 160, 160)
      ctx
    end
  end

  setup do
    Aesir.TestProbe.register!(:mob_touch_npc_probe)
    NpcRegistry.reload([MobWarperNpc])
    on_exit(fn -> :persistent_term.erase(NpcRegistry) end)
    :ok
  end

  test "a walking monster entering the trigger area is warped by OnTouchNPC" do
    for {x, y} <- [{150, 150}, {150, 155}, {160, 160}],
        do: assert(Cell.traversable?("prontera", x, y))

    mob = start_mob_session(position: {150, 150})
    MobSession.move_to(mob.pid, 150, 155)

    assert_receive {:touched, {:mob, id}}, 4_000
    assert id == mob.unit_id
    assert_eventually(fn -> match?(%{x: 160, y: 160}, :sys.get_state(mob.pid)) end)
  end
end
