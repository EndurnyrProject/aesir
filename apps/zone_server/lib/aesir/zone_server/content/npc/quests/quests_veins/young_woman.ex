defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsVeins.YoungWoman do
  @moduledoc """
  Ghez sings a song for the spy quest.

  ## Behavior

  - Performs her song and advances the quest when Vitre sends the player.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Toms
    - Euphy
    - Joseph
    - Everade

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "geffen",
        x: 196,
        y: 167,
        dir: 4,
        sprite: 101,
        name: "Young Woman",
        scope: :shared,
        unique_name: "Young Woman#sch"
      }
    ]

  @impl true
  def on_talk(ctx) do
    cond do
      get_char_var(ctx, :que_sch, 0) < 21 ->
        ctx
        |> mes("[Ghez]")
        |> mes("When is he going")
        |> mes("to send someone to")
        |> mes("listen to my song?")
        |> close()

      get_char_var(ctx, :que_sch, 0) == 21 ->
        ctx
        |> mes("[Ghez]")
        |> mes("Oh, Vitre send you?")
        |> mes("Great, I've been waiting")
        |> mes("for you. Check out this")
        |> mes("new song I wrote. It's great.")
        |> next()
        |> sing_song()
        |> set_char_var(:que_sch, 22)
        |> close()

      get_char_var(ctx, :que_sch, 0) < 30 ->
        ctx
        |> mes("[Ghez]")
        |> mes("You want to hear my song")
        |> mes("again? Fine, but make sure")
        |> mes("to memorize it all this time.")
        |> next()
        |> sing_song()
        |> close()

      true ->
        ctx |> mes("[Ghez]") |> mes("I'm doomed...") |> mes(".......") |> close()
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp sing_song(ctx) do
    ctx
    |> mes("[Ghez]")
    |> mes("Sha la la la la la")
    |> mes("Prontera Knights gotta")
    |> mes("protect the palace~")
    |> mes("Sha hoo hoo haaaaa")
    |> mes("Geffen Knights gotta")
    |> mes("protect the magic tower~")
    |> next()
    |> mes("[Ghez]")
    |> mes("Na na na nan nan naaa")
    |> mes("Prontera! Geffen! Knights")
    |> mes("together! Protect the palace!")
    |> mes("Ooooooooooooh yeah!")
    |> mes("And crush their foes to the west!")
    |> mes("That's the secret plan! La la la~")
    |> next()
    |> mes("[Ghez]")
    |> mes("Wasn't that poetic?")
    |> mes("Now sing that song exactly")
    |> mes("as you heard it to Vitre.")
  end
end
