defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsGonryun.Madam do
  @moduledoc """
  Shang Hua Yen, the chief's wife in Kunlun, greets visitors and points them to her husband.

  ## Behavior

  - Asked about the chief, says he is upstairs, teasing the player differently by sex.

  ## Credits

  - Original from rAthena, authors and Contributors
    - KarLaeda
    - L0ne_W0lf
    - Paradox924X

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "gon_in",
        x: 18,
        y: 27,
        dir: 5,
        sprite: 771,
        name: "Madam",
        scope: :shared,
        unique_name: "Madam#gnbs"
      }
    ]

  @impl true
  def on_talk(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Shang Hua Yen]")
      |> mes("Ho, ho, ho~")
      |> mes("Who might this be?")
      |> mes("A visitor from out of town~")
      |> mes("Welcome!")
      |> next()
      |> select(["Hello, Madam~", "Where's the chief?"])

    if choice == 1 do
      ctx
      |> mes("[Shang Hua Yen]")
      |> mes("Hello, darling~")
      |> close()
    else
      points_to_the_chief(ctx)
    end
  end

  defp points_to_the_chief(ctx) do
    if sex(ctx) == 0 do
      ctx
      |> mes("[Shang Hua Yen]")
      |> mes("Hoho~ he's upstairs.")
      |> mes("My, are you such a pretty lady~")
      |> mes("Just don't be too enraptured by my husband, alright?")
      |> mes("Tee hee~")
      |> close()
    else
      ctx
      |> mes("[Shang Hua Yen]")
      |> mes("Oh, he's upstairs...")
      |> mes("My~! Aren't you a darling young")
      |> mes("man. But still, not nearly as handsome as my husband~")
      |> mes("Tee hee~")
      |> emotion(:throb)
      |> close()
    end
  end
end
