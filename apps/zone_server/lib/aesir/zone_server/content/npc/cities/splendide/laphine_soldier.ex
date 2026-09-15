defmodule Aesir.ZoneServer.Content.Npc.Cities.Splendide.LaphineSoldier do
  @moduledoc """
  Watches a stranger in camp and comments on a foreign instrument.

  ## Behavior

  - Speaks intelligibly while the Ring of the Ancient Wise King is equipped and the ep13_2_rhea gate is complete; otherwise
    responds in untranslated language.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "spl_in01",
        x: 180,
        y: 201,
        dir: 3,
        sprite: 461,
        name: "Laphine Soldier",
        scope: :shared,
        unique_name: "Laphine Soldier#ep13_1"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    if is_equipped(ctx, 2782) > 0 and get_char_var(ctx, :ep13_2_rhea, 0) > 99 do
      ctx
      |> mes("[Laphine Soldier]")
      |> mes("You are a stranger here, aren't you?")
      |> mes("I am watching him to prevent anything bad from happening.")
      |> next()
      |> mes("[Laphine Soldier]")
      |> mes("Definitely you are involved.")
      |> mes("The upper side people allow you to pass here...")
      |> mes("But nobody knows what's going to happen in this battlefield.")
      |> next()
      |> mes("[Laphine Soldier]")
      |> mes("Anyway, what's that instrument over there?")
      |> mes("We have a similar one...")
      |> mes("But it sounds totally different.")
      |> close()
    else
      ctx
      |> mes("[Laphine Soldier]")
      |> mes("FusVohlAnu Ur Lon.")
      |> mes("LoUdenFar Ha Dormaur?")
      |> mes("...marAmanYur Mu.")
      |> next()
      |> mes(
        "-The Laphine Soldier wants to tell you something, but just stops talking as you give him a blank stare -"
      )
      |> close()
    end
  end
end
