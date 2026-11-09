defmodule Aesir.ZoneServer.Content.Npc.Quests.Quests131.Lucas do
  @moduledoc """
  Lucas, the bedridden Assassin in the hideout who explains how the assassin team breached
  the dimensional crack.

  ## Behavior

  - Stays silent below step 11.
  - On step 11 offers the story of the dimensional crack through a two-option menu; taking it
    sets `ep13_newbs` to 12 and hands over one Chocolate Pie.
  - Between steps 12 and 99 remarks on the player's hard life.
  - From step 100 on remarks on the people the motherland keeps sending.

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
        map: "mid_campin",
        x: 295,
        y: 128,
        dir: 4,
        sprite: 884,
        name: "Lucas",
        scope: :shared,
        unique_name: "Lucas#ep13bs"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @gift 12322

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    case get_char_var(ctx, :ep13_newbs, 0) do
      step when step < 11 -> silent(ctx)
      11 -> replacement_talk(ctx)
      step when step < 100 -> hard_life(ctx)
      _step -> motherland(ctx)
    end
  end

  defp silent(ctx) do
    ctx
    |> mes("[Lucas]")
    |> mes("......")
    |> close()
  end

  defp replacement_talk(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Lucas]")
      |> mes("......")
      |> next()
      |> mes("[Lucas]")
      |> mes("...Hmm...")
      |> mes("Replacement?")
      |> mes("......")
      |> next()
      |> mes("[Lucas]")
      |> mes("The Federal team's still...")
      |> mes("send us people using the")
      |> mes("dangerous way.")
      |> next()
      |> select(["Dangerous way?", "Disregard it."])

    case choice do
      1 -> breach_story(ctx)
      2 -> silent(ctx)
      _ -> ctx
    end
  end

  defp breach_story(ctx) do
    ctx
    |> mes("[Lucas]")
    |> mes("......")
    |> mes("I have been here for a long time.")
    |> next()
    |> mes("[Lucas]")
    |> mes("To breach the dimensional crack, the assassin team was deployed first...")
    |> next()
    |> mes("[Lucas]")
    |> mes("However, most of my men...")
    |> mes("......")
    |> next()
    |> mes("[Lucas]")
    |> mes("No, just ignore what I said.")
    |> mes("......")
    |> set_char_var(:ep13_newbs, 12)
    |> give_item(@gift, 1)
    |> close()
  end

  defp hard_life(ctx) do
    ctx
    |> mes("[Lucas]")
    |> mes("You seem to live hard all the time...")
    |> close()
  end

  defp motherland(ctx) do
    ctx
    |> mes("[Lucas]")
    |> mes("The motherland constantly")
    |> mes("sends us people...")
    |> mes("Is that passage safe?")
    |> close()
  end
end
