defmodule Aesir.ZoneServer.Content.Npc.Jobs.M22.Monk.ApprenticeMonk do
  @moduledoc """
  Nervous apprentice at the start of the Monk marathon trial who lets runners give up.

  ## Behavior

  - Announces runners who quit, resets them to the test choice, and sends them back to the abbey.
  - Urges everyone else to keep running.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Dino9021
    - Celest
    - L0ne_W0lf
    - Samuray22
    - Kisuka
    - Lupus
    - Yor
    - Zephiris
    - Vicious
    - Silent

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "monk_test",
        x: 386,
        y: 388,
        dir: 4,
        sprite: 110,
        name: "Apprentice Monk",
        scope: :shared,
        unique_name: "Apprentice Monk#mk"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @quit_message "...q.q..q. .quit! ...the marathon!! Y...you do not have what it takes to be a m... monk!"

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Monk Apprentice]")
      |> mes("W... welcome!")
      |> mes("Th... this place is for testing the tolerance of monk candidates!")
      |> next()
      |> mes("[Monk Apprentice]")
      |> mes("Ju... just run...")
      |> mes("until you're told to stop,")
      |> mes("Ru...ruu....run!")
      |> next()
      |> mes("[Monk Apprentice]")
      |> mes("M... m... me? I'll run one of these days!")
      |> next()
      |> mes("[Monk Apprentice]")
      |> mes("M... monk... are you going to be... a... m...m...monk??")
      |> next()
      |> mes("[Monk Apprentice]")
      |> mes("Ar...are...you...sure you are.. aren't... going to quit?")
      |> next()
      |> select(["Quit.", "Keep running."])

    if choice == 1 do
      quit_marathon(ctx)
    else
      ctx
      |> mes("[Monk Apprentice]")
      |> mes("Until you're told to stop,")
      |> mes("Ru...ruu....run!")
      |> close()
    end
  end

  defp quit_marathon(ctx) do
    quit_notice = Rathena.concat(Rathena.concat("", char_name(ctx, 0)), @quit_message)

    ctx
    |> mes("[Monk Apprentice]")
    |> mes(quit_notice)
    |> mapannounce("monk_test", quit_notice, 1)
    |> close()
    |> set_char_var(:MONK_Q, 15)
    |> changequest(3028, 3027)
    |> warp("prt_monk", 194, 168)
  end
end
