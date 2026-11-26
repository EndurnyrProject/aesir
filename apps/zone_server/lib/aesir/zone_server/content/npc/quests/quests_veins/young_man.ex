defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsVeins.YoungMan do
  @moduledoc """
  Chada sings clues for the investigation.

  ## Behavior

  - Changes his song and response as the investigation progresses.

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
        map: "prontera",
        x: 109,
        y: 161,
        dir: 6,
        sprite: 83,
        name: "Young Man",
        scope: :shared,
        unique_name: "Young Man#sch"
      }
    ]

  @impl true
  def on_talk(ctx) do
    progress = get_char_var(ctx, :que_sch, 0)

    cond do
      progress < 20 ->
        ctx
        |> mes("[Chada]")
        |> mes("What a boring day...")
        |> mes("Perhaps I'll stave the")
        |> mes("dreariness with song~")
        |> close()

      progress == 20 ->
        ctx
        |> mes("[Chada]")
        |> mes("Are you the one that")
        |> mes("Vitre sent? Good, good.")
        |> mes("Let me treat you to my")
        |> mes("wonderful song. Listen...")
        |> mes("And learn... And love...")
        |> next()
        |> mes("[Chada]")
        |> mes("La la la la la la la la~")
        |> mes("A curse plagues the")
        |> mes("royal family, and it's")
        |> mes("been passed down to their")
        |> mes("second child... la la la...")
        |> mes("No one can cure it... Oooh~")
        |> next()
        |> mes("[Chada]")
        |> mes("Hahaha! Isn't that")
        |> mes("such a wonderful song?")
        |> mes("Let Vitre know each and")
        |> mes("every word to it, okay?")
        |> set_char_var(:que_sch, 21)
        |> close()

      progress < 30 ->
        ctx
        |> mes("[Chada]")
        |> mes("Did you need to hear")
        |> mes("the song again? Alright,")
        |> mes("listen carefully this time~")
        |> next()
        |> mes("[Chada]")
        |> mes("La la la la la la la la~")
        |> mes("A curse plagues the")
        |> mes("royal family, and it's")
        |> mes("been passed down to their")
        |> mes("second child... la la la...")
        |> mes("No one can cure it... Oooh~")
        |> next()
        |> mes("[Chada]")
        |> mes("Hahaha! Isn't that")
        |> mes("such a wonderful song?")
        |> mes("Let Vitre know each and")
        |> mes("every word to it, okay?")
        |> close()

      true ->
        ctx
        |> mes("[Chada]")
        |> mes("...........")
        |> mes("I have nothing to say to you.")
        |> close()
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end
end
