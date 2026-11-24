defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsHugel.Ashe do
  @moduledoc """
  Ashe notices the player overhearing a conversation.

  ## Credits

  - Original from rAthena, authors and Contributors
    - MasterOfMuppets
    - SinSloth
    - Samuray22
    - L0ne_W0lf
    - Euphy
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "hu_in01",
        x: 16,
        y: 21,
        dir: 0,
        sprite: 139,
        name: "Ashe",
        scope: :shared,
        unique_name: "Ashe#5",
        trigger: {2, 2}
      }
    ]

  @impl true
  def on_event("OnTouch_", ctx), do: on_talk(ctx)

  @impl true
  def on_talk(ctx) do
    if get_char_var(ctx, :hg_odin, 0) == 18 do
      ctx
      |> mes("[Ashe]")
      |> mes("......?")
      |> next()
      |> set_char_var(:hg_odin, 19)
      |> mes("[Ashe]")
      |> mes("......")
      |> mes(".........")
      |> close()
    else
      ctx
    end
  end
end
