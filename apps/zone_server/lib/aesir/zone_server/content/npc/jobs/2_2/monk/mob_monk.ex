defmodule Aesir.ZoneServer.Content.Npc.Jobs.M22.Monk.MobMonk do
  @moduledoc """
  Spawns undead in the Monk spirit maze when a candidate steps on this spot.

  ## Behavior

  - Summons four Zombies when touched.
  - Removes every monster from the test map when disabled.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Dino9021
    - Celest
    - L0ne_W0lf
    - Samuray22
    - Kisuka
    - Lupus
    - Yor
    - Zephiris
    - Vicious
    - Silent

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "monk_test",
        x: 144,
        y: 277,
        dir: 0,
        sprite: -1,
        name: "mob_monk",
        scope: :shared,
        unique_name: "mob_monk#1_1",
        trigger: {1, 1}
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnTouch_", ctx) do
    ctx
    |> summon_mob(mob_id: 1015, map: "monk_test", at: {144, 277})
    |> summon_mob(mob_id: 1015, map: "monk_test", at: {144, 277})
    |> summon_mob(mob_id: 1015, map: "monk_test", at: {144, 277})
    |> summon_mob(mob_id: 1015, map: "monk_test", at: {144, 277})
  end

  def on_event("OnDisable", ctx), do: killmonsterall(ctx, "monk_test")

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  # rAthena starts a click at the first label, so it runs this body too.
  def on_talk(ctx), do: on_event("OnTouch_", ctx)
end
