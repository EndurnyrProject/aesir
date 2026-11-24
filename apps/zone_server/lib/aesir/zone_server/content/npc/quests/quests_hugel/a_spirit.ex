defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsHugel.ASpirit do
  @moduledoc """
  Kanainne's spirit seeks help reaching her sister and lover.

  ## Behavior

  - Advances the Memory Quest and sends the adventurer back to Hugel.

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
        map: "niflheim",
        x: 90,
        y: 106,
        dir: 3,
        sprite: 802,
        name: "A Spirit",
        scope: :shared,
        unique_name: "A Spirit#HQuest"
      }
    ]

  @impl true
  def on_talk(ctx) do
    case get_char_var(ctx, :hg_memory, 0) do
      6 ->
        ctx
        |> mes("[Spirit]")
        |> mes("El Schatt...")
        |> mes("Manainne...")
        |> mes("I miss them...")
        |> next()
        |> mes("[Spirit]")
        |> mes("Those names... Yes,")
        |> mes("I remember now. Manainee")
        |> mes("was... my younger sister.")
        |> mes("El Schatt was... my lover.")
        |> mes("M-my name was... Kanainne!")
        |> next()
        |> mes("[Kanainne's Spirit]")
        |> mes("Now I know why I'm here")
        |> mes("in this realm. El Schatt...")
        |> mes("I've been watching him.")
        |> mes("He isn't able to let me go...")
        |> mes("But I can't directly intervene")
        |> mes("with the affairs of the living.")
        |> next()
        |> mes("[Kanainne's Spirit]")
        |> mes("I... I can borrow my")
        |> mes("sister's body? Yes, if she")
        |> mes("cooperates, maybe... Maybe")
        |> mes("it will work. I must... must do")
        |> mes("something before he does")
        |> mes("he hurts himself even more...")
        |> next()
        |> mes("[Kanainne's Spirit]")
        |> mes("You... You can help")
        |> mes("me... Just go back to ")
        |> mes("the living... to Hugel...")
        |> mes("Let me send you there...")
        |> set_char_var(:hg_memory, 7)
        |> changequest(8062, 8063)
        |> close()
        |> warp("hugel", 78, 148)

      7 ->
        ctx
        |> mes("[Kanainne's Spirit]")
        |> mes("You...! You can help")
        |> mes("me... Just go back to ")
        |> mes("the living... to Hugel...")
        |> mes("Let me send you there...")
        |> close()
        |> warp("hugel", 78, 148)

      _ ->
        ctx
        |> mes("[Spirit]")
        |> mes("The living shouldn't")
        |> mes("be here in Niflheim...")
        |> mes("Go back! Go back to your")
        |> mes("own world before it's too late!")
        |> next()
        |> mes("[Spirit]")
        |> mes("El Schatt...")
        |> mes("Manainne...")
        |> mes("I miss them...")
        |> close()
    end
  end
end
