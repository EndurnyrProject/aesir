defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsGonryun.Girl do
  @moduledoc """
  Shi Ying Xiao reacts to the recovery of her father's stolen sword.

  ## Behavior

  - Laments the theft until the heirloom is recovered, then thanks its finder.

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
        map: "gonryun",
        x: 139,
        y: 142,
        dir: 7,
        sprite: 772,
        name: "Girl",
        scope: :shared,
        unique_name: "Girl##gnbs1"
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    if get_char_var(ctx, :b_sword, 0) < 12 do
      ctx
      |> mes("[Shi Ying Xiao]")
      |> mes("..........")
      |> mes("I was happy meeting visitors")
      |> mes("from outside the village,")
      |> mes("but because of the thief, I feel terrible now...")
      |> emotion(:think)
      |> close()
    else
      celebrate_recovery(ctx)
    end
  end

  defp celebrate_recovery(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Shi Ying Xiao]")
      |> mes("Hehe...")
      |> mes("I am so happy now~")
      |> mes("Lots of visitors are coming to our")
      |> mes("village now. But most of all,")
      |> mes("Someone found my father's heirloom~")
      |> next()
      |> select(["I'm glad you're relieved.", "That would be me!"])

    if choice == 1 do
      ctx
      |> mes("[Shi Ying Xiao]")
      |> mes("Yes, the mood of the entire")
      |> mes("village seems to have calmed...")
      |> mes("I'm sure whoever found my father's sword is a great person.")
      |> close()
    else
      ctx =
        ctx
        |> mes(Rathena.concat(Rathena.concat("[ ^6699FF", char_name(ctx, 0)), "^000000 ]"))
        |> mes("That would be me!")
        |> next()

      ctx
      |> mes(Rathena.concat(Rathena.concat("[ ^6699FF", char_name(ctx, 0)), "^000000 ]"))
      |> mes("I AM YOUR HERO!")
      |> next()
      |> emotion(:smile)
      |> mes("[Shi Ying Xiao]")
      |> mes("Thank you so much for bringing hope to our village, hero~")
      |> close()
    end
  end
end
