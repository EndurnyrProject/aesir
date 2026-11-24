defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsJuperos.BronzeStatue do
  @moduledoc """
  Offers an inscription relevant to the Juperos history quest.

  ## Behavior

  - Investigating the inscription advances the quest when Fayruz has sent the player.
  - The inscription changes as the quest progresses.

  ## Credits

  - Original from rAthena, authors and Contributors
    - MasterOfMuppets
    - SinSloth
    - L0ne_W0lf
    - Zephyrus
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
        map: "juperos_01",
        x: 99,
        y: 112,
        dir: 4,
        sprite: 844,
        name: "Bronze Statue",
        scope: :shared,
        unique_name: "Bronze Statue#1"
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    if get_char_var(ctx, :yuno_hist, 0) > 3 do
      ctx
      |> mes("^3355FF''Do you wish to see")
      |> mes("the end of the madness?")
      |> mes("He is waiting where the three")
      |> mes("columns were destroyed, where")
      |> mes("two hundred illusions wander.''^000000")
      |> close()
    else
      if get_char_var(ctx, :yuno_hist, 0) == 3 do
        ctx
        |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
        |> mes("I better go and")
        |> mes("see Fayruz in the")
        |> mes("Juno Library and tell")
        |> mes("her about the inscription.")
        |> close()
      else
        {ctx, choice} =
          ctx
          |> mes("^3355FFThere's a peculiar")
          |> mes("engraving on the")
          |> mes("Bronze Statue's rod.^000000")
          |> next()
          |> select(["Investigate", "Ignore it"])

        case choice do
          1 ->
            ctx =
              ctx
              |> mes("^3355FFIt's an inscription that's")
              |> mes("written in an old language")
              |> mes("that you can't understand,")
              |> mes("but have no problem reading")
              |> mes("and making out the sounds")
              |> mes("for some weird reason.^000000")
              |> next()

            ctx =
              ctx
              |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
              |> mes("This is creepy!")
              |> mes("I know that I'm not")
              |> mes("supposed to be able")
              |> mes("to read this, but here")
              |> mes("I am. I know what sounds")
              |> mes("all of these letters make...")
              |> next()

            if get_char_var(ctx, :yuno_hist, 0) == 2 do
              ctx
              |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
              |> mes("Then again, Fayruz did")
              |> mes("say this was enchanted.")
              |> mes("Okay, I guess I'll go back")
              |> mes("to the Juno Library and")
              |> mes("tell her what I found.")
              |> set_char_var(:yuno_hist, 3)
              |> changequest(11017, 11018)
              |> close()
            else
              ctx
              |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
              |> mes("Huh. Only a scholar,")
              |> mes("maybe someone even in")
              |> mes("Juno, could make sense")
              |> mes("of what this stuff says.")
              |> close()
            end

          2 ->
            close(ctx)

          _ ->
            ctx
        end
      end
    end
  end
end
