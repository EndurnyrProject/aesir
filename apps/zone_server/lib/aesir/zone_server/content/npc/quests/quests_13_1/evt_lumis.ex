defmodule Aesir.ZoneServer.Content.Npc.Quests.Quests131.EvtLumis do
  @moduledoc """
  The invisible spot on the Manuk field that Rumis Block points out during the Hillsrion
  hunt.

  ## Behavior

  - Fires on touch and on talk only while the player is on `ep13_animal` step 11.
  - Calls the player over to the small tree to the southeast.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Joseph
    - Euphy
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script quests/quests_13_1.txt
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "man_fild01",
        x: 59,
        y: 261,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#evt_lumis",
        trigger: {5, 5}
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnTouch_", ctx), do: call_rumis(ctx)

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx), do: call_rumis(ctx)

  defp call_rumis(ctx) do
    if get_char_var(ctx, :ep13_animal, 0) == 11 do
      ctx
      |> mes("[Rumis Block]")
      |> mes("This is it! Come to the small tree in the southeast direction!")
      |> close()
    else
      ctx
    end
  end
end
