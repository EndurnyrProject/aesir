defmodule Aesir.ZoneServer.Content.Npc.Quests.FirstClass.TuSword.Bankley do
  @moduledoc """
  Bankley, the murder suspect in Morocc who turns out to be the culprit in the Swordman training quest.

  ## Behavior

  - While the player is interrogating the suspects, recites his piece of the secret code;
    the first time this also marks the interrogations as done.
  - Once Dequ'ee names him as the murderer, the player finds him dead, which advances the
    quest so the player can report back to Dequ'ee.
  - Afterwards only his lifeless body remains; before the investigation he talks about
    travelling the world.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Jukka (fix up)
    - Lupus
    - SinSloth
    - L0ne_W0lf
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{map: "morocc_in", x: 12, y: 156, dir: 3, sprite: 97, name: "Bankley", scope: :shared}
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    case get_char_var(ctx, :tu_swordman, 0) do
      step when step > 19 -> lifeless_body(ctx)
      19 -> discover_body(ctx)
      step -> ctx |> mes("[Bankley]") |> interrogation(step)
    end
  end

  defp lifeless_body(ctx) do
    ctx
    |> mes("^3355FFBankley had a pitiable")
    |> mes("expression on his face.^000000")
    |> mes(
      "^3355FFHis body is completely lifeless. There's a long, deep wound in his chest, and a blood drenched knife is clenched in his right hand.^000000"
    )
    |> close()
  end

  defp discover_body(ctx) do
    ctx
    |> mes("...")
    |> mes("......")
    |> next()
    |> mes("^3355FFHe's dead!^000000")
    |> next()
    |> mes(
      "^3355FFBankley had a sad, pitiable expression on his face. Since the color is still fresh in his cheeks, he died only a little while ago."
    )
    |> mes(
      "^3355FFThere is a long, deep wound in his chest, and a blood drenched knife is clenched in his right hand.^000000"
    )
    |> set_char_var(:tu_swordman, 20)
    |> changequest(8225, 8226)
    |> close()
  end

  defp interrogation(ctx, 15), do: ctx |> recite_code() |> close()

  defp interrogation(ctx, 14) do
    ctx |> recite_code() |> set_char_var(:tu_swordman, 15) |> close()
  end

  defp interrogation(ctx, _step) do
    ctx
    |> mes(
      "Even though I can't afford it now, my dream is to travel around the world and visit all of its great cities!"
    )
    |> next()
    |> mes("[Bankley]")
    |> mes("Someday, I'm sure I'll get the chance to make my dreams")
    |> mes("come true. But for now, I'll have to live as best as I can.")
    |> close()
  end

  defp recite_code(ctx) do
    ctx
    |> mes("I didn't kill anybody...!")
    |> mes("I'm innocent and don't")
    |> mes("have anything to hide!")
    |> next()
    |> mes("[Bankley]")
    |> mes("But look...")
    |> mes(
      "If it helps, let me give you this weird code that some strange guy gave me. I guess it's supposed to be some kind of clue."
    )
    |> next()
    |> mes("[Bankley]")
    |> mes("^5D478BhekdlfiDrindkelsd^000000")
    |> mes("Do you understand what")
    |> mes("it means? I have no idea, but")
    |> mes("I told you everything I know!")
    |> next()
    |> mes("[Bankley]")
    |> mes("I feel so violated!")
    |> mes("Once you prove I'm innocent, are you going to compensate me for")
    |> mes("my mental suffering!?")
    |> next()
    |> mes("[Bankley]")
    |> mes("Stop bothering me")
    |> mes("and wasting your time.")
    |> mes("You're better off hunting")
    |> mes("for the real culprit!")
  end
end
